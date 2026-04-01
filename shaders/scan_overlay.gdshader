shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform bool active = false;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float world_x_min = -4.97;
uniform float world_x_max = -1.94;
uniform float line_width = 0.08;

void fragment() {
	if (!active) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.0);
		ALPHA = 0.0;
		return;
	}
	float scan_x = mix(world_x_min, world_x_max, progress);
	float d = abs(WORLD_POSITION.x - scan_x);
	float line = smoothstep(line_width, 0.0, d);
	vec3 glow = vec3(0.1, 1.0, 0.3) * line * 4.0;
	ALBEDO = glow;
	EMISSION = glow;
	ALPHA = line * 0.85;
}
