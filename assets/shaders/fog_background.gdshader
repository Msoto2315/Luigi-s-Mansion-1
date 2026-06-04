shader_type canvas_item;

uniform vec4  fog_color     : source_color = vec4(0.08, 0.18, 0.55, 1.0);
uniform float speed         : hint_range(0.0, 3.0)  = 0.85;
uniform float fog_alpha_min : hint_range(0.0, 1.0)  = 0.35;
uniform float fog_alpha_max : hint_range(0.0, 1.0)  = 0.90;

vec2 quintic(vec2 x) {
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = quintic(f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v   = 0.0;
	float amp = 0.5;
	mat2 rot  = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v   += amp * smooth_noise(p);
		p    = rot * p * 2.0 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * 2.0;
	float t = TIME * speed;

	// Rotación circular rápida
	vec2  center  = uv - vec2(1.0);
	float angle   = t * 0.9;
	float cs      = cos(angle);
	float sn      = sin(angle);
	vec2  rotated = vec2(center.x * cs - center.y * sn,
	                     center.x * sn + center.y * cs);

	// Dos capas de niebla con deriva pronunciada
	float n1 = fbm(rotated + vec2(t * 0.55, -t * 0.40));
	float n2 = fbm(uv * 1.3 + vec2(-t * 0.45, t * 0.60) + n1 * 0.7);
	float fog = (n1 + n2) * 0.5;
	fog = smoothstep(0.20, 0.60, fog);

	// Viñeta: más niebla en bordes, menos en el centro
	vec2  vig_uv  = UV - vec2(0.5);
	float vignette = smoothstep(0.05, 0.95, dot(vig_uv, vig_uv) * 2.2);

	// Alpha bien visible — mezcla entre fog_alpha_min y fog_alpha_max
	float final_alpha = fog * mix(fog_alpha_min, fog_alpha_max, vignette);
	COLOR = vec4(fog_color.rgb, final_alpha);
}
