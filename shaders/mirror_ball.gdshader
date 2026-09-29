shader_type spatial;
// Faceted disco mirror ball: flat chrome tiles that twinkle as the ball turns.
render_mode specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.72, 0.74, 0.8, 1.0);
uniform float tiles_around = 36.0;
uniform float tiles_down = 18.0;
uniform float sparkle_strength = 3.0;
uniform float sparkle_speed = 2.5;

varying vec3 obj_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(obj_pos);
	float u = atan(n.z, n.x) / TAU + 0.5;
	float v = acos(clamp(n.y, -1.0, 1.0)) / PI;
	vec2 tile_uv = vec2(u * tiles_around, v * tiles_down);
	vec2 id = floor(tile_uv);
	vec2 f = fract(tile_uv);
	float grout = step(0.08, f.x) * step(0.08, f.y) * step(f.x, 0.92) * step(f.y, 0.92);

	float h = hash21(id);
	float twinkle = pow(max(sin(TIME * sparkle_speed + h * 60.0), 0.0), 24.0);

	ALBEDO = base_color.rgb * mix(0.25, 1.0, grout) * (0.8 + 0.2 * h);
	METALLIC = 1.0;
	ROUGHNESS = mix(0.6, 0.08, grout);
	EMISSION = vec3(1.0, 0.95, 1.0) * twinkle * sparkle_strength * grout;
}
