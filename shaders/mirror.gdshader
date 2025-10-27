shader_type spatial;

uniform sampler2D refl_tx;
uniform float metallic : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float reflection_strength : hint_range(0.0, 1.0) = 1.0;
 
void fragment() {
	ALBEDO = texture(refl_tx, vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y)).rgb * reflection_strength;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}