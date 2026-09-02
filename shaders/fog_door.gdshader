shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// Dark Souls-style fog door for a CSGBox3D. Swirling white/gray cloud
// wall, wispy at the edges, denser in the middle. Animate `dissolve`
// 0 -> 1 in code when the player traverses to burn the wall away.

uniform vec4 color_dark : source_color = vec4(0.55, 0.56, 0.62, 1.0); // shadowed gray
uniform vec4 color_light : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // cloud highlights
uniform float brightness : hint_range(0.5, 4.0) = 1.6; // HDR push via ALBEDO for bloom

uniform float cloud_scale = 3.0;
uniform float swirl_amount : hint_range(0.0, 8.0) = 2.6;
uniform float swirl_speed = 0.25;
uniform vec2 drift = vec2(0.03, -0.06);   // slow upward-ish churn
uniform float warp_strength = 0.35;       // domain warp = billowy look
uniform float density : hint_range(0.0, 2.0) = 1.0;
uniform float edge_softness : hint_range(0.01, 0.5) = 0.22; // fade at box edges

uniform float dissolve : hint_range(0.0, 1.0) = 0.0; // 0 = solid wall, 1 = gone
uniform float dissolve_edge = 0.08;                  // width of the bright burn rim
uniform vec4 dissolve_rim_color : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform float dissolve_rim_boost = 3.0;              // HDR rim for bloom pop

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * amp;
		p = p * 2.03 + vec2(17.3, 9.1);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;

	// swirl around the center of the face, stronger near the middle
	vec2 c = uv - 0.5;
	float r = length(c);
	float ang = (1.0 - smoothstep(0.0, 0.7, r)) * swirl_amount + TIME * swirl_speed;
	float cs = cos(ang);
	float sn = sin(ang);
	c = vec2(cs * c.x - sn * c.y, sn * c.x + cs * c.y);
	vec2 suv = c + 0.5 + drift * TIME;

	// domain-warped fbm: one field bends the lookup of the second
	vec2 p = suv * cloud_scale;
	vec2 warp = vec2(
		fbm(p + vec2(0.0, TIME * 0.15)),
		fbm(p + vec2(5.2, 1.3) - vec2(TIME * 0.12, 0.0))
	);
	float clouds = fbm(p + warp * warp_strength * cloud_scale + vec2(0.0, TIME * 0.1));

	// second finer layer scrolling the other way for depth
	float wisps = fbm(p * 2.2 - vec2(TIME * 0.08, TIME * 0.05) + warp * 0.6);
	float n = clouds * 0.7 + wisps * 0.3;

	// shape it: denser core, wispy falloff
	float body = smoothstep(0.32, 0.72, n * density);

	// soft fade at the quad edges so the wall reads as vapor, not a decal
	vec2 e = min(uv, 1.0 - uv);
	float edge_fade = smoothstep(0.0, edge_softness, e.x) * smoothstep(0.0, edge_softness, e.y);

	// dissolve burn-away, driven by the same noise so it tears organically
	float cut = n - dissolve * (1.0 + dissolve_edge * 2.0);
	float alive = smoothstep(0.0, dissolve_edge, cut);
	float rim = smoothstep(0.0, dissolve_edge, cut) - smoothstep(dissolve_edge, dissolve_edge * 2.0, cut);

	vec3 col = mix(color_dark.rgb, color_light.rgb, body) * brightness;
	col += dissolve_rim_color.rgb * rim * dissolve_rim_boost * step(0.001, dissolve);

	float alpha = body * edge_fade * alive;
	alpha = clamp(alpha + rim * edge_fade * 0.8 * step(0.001, dissolve), 0.0, 1.0);

	ALBEDO = col; // HDR through ALBEDO so it feeds WorldEnvironment bloom
	ALPHA = alpha;
}
