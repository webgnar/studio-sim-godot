shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec3 inverted = vec3(1.0) - screen_color.rgb;
	float mask = texture(TEXTURE, UV).a;
	COLOR = vec4(inverted, mask);
}
