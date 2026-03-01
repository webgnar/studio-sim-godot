shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float grid_scale : hint_range(1.0, 100.0) = 20.0;
uniform float line_width : hint_range(0.001, 0.5) = 0.02;
uniform float glow_strength : hint_range(0.0, 10.0) = 3.0;
uniform float rainbow_speed : hint_range(0.0, 5.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV * grid_scale;

	vec2 grid = abs(fract(uv - 0.5) - 0.5) / fwidth(uv);
	float line = min(grid.x, grid.y);
	float grid_mask = 1.0 - smoothstep(0.0, line_width * 10.0, line);

	float hue = fract(uv.x * 0.1 + uv.y * 0.1 + TIME * rainbow_speed);
	vec3 color = vec3(
		abs(hue * 6.0 - 3.0) - 1.0,
		2.0 - abs(hue * 6.0 - 2.0),
		2.0 - abs(hue * 6.0 - 4.0)
	);
	color = clamp(color, 0.0, 1.0);

	vec3 final_color = color * grid_mask;

	ALBEDO = final_color;
	EMISSION = final_color * glow_strength;
	ALPHA = grid_mask * alpha;
}
