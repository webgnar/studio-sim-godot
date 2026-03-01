shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec4 water_color : source_color = vec4(0.05, 0.35, 0.75, 0.25);
uniform float wave_speed : hint_range(0.0, 5.0) = 1.8;
uniform float wave_scale : hint_range(1.0, 20.0) = 8.0;
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.06;
uniform float fresnel_power : hint_range(1.0, 8.0) = 2.5;
uniform float fresnel_opacity : hint_range(0.0, 1.0) = 0.85;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.18;
uniform float caustic_speed : hint_range(0.0, 3.0) = 0.9;
uniform float caustic_scale : hint_range(1.0, 20.0) = 6.0;

// Cheap caustic pattern from layered sin waves
float caustics(vec2 uv, float t) {
	float c = 0.0;
	c += sin(uv.x * caustic_scale + t * 1.1) * sin(uv.y * caustic_scale * 0.9 - t * 0.8);
	c += sin(uv.x * caustic_scale * 1.4 - t * 0.7 + uv.y * 2.0) * 0.6;
	c += sin((uv.x + uv.y) * caustic_scale * 0.8 + t * 1.3) * 0.4;
	return clamp(c * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	float t = TIME * wave_speed;

	// Multi-directional ripple distortion
	vec2 uv = UV;
	float dx = sin(uv.y * wave_scale + t) * 0.5
			 + sin(uv.y * wave_scale * 2.3 - t * 0.7 + uv.x * 3.0) * 0.3
			 + sin(uv.x * wave_scale * 1.5 + t * 1.2) * 0.2;
	float dy = cos(uv.x * wave_scale * 0.9 + t * 0.8) * 0.5
			 + cos(uv.y * wave_scale * 1.8 - t * 0.5) * 0.3;

	vec2 distort = vec2(dx, dy) * refraction_strength;

	// Sample screen with distortion
	vec3 refracted = texture(SCREEN_TEXTURE, SCREEN_UV + distort).rgb;

	// Water tint over refracted scene
	vec3 tinted = mix(refracted, water_color.rgb, water_color.a);

	// Caustic light shimmer on top
	float caust = caustics(uv, TIME * caustic_speed);
	float caust2 = caustics(uv * 1.3 + vec2(0.4, 0.7), TIME * caustic_speed * 0.6);
	float caustic_mask = pow(caust * caust2, 2.0);
	tinted += water_color.rgb * caustic_mask * caustic_strength;

	// Fresnel rim
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	float alpha = mix(water_color.a, fresnel_opacity, fresnel);

	ALBEDO = tinted;
	ALPHA = alpha;
}
