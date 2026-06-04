shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float speed = 0.42;
uniform float width = 1.22;
uniform float height = 0.92;
uniform float intensity = 1.95;
uniform float distortion = 0.74;
uniform float glow = 2.95;
uniform vec4 fire_color : source_color = vec4(1.0, 0.30, 0.035, 1.0);

varying vec3 object_pos;

// --- Noise helpers ---

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.11369, 0.13787));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

// Quintic-smooth 3D value noise (no derivative discontinuities)
float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	// Quintic smoothstep
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);
	return mix(nxy0, nxy1, u.z);
}

// Domain-rotating FBM for isotropic, non-repetitive noise
float fbm(vec3 p) {
	float value = 0.0;
	float amplitude = 0.50;
	float total_amp = 0.0;
	// ~37-degree rotation in XZ to break axis alignment
	mat3 rot = mat3(
		vec3(0.00, 0.80, 0.60),
		vec3(-0.80, 0.36, -0.48),
		vec3(-0.60, -0.48, 0.64)
	);
	for (int i = 0; i < 6; i++) {
		value += vnoise3(p) * amplitude;
		total_amp += amplitude;
		p = rot * p * 2.02 + vec3(5.37, 2.91, 7.13);
		amplitude *= 0.50;
	}
	return value / total_amp; // normalised
}

float ridge(float v) {
	return 1.0 - abs(v * 2.0 - 1.0);
}

void vertex() {
	object_pos = VERTEX;
}

