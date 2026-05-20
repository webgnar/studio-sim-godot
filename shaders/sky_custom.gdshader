shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.192, 0.612, 1.0);
uniform vec3 sky_horizon_color : source_color = vec3(0.883, 0.796, 0.752);
uniform float sky_curve : hint_range(0.0, 1.0) = 0.0375;
uniform sampler2D sky_cover : source_color, filter_linear_mipmap;
uniform float cover_scale : hint_range(0.1, 10.0) = 1.0;
uniform vec4 cover_modulate : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 ground_bottom_color : source_color = vec3(0.238, 0.497, 0.972);
uniform vec3 ground_horizon_color : source_color = vec3(0.183, 0.0, 0.837);
uniform float night_blend : hint_range(0.0, 1.0) = 0.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.985;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float stars(vec3 dir) {
	vec2 uv = vec2(atan(dir.z, dir.x), asin(dir.y)) * (1.0 / 3.14159265);
	vec2 cell = floor(uv * 200.0);
	float h = hash(cell);
	if (h < star_density) return 0.0;
	vec2 f = fract(uv * 200.0) - 0.5;
	float brightness = (h - star_density) / (1.0 - star_density);
	return brightness * smoothstep(0.08, 0.0, length(f));
}

void sky() {
	float v_angle = EYEDIR.y;

	if (v_angle > 0.0) {
		float sky_blend = 1.0 - pow(1.0 - v_angle, 1.0 / sky_curve);
		COLOR = mix(sky_horizon_color, sky_top_color, clamp(sky_blend, 0.0, 1.0));
	} else {
		float ground_blend = 1.0 - pow(1.0 + v_angle, 1.0 / sky_curve);
		// At night blend ground toward the sky colors so the horizon disappears
		vec3 g_horizon = mix(ground_horizon_color, sky_horizon_color, night_blend);
		vec3 g_bottom  = mix(ground_bottom_color,  sky_top_color,     night_blend);
		COLOR = mix(g_horizon, g_bottom, clamp(ground_blend, 0.0, 1.0));
	}

	// Sky cover (clouds) fades out at night
	vec2 sky_uv = SKY_COORDS;
	sky_uv = (sky_uv - 0.5) * (1.0 / cover_scale) + 0.5;
	vec4 cover = texture(sky_cover, sky_uv);
	cover *= cover_modulate;
	COLOR = mix(COLOR, cover.rgb, cover.a * (1.0 - night_blend));

	// Stars fill the full sphere at night — no hemisphere guard
	float s = stars(EYEDIR) * night_blend;
	COLOR = mix(COLOR, vec3(1.0), s);
}
