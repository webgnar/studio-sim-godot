shader_type spatial;
render_mode unshaded, blend_add;

uniform vec3 color : source_color = vec3(0.2, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.5, 20.0) = 6.0;
uniform float glow : hint_range(1.0, 20.0) = 5.0;

void fragment() {
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	vec3 col = color * pulse;
	ALBEDO = col;
	EMISSION = col * glow;
}
