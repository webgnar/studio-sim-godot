shader_type spatial;
// A projected light image for the DJ dance party. Put it on a flat QuadMesh sitting a few cm
// in front of a wall/floor. Additive + unshaded, so it reads as light landing on the surface.
// Shows either `projection_texture` (content added later) or one of the built-in procedural
// geometric patterns, or a pattern built from one of the player's stickers (`sticker_texture`).
// PartyProjector.gd drives pattern / texture / sticker / fade.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D projection_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_texture = false;
uniform int pattern = 0; // 0 polygon rings, 1 kaleidoscope, 2 spiral grid, 3 starburst, 4 mirror-ball specks,
                         // 5 sticker kaleidoscope, 6 sticker gobo
uniform vec4 tint : source_color = vec4(1.0);
uniform float intensity = 1.2;
uniform float speed = 1.0;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.25; // soft lens falloff
uniform bool circular_mask = true;
uniform float fade : hint_range(0.0, 1.0) = 1.0; // crossfade between images
uniform float time_offset = 0.0;
uniform vec2 speck_scale = vec2(24.0, 8.0); // pattern 4: specks across / down the quad
uniform sampler2D sticker_texture : source_color, filter_linear_mipmap, repeat_disable; // patterns 5 and 6
uniform float sticker_aspect = 1.0; // sticker width / height, so it isn't stretched
uniform float kaleido_segments = 8.0; // pattern 5: mirrored wedges
uniform float sticker_seed = 0.0; // varies the colours / spin per sticker

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