void fragment() {
	vec3 local = object_pos;
	vec3 p = local;
	float t = TIME * speed * 0.42;

	// Primary upward drift + lateral sway
	p.y -= t;
	p.x += sin(local.y * 1.35 + t * 0.95) * 0.20 + t * 0.08;
	p.z += cos(local.y * 1.18 + t * 0.82) * 0.20 + t * 0.06;

	// --- Radial and vertical masks ---
	float radius = length(local.xz);
	float radial_core  = 1.0 - smoothstep(width * 0.16, width * 0.92, radius);
	float radial_shell = 1.0 - smoothstep(width * 0.84, width * 1.22, radius);
	float radial_edge  = smoothstep(width * 0.34, width * 0.92, radius) * radial_shell;

	float y01 = clamp((local.y / max(height, 0.001)) * 0.5 + 0.5, 0.0, 1.0);
	float bottom_fade  = smoothstep(0.02, 0.20, y01);
	float top_fade     = 1.0 - smoothstep(0.72, 1.0, y01);
	float vertical_mask = bottom_fade * top_fade;
	float surface_boost = 1.0 - smoothstep(width * 1.08, width * 1.34, radius);
	float shape_mask = smoothstep(0.0, 0.58, max(radial_shell, surface_boost * 0.72) * vertical_mask);

	// --- Slow large-scale smoke warp (the key for realism) ---
	// Large turbulent plumes driven by slow FBM
	float smoke_t = t * 0.55; // smoke rises slower
	vec3 smoke_p = vec3(p.x * 0.9, p.y * 0.6 - smoke_t, p.z * 0.9);
	float smoke_base = fbm(smoke_p);
	float smoke_detail = fbm(smoke_p * 2.1 + vec3(1.7, 0.0, 4.3));
	// Billowy pockets – smooth billow shape
	float billow = smoothstep(0.30, 0.80, smoke_base * 0.6 + smoke_detail * 0.4);
	billow *= radial_shell * vertical_mask;
	// Gentle lateral curl
	float curl_x = fbm(vec3(p.z * 1.3 + smoke_t * 0.22, p.y * 0.7, p.x * 0.9 + smoke_t * 0.18)) - 0.5;
	float curl_z = fbm(vec3(p.x * 1.2 + smoke_t * 0.19, p.y * 0.7, p.z * 1.1 + smoke_t * 0.23)) - 0.5;

	vec3 warped = p;
	warped.xz += vec2(curl_x, curl_z) * distortion * 0.65;
	warped.y   += (smoke_base - 0.5) * distortion * 0.30;

	// --- Fire structure on warped coords ---
	float column_noise = fbm(warped * vec3(2.2, 1.45, 2.2));
	float fine_noise   = fbm(warped * vec3(5.8, 2.6, 5.8) + vec3(3.7, 0.0, 8.4));
	float stream_a = ridge(fbm(vec3(warped.x * 2.0 + warped.y * 0.42, warped.y * 1.15, warped.z * 0.8)));
	float stream_b = ridge(fbm(vec3(warped.z * 1.9 - warped.y * 0.36 + 4.0, warped.y * 1.02, warped.x * 0.9)));

	float diagonal_flow  = smoothstep(0.54, 0.95, stream_a + fine_noise * 0.18);
	float horizontal_flow = smoothstep(0.56, 0.98, stream_b + column_noise * 0.16);
	float vapor    = smoothstep(0.24, 0.72, column_noise) * max(radial_shell, surface_boost * 0.85);
	float crossings = diagonal_flow * horizontal_flow;

	float core_heat  = smoothstep(0.58, 0.98, fine_noise + crossings * 0.65 + radial_core * 0.18);
	float ember_core = core_heat * smoothstep(0.22, 0.76, y01) * (1.0 - smoothstep(0.88, 1.0, y01));

	// Smooth noise grain (quintic, so no sparkle artifacts)
	float grain = (vnoise3(local * 28.0 + vec3(TIME * 0.025)) - 0.5) * 0.012;

	// --- Color ---
	vec3 void_black    = vec3(0.004, 0.001, 0.000);
	vec3 deep_violet   = vec3(0.040, 0.008, 0.018);
	vec3 smoke_grey    = vec3(0.14, 0.10, 0.08);   // lighter, more realistic smoke
	vec3 smoke_brown   = vec3(0.16, 0.045, 0.010);
	vec3 dark_red      = vec3(0.38, 0.020, 0.002);
	vec3 ember_red     = vec3(0.78, 0.055, 0.006);
	vec3 gold          = vec3(1.0, 0.58, 0.08);
	vec3 pale_fire     = vec3(1.0, 0.82, 0.24);
	vec3 spectral_cyan = vec3(0.05, 0.34, 0.42);
	vec3 red_core      = vec3(0.70, 0.030, 0.004);
	vec3 orange_core   = fire_color.rgb;

	vec3 color = mix(void_black, deep_violet, radial_edge * 0.72 + vapor * 0.24);
	color = mix(color, smoke_brown, vapor * 0.44);
	// Smoke billows tinted toward cooler grey at edges
	color = mix(color, smoke_grey * 0.6, billow * (1.0 - diagonal_flow) * 0.40);
	color = mix(color, dark_red,    diagonal_flow * 0.52);
	color = mix(color, ember_red,   horizontal_flow * 0.46);
	color = mix(color, orange_core, crossings * 0.50);
	color = mix(color, gold,        ember_core * 0.42);
	color = mix(color, pale_fire,   pow(ember_core, 2.2) * 0.20);
	color = mix(color, spectral_cyan, vapor * radial_edge * 0.08);
	color = mix(color, red_core,    ember_core * 0.18);
	color = vec3(color.r * 1.25, color.g * 0.76, color.b * 0.38);
	color += grain;

	// --- Alpha ---
	vec3 world_pos = (MODEL_MATRIX * vec4(object_pos, 1.0)).xyz;
	float distance_fade = clamp(1.0 - length(world_pos - CAMERA_POSITION_WORLD) * 0.0016, 0.25, 1.0);
	float volume_depth  = smoothstep(width * 1.08, width * 0.28, radius);

	float alpha = (vapor * 0.25 + diagonal_flow * 0.32 + horizontal_flow * 0.32
	             + crossings * 0.44 + ember_core * 0.34 + billow * 0.22);
	alpha *= shape_mask * distance_fade * intensity;
	alpha *= mix(0.72, 1.0, volume_depth);
	alpha = clamp(alpha, 0.0, 1.0);

	vec3 emission_color = color * glow * (0.20 + alpha);

	ALBEDO   = emission_color;
	EMISSION = emission_color;
	ALPHA    = alpha * fire_color.a;
}
