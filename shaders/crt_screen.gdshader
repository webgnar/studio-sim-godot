shader_type spatial;
// Curved CRT monitor for arcade screens (Lou Gnar cabinet). Samples a SubViewport texture with
// barrel distortion (the fisheye bulge of a curved tube), rounded black corners, soft scanlines,
// a faint aperture-grille tint and a vignette. No static/noise: the only motion is a very slow,
// faint brightness roll so the tube feels alive.
render_mode unshaded, cull_back;

uniform sampler2D tv_tex : source_color, filter_linear;
uniform float curvature : hint_range(1.5, 20.0) = 3.6; // lower = more bulge
uniform float corner_radius : hint_range(0.0, 0.3) = 0.08;
uniform float scanline_count = 300.0; // dark lines across the screen height
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
uniform float grille_strength : hint_range(0.0, 0.5) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float brightness = 1.2;
uniform float roll_speed = 0.05;
uniform float roll_strength : hint_range(0.0, 0.2) = 0.025;

vec2 barrel(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	vec2 offset = c.yx / curvature;
	c += c * offset * offset;
	return c * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = barrel(UV);

	// Black outside the bent picture, with rounded tube corners.
	vec2 q = abs(uv - 0.5) * 2.0;
	vec2 corner = max(q - (1.0 - corner_radius), 0.0);
	float tube = 1.0 - smoothstep(corner_radius - 0.015, corner_radius, length(corner));
	tube *= step(q.x, 1.0) * step(q.y, 1.0);

	vec3 col = texture(tv_tex, clamp(uv, 0.0, 1.0)).rgb;

	// Soft horizontal scanlines.
	float scan = 0.5 + 0.5 * cos(uv.y * scanline_count * TAU);
	col *= 1.0 - scanline_strength * (1.0 - scan);

	// Faint RGB aperture grille.
	float g = mod(floor(FRAGCOORD.x), 3.0);
	vec3 grille = vec3(g == 0.0 ? 1.0 : 1.0 - grille_strength,
			g == 1.0 ? 1.0 : 1.0 - grille_strength,
			g == 2.0 ? 1.0 : 1.0 - grille_strength);
	col *= grille;

	// Vignette toward the curved edges.
	float vig = clamp(16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y), 0.0, 1.0);
	col *= mix(1.0, pow(vig, 0.3), vignette_strength);

	// Very slow, faint rolling brightness band.
	col *= 1.0 + roll_strength * sin((uv.y - TIME * roll_speed) * TAU);

	ALBEDO = col * brightness * tube;
}
