shader_type spatial;
// A projected light image for the DJ dance party. Put it on a flat QuadMesh sitting a few cm
// in front of a wall/floor. Additive + unshaded, so it reads as light landing on the surface.
// Shows either `projection_texture` (content added later) or one of the built-in procedural
// geometric patterns. PartyProjector.gd drives pattern / texture / fade.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D projection_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_texture = false;
uniform int pattern = 0; // 0 polygon rings, 1 kaleidoscope, 2 spiral grid, 3 starburst, 4 mirror-ball specks
uniform vec4 tint : source_color = vec4(1.0);
uniform float intensity = 1.2;
uniform float speed = 1.0;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.25; // soft lens falloff
uniform bool circular_mask = true;
uniform float fade : hint_range(0.0, 1.0) = 1.0; // crossfade between images
uniform float time_offset = 0.0;
uniform vec2 speck_scale = vec2(24.0, 8.0); // pattern 4: specks across / down the quad

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
	} else {
		col = specks(UV, t);
	}

	ALBEDO = col * tint.rgb * intensity * mask * fade;
}
