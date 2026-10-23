shader_type spatial;
// Yellow-and-black construction tape. Stripes run diagonally in world space,
// so separate strips line up where they meet at a corner.

uniform vec3 yellow : source_color = vec3(0.95, 0.75, 0.05);
uniform vec3 black : source_color = vec3(0.03, 0.03, 0.03);
uniform float stripes_per_meter = 6.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float band = fract((world_pos.x + world_pos.z) * stripes_per_meter * 0.5);
	ALBEDO = band < 0.5 ? yellow : black;
	ROUGHNESS = 0.6;
}
