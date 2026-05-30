shader_type canvas_item;

uniform float blur_strength : hint_range(0.0, 20.0) = 0.0;

void fragment() {
	vec4 color = vec4(0.0);
	float samples = 0.0;

	for (int x = -4; x <= 4; x++) {
		for (int y = -4; y <= 4; y++) {

			vec2 offset = vec2(float(x), float(y))
				* blur_strength
				* TEXTURE_PIXEL_SIZE;

			color += texture(TEXTURE, UV + offset);
			samples += 1.0;
		}
	}

	COLOR = color / samples;
}