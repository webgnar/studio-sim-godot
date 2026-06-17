shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D sticker_texture : source_color;
uniform float outline_width : hint_range(1.0, 8.0) = 2.5;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_mult : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 size = vec2(textureSize(sticker_texture, 0));
	vec2 px = outline_width / size;

	float center_a = texture(sticker_texture, UV).a;

	float max_neighbor = 0.0;
	max_neighbor = max(max_neighbor, texture(sticker_texture, UV + vec2(px.x, 0.0)).a);
	max_neighbor = max(max_neighbor, texture(sticker_texture, UV + vec2(-px.x, 0.0)).a);
	max_neighbor = max(max_neighbor, texture(sticker_texture, UV + vec2(0.0, px.y)).a);
	max_neighbor = max(max_neighbor, texture(sticker_texture, UV + vec2(0.0, -px.y)).a);
	max_neighbor = max(max_neighbor, texture(sticker_texture, UV + vec2(px.x, px.y)).a);
	max_neighbor = max(max_neighbor, texture(sticker_texture, UV + vec2(-px.x, px.y)).a);
	max_neighbor = max(max_neighbor, texture(sticker_texture, UV + vec2(px.x, -px.y)).a);
	max_neighbor = max(max_neighbor, texture(sticker_texture, UV + vec2(-px.x, -px.y)).a);

	float edge = max_neighbor * step(center_a, 0.3);

	ALBEDO = outline_color.rgb;
	ALPHA = edge * outline_color.a * alpha_mult;
}
