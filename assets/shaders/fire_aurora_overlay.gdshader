shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float speed = 0.28;
uniform float intensity = 1.0;
uniform float distortion = 0.85;
uniform float glow = 2.8;
uniform vec4 fire_color : source_color = vec4(1.0, 0.30, 0.035, 1.0);

// --- Noise helpers ---

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Smooth value noise 2D
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Quintic smoothstep for extra smoothness (no derivative discontinuity)
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Multi-octave FBM – more octaves, domain rotation for isotropy
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.50;
	float total_amp = 0.0;
	// Rotation matrix ~37 degrees to break axis-aligned artifacts
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 7; i++) {
		v += vnoise(p) * a;
		total_amp += a;
		p = rot * p * 2.01 + vec2(4.7, 2.3);
		a *= 0.52;
	}
	return v / total_amp; // normalise to [0,1]
}

// Smooth domain-warped curtain band
float curtain(vec2 uv, float t, float y_offset, float width, float phase) {
	// Two layers of domain warp for organic look
	vec2 warp_p = vec2(uv.x * 2.5 + t * 0.28 + phase, uv.y * 1.4 - t * 0.14);
	float n1 = fbm(warp_p);
	float n2 = fbm(vec2(uv.x * 5.5 - t * 0.38 + phase + 3.1, uv.y * 2.6 + n1 * 1.8));

	// Multi-frequency wave for complex curtain edge
	float wave = y_offset;
	wave += sin(uv.x * 4.8 + t * 1.1 + phase + n1 * 2.5) * 0.13;
	wave += sin(uv.x * 2.1 - t * 0.65 + phase + 1.7) * 0.09;
	wave += sin(uv.x * 9.0 + t * 1.9 + phase + n2 * 1.2) * 0.04; // high-freq flutter

	// Smooth feathered band – wider softness for no hard edges
	float dist = abs(uv.y - wave);
	float band = 1.0 - smoothstep(0.0, width, dist);
	band = pow(band, 0.7); // brighten core

	// Vertical transparency variation
	float veil = smoothstep(0.08, 0.92, n1 + n2 * 0.5);
	return band * veil;
}

void fragment() {
	float t = TIME * speed;
	vec2 uv = UV;

	// Edge fades (smooth, no abrupt cutoff)
	float vertical_fade = smoothstep(0.02, 0.22, uv.y) * (1.0 - smoothstep(0.78, 1.0, uv.y));
	float side_fade    = smoothstep(0.0, 0.12, uv.x) * (1.0 - smoothstep(0.88, 1.0, uv.x));

	// Domain warp on UV for large-scale undulation
	float base_warp = fbm(uv * 1.8 + t * 0.12);
	vec2 warped_uv = uv + vec2(base_warp * distortion * 0.055, 0.0);

	// Three aurora curtain bands at different heights / phases
	float c1 = curtain(warped_uv, t, 0.60, 0.16, 0.0);
	float c2 = curtain(warped_uv, t, 0.43, 0.13, 2.6);
	float c3 = curtain(warped_uv, t, 0.27, 0.10, 5.1);
	// A fourth subtle band for depth
	float c4 = curtain(warped_uv, t * 0.72, 0.52, 0.07, 7.8) * 0.45;

	float glow_band = c1 * 0.78 + c2 * 0.60 + c3 * 0.38 + c4;

	// --- Smoke / volume layer (slow, large, very soft) ---
	vec2 smoke_p = vec2(uv.x * 2.2 - t * 0.22, uv.y * 1.6 + t * 0.08);
	float smoke_a = fbm(smoke_p);
	float smoke_b = fbm(smoke_p * 1.7 + vec2(3.1, 7.4));
	float smoke = smoothstep(0.30, 0.80, smoke_a * 0.65 + smoke_b * 0.35);
	// Soft rising pockets
	float smoke_rise = fbm(vec2(uv.x * 3.5 - t * 0.18, uv.y * 3.0 + t * 0.35));
	smoke = mix(smoke, smoke_rise, 0.30);
	smoke *= vertical_fade * side_fade * 0.55; // keep smoke subtle

	// Tiny luminous sparks
	float sparks = smoothstep(0.976, 0.999, fbm(vec2(uv.x * 22.0 - t * 2.8, uv.y * 10.0 + t * 1.2)));
	sparks *= smoothstep(0.04, 0.18, uv.y); // no sparks at very bottom

	// --- Alpha composition ---
	float alpha = glow_band * vertical_fade * side_fade * intensity;
	alpha += sparks * 0.32 * vertical_fade;
	alpha = clamp(alpha, 0.0, 0.90);

	// --- Color ---
	vec3 deep_red    = vec3(0.40, 0.012, 0.002);
	vec3 red         = vec3(0.82, 0.050, 0.005);
	vec3 orange      = fire_color.rgb;
	vec3 gold        = vec3(1.0, 0.62, 0.10);
	vec3 smoke_col   = vec3(0.30, 0.07, 0.008);
	vec3 pale_gold   = vec3(1.0, 0.85, 0.30); // very hot core

	float heat = clamp(glow_band * 1.1 + smoke * 0.18, 0.0, 1.0);
	vec3 color = smoke_col;
	color = mix(color, deep_red, smoothstep(0.05, 0.30, heat));
	color = mix(color, red,      smoothstep(0.22, 0.52, heat));
	color = mix(color, orange,   smoothstep(0.42, 0.78, heat));
	color = mix(color, gold,     smoothstep(0.72, 0.95, heat) * 0.65);
	color = mix(color, pale_gold, pow(max(heat - 0.90, 0.0) * 10.0, 2.0) * 0.25);

	// Tint smoke slightly cooler
	color = mix(color, smoke_col * 1.4, smoke * (1.0 - heat) * 0.35);

	ALBEDO   = color * alpha;
	EMISSION = color * alpha * glow;
	ALPHA    = alpha;
}
