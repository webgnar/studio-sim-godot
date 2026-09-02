shader_type spatial;
render_mode unshaded, shadows_disabled;
// Procedural Earth globe for a SphereMesh — no textures, no clouds.
// Seamless: all noise is 3D fbm in object space, and the sample domain
// is offset far from the origin so the hash never mirrors across the
// coordinate planes (that mirroring is what caused the visible seam).
// Ice caps stay, so the poles read white. Fully lit all the way around
// (no day/night side) — this spins on a physics-tumbled ball, not a
// slowly-rotating stationary globe, so a fixed terminator just reads as
// "half the sphere is broken and dark" from whatever angle it lands on.
// Cyan atmosphere rim, HDR through ALBEDO.

// ---- surface palette ----
uniform vec4 ocean_deep : source_color = vec4(0.02, 0.09, 0.28, 1.0);
uniform vec4 ocean_shallow : source_color = vec4(0.05, 0.30, 0.48, 1.0);
uniform vec4 land_low : source_color = vec4(0.13, 0.38, 0.16, 1.0);
uniform vec4 land_high : source_color = vec4(0.55, 0.45, 0.25, 1.0);
uniform vec4 ice_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform vec4 atmo_color : source_color = vec4(0.30, 0.65, 1.0, 1.0); // cyan-blue rim

// ---- world generation ----
uniform float land_scale = 2.4;
uniform float land_threshold : hint_range(0.3, 0.7) = 0.52; // lower = more land
uniform float ice_latitude : hint_range(0.5, 1.0) = 0.78;

// ---- motion ----
uniform float spin_speed = 0.02;
uniform float atmo_strength = 1.8;    // HDR rim for bloom

// keeps every noise lookup in strictly positive territory, well away
// from the origin where the hash's fract() symmetry can draw lines
const vec3 DOMAIN_OFFSET = vec3(157.31, 113.57, 271.13);

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

float hash31(vec3 p) {
	p = fract(p * vec3(0.10314, 0.10921, 0.09713));
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
	p += DOMAIN_OFFSET;
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

	// ---- continents ----
	float h = fbm3(p_land * land_scale);
	float land = smoothstep(land_threshold - 0.025, land_threshold + 0.025, h);
	float elev = smoothstep(land_threshold, land_threshold + 0.22, h);
	elev = floor(elev * 3.0) / 3.0; // banded elevation, comic-book style

	float shallow = smoothstep(land_threshold - 0.13, land_threshold, h);
	vec3 ocean = mix(ocean_deep.rgb, ocean_shallow.rgb, shallow);
	vec3 ground = mix(land_low.rgb, land_high.rgb, elev);
	vec3 surf = mix(ocean, ground, land);

	// ---- polar ice, noisy coastline (your white Antarctica) ----
	float lat = abs(sp.y) + (h - 0.5) * 0.18;
	float ice = smoothstep(ice_latitude, ice_latitude + 0.06, lat);
	surf = mix(surf, ice_color.rgb, ice);

	vec3 col = surf;

	// ---- atmosphere rim (view-space fresnel), HDR for bloom ----
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	col += atmo_color.rgb * fres * atmo_strength;

	ALBEDO = col; // HDR through ALBEDO so the rim feeds bloom
}
