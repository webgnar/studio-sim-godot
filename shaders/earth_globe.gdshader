shader_type spatial;
render_mode unshaded, shadows_disabled;
// Procedural Earth globe for a SphereMesh — no textures needed.
// Continents, ice caps, and a separate cloud layer are all 3D fbm
// sampled in object space, so there's no UV seam and no pole pinch.
// Lighting is computed in-shader (cel-banded terminator) to stay
// consistent with the unshaded/bloom pipeline.

// ---- surface palette ----
uniform vec4 ocean_deep : source_color = vec4(0.02, 0.09, 0.28, 1.0);
uniform vec4 ocean_shallow : source_color = vec4(0.05, 0.30, 0.48, 1.0);
uniform vec4 land_low : source_color = vec4(0.13, 0.38, 0.16, 1.0);
uniform vec4 land_high : source_color = vec4(0.55, 0.45, 0.25, 1.0);
uniform vec4 ice_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 night_color : source_color = vec4(0.01, 0.015, 0.05, 1.0);
uniform vec4 city_color : source_color = vec4(1.0, 0.72, 0.30, 1.0); // amber
uniform vec4 atmo_color : source_color = vec4(0.30, 0.65, 1.0, 1.0); // cyan-blue rim

// ---- world generation ----
uniform float land_scale = 2.4;
uniform float land_threshold : hint_range(0.3, 0.7) = 0.52; // lower = more land
uniform float ice_latitude : hint_range(0.5, 1.0) = 0.78;

// ---- clouds ----
uniform float cloud_scale = 3.2;
uniform float cloud_threshold : hint_range(0.3, 0.8) = 0.55; // lower = more clouds
uniform float cloud_drift = 0.010; // extra spin vs. the ground

// ---- motion & light ----
uniform float spin_speed = 0.02;
uniform vec3 sun_dir = vec3(0.65, 0.25, 0.72);
uniform float light_bands = 3.0;      // cel steps on the day side (0 = smooth)
uniform float city_intensity = 2.5;   // HDR for bloom
uniform float atmo_strength = 1.8;    // HDR rim for bloom

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
		mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
		u.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += vnoise3(p) * amp;
		p = p * 2.07 + vec3(11.5, 7.3, 3.1);
		amp *= 0.5;
	}
	return v;
}

vec3 rot_y(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

void fragment() {
	vec3 sp = normalize(obj_pos);
	vec3 p_land = rot_y(sp, TIME * spin_speed);
	vec3 p_cloud = rot_y(sp, TIME * (spin_speed + cloud_drift));

	// ---- continents ----
	float h = fbm3(p_land * land_scale);
	float land = smoothstep(land_threshold - 0.025, land_threshold + 0.025, h);
	float elev = smoothstep(land_threshold, land_threshold + 0.22, h);
	elev = floor(elev * 3.0) / 3.0; // banded elevation, comic-book style

	float shallow = smoothstep(land_threshold - 0.13, land_threshold, h);
	vec3 ocean = mix(ocean_deep.rgb, ocean_shallow.rgb, shallow);
	vec3 ground = mix(land_low.rgb, land_high.rgb, elev);
	vec3 surf = mix(ocean, ground, land);

	// ---- polar ice, noisy coastline ----
	float lat = abs(sp.y) + (h - 0.5) * 0.18;
	float ice = smoothstep(ice_latitude, ice_latitude + 0.06, lat);
	surf = mix(surf, ice_color.rgb, ice);

	// ---- clouds (independent layer, slightly faster spin) ----
	float cn = fbm3(p_cloud * cloud_scale + vec3(0.0, TIME * 0.015, 0.0));
	float clouds = smoothstep(cloud_threshold, cloud_threshold + 0.16, cn);
	surf *= 1.0 - clouds * 0.18; // cheap cloud shadow on the ground

	// ---- day/night terminator, cel-banded ----
	vec3 n = normalize(obj_normal);
	vec3 sun = normalize(sun_dir);
	float day = smoothstep(-0.12, 0.28, dot(n, sun));
	if (light_bands > 0.5) {
		day = floor(day * light_bands + 0.5) / light_bands;
	}

	vec3 col = mix(night_color.rgb, surf, day);
	col = mix(col, cloud_color.rgb * max(day, 0.06), clouds);

	// ---- night-side city lights on land ----
	float sparkle = step(0.965, vnoise3(p_land * 60.0));
	float city = sparkle * land * (1.0 - ice) * (1.0 - day) * (1.0 - clouds);
	col += city_color.rgb * city * city_intensity;

	// ---- atmosphere rim (view-space fresnel), HDR for bloom ----
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	col += atmo_color.rgb * fres * atmo_strength * (day * 0.75 + 0.25);

	ALBEDO = col; // HDR through ALBEDO so rim + cities feed bloom
}
