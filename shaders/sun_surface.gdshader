shader_type spatial;
render_mode unshaded;

uniform vec4 sun_color  : source_color = vec4(1.0,  0.50, 0.08, 1.0);
uniform vec4 hot_color  : source_color = vec4(1.0,  0.95, 0.70, 1.0);
uniform vec4 dark_color : source_color = vec4(0.25, 0.10, 0.02, 1.0);

uniform float time_scale        : hint_range(0.0, 2.0)   = 0.08;
uniform float uv_scale          : hint_range(0.5, 6.0)   = 2.5;
uniform float cell_contrast     : hint_range(0.5, 4.0)   = 2.0;
uniform float fbm_strength      : hint_range(0.0, 1.0)   = 0.18;
uniform float limb_power        : hint_range(0.3, 3.0)   = 0.6;
uniform float emission_strength : hint_range(1.0, 20.0)  = 6.0;
uniform int   sunspot_count     : hint_range(0, 5)       = 3;
uniform float sunspot_size      : hint_range(0.02, 0.25) = 0.09;
uniform float spot_drift_speed  : hint_range(0.0, 0.5)   = 0.04;

vec2 hash2(vec2 p) {
	float x = fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
	float y = fract(sin(dot(p, vec2(269.5, 183.3))) * 12345.6789);
	return vec2(x, y);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Returns (min_dist_to_nearest_point, cell_id).
// min_dist near 0 = boundary seam, near 0.5 = cell center.
vec2 voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_d = 8.0;
	float cell_id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash2(i + neighbor);
			float d = length(neighbor + point - f);
			if (d < min_d) {
				min_d = d;
				cell_id = hash1(i + neighbor);
			}
		}
	}
	return vec2(min_d, cell_id);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash1(i);
	float b = hash1(i + vec2(1.0, 0.0));
	float c = hash1(i + vec2(0.0, 1.0));
	float d = hash1(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2(vec2 p) {
	return vnoise(p) * 0.6 + vnoise(p * 2.1 + vec2(5.3, 1.7)) * 0.4;
}

void fragment() {
	float t = TIME * time_scale;
	vec2 uv_base  = UV * uv_scale;
	vec2 uv_cells = uv_base + vec2(t * 0.7, t * 0.4);

	// Voronoi granulation — bold convection cells with hard boundaries
	vec2  vor          = voronoi(uv_cells);
	float cell_interior = pow(clamp(vor.x * 2.0, 0.0, 1.0), cell_contrast);

	// FBM detail overlay — breaks up cell regularity at close range
	vec2  uv_fbm = uv_base * 3.2 + vec2(-t * 0.5, t * 0.9);
	float plasma = fbm2(uv_fbm);
	float surface = clamp(cell_interior + plasma * fbm_strength - fbm_strength * 0.5, 0.0, 1.0);

	// Two-step color: boundary → orange → yellow-white center
	vec3 base_col;
	if (surface < 0.5) {
		base_col = mix(dark_color.rgb, sun_color.rgb, surface * 2.0);
	} else {
		base_col = mix(sun_color.rgb, hot_color.rgb, (surface - 0.5) * 2.0);
	}

	// Sunspots — compared against raw UV so they drift independently of the plasma field
	float spot_mask = 0.0;
	for (int i = 0; i < sunspot_count; i++) {
		vec2 seed = vec2(float(i) * 3.7, float(i) * 5.1 + 1.3);
		vec2 rnd  = hash2(seed);
		float drift   = TIME * spot_drift_speed * (0.8 + rnd.x * 0.4);
		vec2  spot_pos = vec2(fract(rnd.x + drift), mix(0.3, 0.7, rnd.y));
		vec2  delta    = abs(UV - spot_pos);
		delta.x = min(delta.x, 1.0 - delta.x);  // handle U wrap
		float s = 1.0 - smoothstep(sunspot_size * 0.4, sunspot_size, length(delta));
		spot_mask = max(spot_mask, s);
	}
	base_col = mix(base_col, dark_color.rgb * 0.5, spot_mask * 0.85);

	// Limb darkening — edges darker, matching real solar photography
	float limb = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), limb_power);
	base_col = mix(dark_color.rgb * 0.6, base_col, limb);

	ALBEDO   = base_col;
	EMISSION = base_col * emission_strength * (1.0 + surface * 0.4) * limb;
}
