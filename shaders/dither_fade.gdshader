shader_type spatial;
render_mode blend_mix, cull_back;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float dither_scale : hint_range(1.0, 16.0) = 4.0;

const mat4 BAYER_8 = mat4(
	vec4( 0.0/64.0, 32.0/64.0,  8.0/64.0, 40.0/64.0),
	vec4(48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0),
	vec4(12.0/64.0, 44.0/64.0,  4.0/64.0, 36.0/64.0),
	vec4(60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0)
);

void fragment() {
	ivec2 px = ivec2(mod(FRAGCOORD.xy / dither_scale, 4.0));
	float threshold = BAYER_8[px.x][px.y];
	if (progress > threshold) {
		discard;
	}
}
