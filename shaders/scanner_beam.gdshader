shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

void fragment() {
	float fade = 1.0 - UV.y;
	ALBEDO = vec3(0.1, 1.0, 0.3);
	EMISSION = ALBEDO * fade * 2.0;
	ALPHA = fade * 0.25;
}