mat2 rot(float a) {
	float s = sin(a), c = cos(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

// Distance to a regular n-gon of "radius" r (negative inside).
float sd_ngon(vec2 p, float n, float r) {
	float a = atan(p.x, p.y) + PI;
	float seg = TAU / n;
	return cos(floor(0.5 + a / seg) * seg - a) * length(p) - r;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 polygon_rings(vec2 uv, float t) {
	vec2 p = rot(t * 0.35) * uv;
	float d = sd_ngon(p, 6.0, 0.0);
	float rings = abs(fract(d * 5.0 - t * 0.6) - 0.5);
	float line = smoothstep(0.12, 0.02, rings);
	vec2 q = rot(-t * 0.5) * uv;
	float tri = abs(fract(sd_ngon(q, 3.0, 0.0) * 3.0 + t * 0.3) - 0.5);
	line = max(line, 0.6 * smoothstep(0.06, 0.0, tri));
	return hsv2rgb(vec3(fract(d * 0.4 + t * 0.07), 0.85, 1.0)) * line;
}

vec3 kaleidoscope(vec2 uv, float t) {
	vec2 p = rot(t * 0.2) * uv;
	float a = atan(p.y, p.x);
	float seg = TAU / 8.0;
	a = abs(mod(a, seg) - seg * 0.5);
	vec2 q = vec2(cos(a), sin(a)) * length(p);
	q = rot(t * 0.15) * q * 3.0 - vec2(t * 0.4, 0.0);
	vec2 cell = fract(q) - 0.5;
	float diamond = abs(cell.x) + abs(cell.y);
	float shape = smoothstep(0.42, 0.36, diamond) - smoothstep(0.30, 0.24, diamond);
	float hue = fract(hash21(floor(q)) * 0.3 + t * 0.05 + length(p) * 0.2);
	return hsv2rgb(vec3(hue, 0.9, 1.0)) * shape;
}

vec3 spiral_grid(vec2 uv, float t) {
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	vec2 polar = vec2(a / TAU * 12.0 + t * 0.3, log(max(r, 1e-3)) * 3.0 - t * 0.8);
	vec2 g = abs(fract(polar) - 0.5);
	float line = smoothstep(0.08, 0.0, min(g.x, g.y));
	return hsv2rgb(vec3(fract(polar.y * 0.1 + t * 0.05), 0.8, 1.0)) * line * smoothstep(0.02, 0.2, r);
}

vec3 starburst(vec2 uv, float t) {
	float a = atan(uv.y, uv.x);
	float r = length(uv);
	float rays = pow(max(sin(a * 10.0 + t * 1.5), 0.0), 6.0);
	float rays2 = pow(max(sin(a * 6.0 - t * 1.1 + r * 4.0), 0.0), 10.0);
	float pulse = 0.6 + 0.4 * sin(t * 4.0 - r * 10.0);
	vec3 c1 = hsv2rgb(vec3(fract(t * 0.08), 0.9, 1.0));
	vec3 c2 = hsv2rgb(vec3(fract(t * 0.08 + 0.5), 0.9, 1.0));
	return (c1 * rays + c2 * rays2) * pulse;
}

vec3 specks(vec2 uv01, float t) {
	// Drifting dots, like light thrown off a mirror ball.
	vec2 p = uv01 * speck_scale + vec2(t * 0.6, 0.0);
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash21(id);
	vec2 jitter = (vec2(hash21(id + 7.1), hash21(id + 3.3)) - 0.5) * 0.5;
	float d = length(f - jitter);
	float dot_ = smoothstep(0.12, 0.05, d) * step(0.35, h);
	float twinkle = 0.5 + 0.5 * sin(t * 6.0 + h * 40.0);
	return hsv2rgb(vec3(fract(h * 3.0 + t * 0.05), 0.35, 1.0)) * dot_ * twinkle;
}

// Sticker centred in the unit square [-1, 1], keeping its aspect ratio. Outside it is transparent.
vec4 sample_sticker(vec2 p) {
	vec2 fit = sticker_aspect >= 1.0 ? vec2(1.0, 1.0 / sticker_aspect) : vec2(sticker_aspect, 1.0);
	vec2 suv = p / fit * 0.5 + 0.5;
	if (any(lessThan(suv, vec2(0.0))) || any(greaterThan(suv, vec2(1.0)))) {
		return vec4(0.0);
	}
	return texture(sticker_texture, vec2(suv.x, 1.0 - suv.y));
}

// A slice of the sticker mirrored into rotating wedges. The slice drifts slowly across the
// sticker, so the picture keeps folding into new shapes.
vec3 sticker_kaleidoscope(vec2 uv, float t) {
	vec2 p = rot(t * 0.15) * uv;
	float seg = TAU / kaleido_segments;
	float a = abs(mod(atan(p.y, p.x), seg) - seg * 0.5);
	vec2 q = vec2(cos(a), sin(a)) * length(p);
	vec2 drift = vec2(sin(t * 0.13 + sticker_seed), cos(t * 0.11 + sticker_seed * 1.7)) * 0.3;
	q = rot(-t * 0.08 + sticker_seed) * q * 1.15 + drift;
	// Mirror outside the sticker instead of going dark, so every wedge stays filled.
	q = 1.0 - abs(mod(q + 1.0, 4.0) - 2.0);
	vec4 s = sample_sticker(q * 0.98);
	vec3 col = s.rgb * s.a;
	// Sticker colours with a little extra saturation, plus a faint hue wash where it's transparent.
	col = max(mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, 1.5), 0.0);
	col += hsv2rgb(vec3(fract(sticker_seed * 0.37 + t * 0.04 + length(uv) * 0.3), 0.9, 1.0)) * (1.0 - s.a) * 0.06;
	return col;
}

// The sticker's outline used as a gobo: a solid shape of party light, slowly spinning and
// breathing, with the colour sweeping across it.
vec3 sticker_gobo(vec2 uv, float t) {
	float spin = t * 0.25 * (fract(sticker_seed) > 0.5 ? 1.0 : -1.0);
	float breathe = 1.0 + 0.06 * sin(t * 2.2);
	vec2 p = rot(spin) * uv / (0.82 * breathe);
	float a = sample_sticker(p).a;
	float shape = smoothstep(0.35, 0.6, a);
	// Brighter rim, like the hard edge of a metal gobo.
	float rim = smoothstep(0.15, 0.4, a) - smoothstep(0.6, 0.85, a);
	vec3 c1 = hsv2rgb(vec3(fract(sticker_seed * 0.37 + t * 0.05), 0.85, 1.0));
	vec3 c2 = hsv2rgb(vec3(fract(sticker_seed * 0.37 + t * 0.05 + 0.33), 0.85, 1.0));
	vec3 col = mix(c1, c2, smoothstep(-0.8, 0.8, (rot(t * 0.4) * uv).x));
	return col * shape + vec3(1.0) * rim * 0.6;
}

void fragment() {
	float t = TIME * speed + time_offset;
	vec2 uv = UV * 2.0 - 1.0;
	float mask = 1.0;
	if (circular_mask && pattern != 4) {
		mask = 1.0 - smoothstep(1.0 - edge_softness, 1.0, length(uv));
	} else {
		vec2 e = smoothstep(vec2(0.0), vec2(edge_softness * 0.5), UV) * smoothstep(vec2(0.0), vec2(edge_softness * 0.5), 1.0 - UV);
		mask = e.x * e.y;
	}

	vec3 col;
	if (use_texture) {
		col = texture(projection_texture, UV).rgb;
	} else if (pattern == 0) {
		col = polygon_rings(uv, t);
	} else if (pattern == 1) {
		col = kaleidoscope(uv, t);
	} else if (pattern == 2) {
		col = spiral_grid(uv, t);
	} else if (pattern == 3) {
		col = starburst(uv, t);
	} else if (pattern == 5) {
		col = sticker_kaleidoscope(uv, t);
	} else if (pattern == 6) {
		col = sticker_gobo(uv, t);
	} else {
		col = specks(UV, t);
	}

	ALBEDO = col * tint.rgb * intensity * mask * fade;
}
