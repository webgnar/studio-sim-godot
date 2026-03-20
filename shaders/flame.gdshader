shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float speed : hint_range(0.5, 10.0) = 2.5;
uniform float strength : hint_range(0.1, 3.0) = 1.2;
uniform float taper : hint_range(0.5, 5.0) = 2.2;
uniform float noise_scale : hint_range(1.0, 8.0) = 3.5;
uniform float flicker_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec3 color_core : source_color = vec3(1.0, 1.0, 0.7);
uniform vec3 color_mid : source_color = vec3(1.0, 0.45, 0.05);
uniform vec3 color_tip : source_color = vec3(0.85, 0.04, 0.0);
uniform float emission_strength : hint_range(1.0, 16.0) = 5.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// FBM: 3 octaves for organic turbulence
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = p * 2.1 + vec2(1.3, 0.7);
		a *= 0.48;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	// y=0 at base (hot), y=1 at tip
	float cy = uv.y;
	float cx = uv.x * 2.0 - 1.0; // center to [-1, 1]

	float t = TIME * speed;

	// Two noise layers: main shape + sway warp
	vec2 np = vec2(cx * noise_scale * 0.7, cy * noise_scale - t);
	float n = fbm(np);

	// Lateral sway using a second noise pass
	float sway = (fbm(np * 0.5 + vec2(3.7, -t * 0.4)) - 0.5) * 0.35;
	float cx_warped = cx + sway;

	// Taper: wide at base, narrow at tip
	float width = pow(1.0 - cy, taper) * 0.75;

	// Smooth mask — 1.0 inside flame boundary, 0.0 outside
	float mask = smoothstep(width + 0.08, width - 0.12, abs(cx_warped));

	// Combine mask with turbulence noise
	float flame = mask * (n * strength);

	// Fade near tip so it dissolves cleanly
	flame *= smoothstep(1.0, 0.55, cy);

	// Subtle flicker pulse
	float flicker = 1.0 + sin(TIME * 19.7 + 0.3) * flicker_strength;
	flame *= flicker;

	flame = clamp(flame, 0.0, 1.0);

	// Core-white -> orange -> red gradient from base to tip
	vec3 col = mix(color_core, color_mid, cy);
	col = mix(col, color_tip, cy * cy);

	ALBEDO = col;
	EMISSION = col * flame * emission_strength;
	ALPHA = flame;
}
