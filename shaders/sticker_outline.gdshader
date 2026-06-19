shader_type canvas_item;

uniform float outline_width : hint_range(1.0, 8.0) = 2.5;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 px = outline_width / size;

	float center_a = texture(TEXTURE, UV).a;

	float max_neighbor = 0.0;
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

	// Edge = neighbor is opaque but center is transparent (outer outline)
	float edge = max_neighbor * step(center_a, 0.3);

	COLOR = vec4(outline_color.rgb, edge * outline_color.a);
}
