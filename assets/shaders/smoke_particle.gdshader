shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;

uniform float smoke_density : hint_range(0.0, 1.0) = 0.85;
uniform vec4  smoke_color : source_color = vec4(0.78, 0.76, 0.74, 1.0);

// Simple but smooth hash
float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Quintic-smooth 2D value noise
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f*f*f*(f*(f*6.0-15.0)+10.0);
	float a = hash(i);
	float b = hash(i + vec2(1,0));
	float c = hash(i + vec2(0,1));
	float d = hash(i + vec2(1,1));
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0; float a = 0.5; float total = 0.0;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		total += a;
		p = rot * p * 2.01 + vec2(4.7, 2.3);
		a *= 0.52;
	}
	return v / total;
}

void fragment() {
	// UV centered at (0.5, 0.5)
	vec2 uv = UV;
	vec2 centered = uv - 0.5;

	// Radial soft circle mask — smooth, no hard edges
	float dist = length(centered);
	float circle = 1.0 - smoothstep(0.30, 0.52, dist);
	if (circle < 0.001) discard;

	// Slow animated FBM warp for organic billowing
	float t = TIME * 0.18;
	vec2 warp = vec2(
		fbm(uv * 2.8 + vec2(t * 0.7, t * 0.4)),
		fbm(uv * 2.8 + vec2(t * 0.5 + 3.1, t * 0.6 + 1.7))
	) - 0.5;
	vec2 warped_uv = uv + warp * 0.22;

	float n1 = fbm(warped_uv * 3.5 + vec2(t * 0.55, -t * 0.3));
	float n2 = fbm(warped_uv * 6.0 + vec2(-t * 0.42 + 5.0, t * 0.7));

	// Combine for a wispy, billowy shape
	float cloud = n1 * 0.65 + n2 * 0.35;
	cloud = smoothstep(0.28, 0.75, cloud);

	// Slightly lighter in the centre, darker at edges (volumetric feel)
	float radial_bright = 1.0 - smoothstep(0.0, 0.40, dist) * 0.35;

	// Final alpha: circle edge × cloud detail × COLOR.a (particle lifetime)
	float alpha = circle * cloud * radial_bright * smoke_density * COLOR.a;
	alpha = clamp(alpha, 0.0, 1.0);

	// Color: mix base smoke grey with a slightly warmer tone in the dense areas
	vec3 col = mix(smoke_color.rgb * 0.72, smoke_color.rgb, cloud * radial_bright);

	ALBEDO = col * COLOR.rgb;
	ALPHA  = alpha;
}
