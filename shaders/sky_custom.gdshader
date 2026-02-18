shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.192, 0.612, 1.0);
uniform vec3 sky_horizon_color : source_color = vec3(0.883, 0.796, 0.752);
uniform float sky_curve : hint_range(0.0, 1.0) = 0.0375;
uniform sampler2D sky_cover : source_color, filter_linear_mipmap;
uniform float cover_scale : hint_range(0.1, 10.0) = 1.0;
uniform vec4 cover_modulate : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 ground_bottom_color : source_color = vec3(0.238, 0.497, 0.972);
uniform vec3 ground_horizon_color : source_color = vec3(0.183, 0.0, 0.837);

void sky() {
	float v_angle = EYEDIR.y;

	if (v_angle > 0.0) {
		// Sky
		float sky_blend = 1.0 - pow(1.0 - v_angle, 1.0 / sky_curve);
		COLOR = mix(sky_horizon_color, sky_top_color, clamp(sky_blend, 0.0, 1.0));
	} else {
		// Ground
		float ground_blend = 1.0 - pow(1.0 + v_angle, 1.0 / sky_curve);
		COLOR = mix(ground_horizon_color, ground_bottom_color, clamp(ground_blend, 0.0, 1.0));
	}

	// Sky cover texture with adjustable scale
	vec2 sky_uv = SKY_COORDS;
	sky_uv = (sky_uv - 0.5) * (1.0 / cover_scale) + 0.5;
	vec4 cover = texture(sky_cover, sky_uv);
	cover *= cover_modulate;
	COLOR = mix(COLOR, cover.rgb, cover.a);
}
