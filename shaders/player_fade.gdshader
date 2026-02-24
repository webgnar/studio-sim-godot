shader_type spatial;
// Opaque render mode — discard handles per-pixel transparency without sorting issues
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture  : hint_normal,  filter_linear_mipmap;
uniform sampler2D ao_texture      : hint_default_white, filter_linear_mipmap;
uniform bool normal_enabled = true;
uniform bool ao_enabled = true;

// fade_inner_radius: fully invisible inside this distance
// fade_outer_radius: fully visible beyond this distance
// Narrow the gap for a sharper transition; set equal for a hard cutoff
uniform float fade_inner_radius : hint_range(0.0, 2.0) = 0.3;
uniform float fade_outer_radius : hint_range(0.0, 2.0) = 0.6;

// Controls the dither blend in the transition band.
// 0.0 = hard cutoff at the midpoint, 1.0 = full 4x4 Bayer dither
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;

float bayer4x4(ivec2 pixel) {
	int bayer[16] = int[16](
		 0,  8,  2, 10,
		12,  4, 14,  6,
		 3, 11,  1,  9,
		15,  7, 13,  5
	);
	return float(bayer[(pixel.x % 4) + (pixel.y % 4) * 4]) / 16.0;
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb;
	if (normal_enabled) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
	if (ao_enabled) {
		AO = texture(ao_texture, UV).r;
	}
	ROUGHNESS = 0.8;
	METALLIC  = 0.0;

	// VERTEX in fragment() is view-space — its length is the distance from the camera
	float dist = length(VERTEX);
	float fade_factor = clamp(
		(dist - fade_inner_radius) / (fade_outer_radius - fade_inner_radius),
		0.0, 1.0
	);
	// Blend between hard threshold (0.5) and Bayer dither based on dither_strength
	float threshold = mix(0.5, bayer4x4(ivec2(FRAGCOORD.xy)), dither_strength);
	if (fade_factor < threshold) {
		discard;
	}
}
