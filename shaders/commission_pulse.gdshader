shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float glow_strength = 2.0;
uniform float rim_power = 3.0;
uniform float pulse_speed = 2.0;

void fragment() {
	float rim = 1.0 - dot(NORMAL, VIEW);
	rim = pow(rim, rim_power);

	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;

	ALBEDO = glow_color.rgb;
	ALPHA = rim * glow_strength * pulse;
}
