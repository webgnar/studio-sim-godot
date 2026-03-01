shader_type spatial;
render_mode unshaded, blend_add;

uniform vec3 color : source_color = vec3(0.0, 0.8, 1.0);
uniform float speed : hint_range(0.1, 10.0) = 2.0;
uniform float stripe_density : hint_range(1.0, 40.0) = 10.0;
uniform float intensity : hint_range(0.5, 10.0) = 3.0;

void fragment() {
	float stripe = sin((UV.x * stripe_density) - TIME * speed);
	stripe = smoothstep(0.4, 1.0, stripe);
	vec3 col = color * stripe;
	ALBEDO = col;
	EMISSION = col * intensity;
}
