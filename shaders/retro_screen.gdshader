shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform float intensity = 0.0;
uniform float max_intensity = 4.2;
uniform float pixel_size_max = 32.0;
uniform float color_levels_min : hint_range(2.0, 32.0) = 4.0;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.3;

void fragment() {
	vec2 screen_size = vec2(textureSize(SCREEN_TEXTURE, 0));

	// Normalize to 0-1 range based on max hits
	float t = clamp(intensity / max_intensity, 0.0, 1.0);

	// Exponential pixelation: starts at 4px on first hit, scales up dramatically
	float pix = mix(1.0, 4.0, step(0.001, t)) * pow(pixel_size_max / 4.0, t);
	vec2 grid = floor(SCREEN_UV * screen_size / pix) * pix / screen_size;
	vec2 uv = mix(SCREEN_UV, grid, step(0.001, t));

	vec3 col = texture(SCREEN_TEXTURE, uv).rgb;

	// Color quantization with exponential curve
	float levels = mix(256.0, color_levels_min, t * t);
	col = floor(col * levels) / levels;

	// Scanlines scale with pixelation
	float scan = sin(uv.y * screen_size.y / pix * 3.14159) * 0.5 + 0.5;
	col *= mix(1.0, mix(1.0, scan, scanline_strength), t);

	COLOR = vec4(col, 1.0);
}
