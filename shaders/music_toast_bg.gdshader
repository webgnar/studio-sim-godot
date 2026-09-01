shader_type canvas_item;
// Earthbound-style scrolling background for the "now playing" toast.
// Dark base so white/light text stays readable. Drop on a ColorRect
// (or TextureRect) sitting behind your Label.

// ---- palette (tuned to amber/purple/cyan identity, kept dark) ----
uniform vec4 color_bg : source_color = vec4(0.045, 0.030, 0.085, 1.0); // near-black purple
uniform vec4 color_bg2 : source_color = vec4(0.085, 0.045, 0.130, 1.0); // stripe tint
uniform vec4 color_note_a : source_color = vec4(0.55, 0.35, 0.90, 1.0); // muted purple
uniform vec4 color_note_b : source_color = vec4(0.95, 0.62, 0.20, 1.0); // amber accent

// ---- motion ----
uniform vec2 scroll_speed = vec2(0.055, -0.028); // diagonal drift
uniform float wave_amp : hint_range(0.0, 0.08) = 0.018; // EB wobble strength
uniform float wave_freq = 6.0;
uniform float wave_speed = 1.4;

// ---- layout / look ----
uniform vec2 tiles = vec2(6.0, 3.0);          // note density (x, y)
uniform float note_alpha : hint_range(0.0, 1.0) = 0.35; // keep low = text pops
uniform float stripe_strength : hint_range(0.0, 1.0) = 0.6;
uniform float cycle_speed = 0.6;              // purple<->amber shift
uniform float posterize_steps = 6.0;          // 0.0 disables

float ellipse_mask(vec2 p, vec2 c, vec2 r, float rot) {
	vec2 d = p - c;
	float cs = cos(rot);
	float sn = sin(rot);
	d = vec2(cs * d.x - sn * d.y, sn * d.x + cs * d.y) / r;
	return 1.0 - smoothstep(0.88, 1.0, length(d));
}

float seg_mask(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	float d = length(pa - ba * h);
	return 1.0 - smoothstep(w * 0.75, w, d);
}

// single eighth note, drawn in 0..1 cell space
float eighth_note(vec2 p) {
	float m = ellipse_mask(p, vec2(0.40, 0.70), vec2(0.115, 0.085), -0.35);
	m = max(m, seg_mask(p, vec2(0.505, 0.685), vec2(0.505, 0.27), 0.030));
	// flag sweeping down-right off the stem tip
	m = max(m, seg_mask(p, vec2(0.505, 0.27), vec2(0.61, 0.36), 0.045));
	m = max(m, seg_mask(p, vec2(0.61, 0.36), vec2(0.635, 0.50), 0.032));
	return m;
}

// beamed pair of eighth notes
float beam_notes(vec2 p) {
	float m = ellipse_mask(p, vec2(0.29, 0.735), vec2(0.105, 0.080), -0.35);
	m = max(m, ellipse_mask(p, vec2(0.645, 0.675), vec2(0.105, 0.080), -0.35));
	m = max(m, seg_mask(p, vec2(0.385, 0.715), vec2(0.385, 0.305), 0.028));
	m = max(m, seg_mask(p, vec2(0.740, 0.655), vec2(0.740, 0.245), 0.028));
	m = max(m, seg_mask(p, vec2(0.385, 0.305), vec2(0.740, 0.245), 0.058)); // beam
	return m;
}

void fragment() {
	vec2 uv = UV;

	// Earthbound wobble: warp the whole field with slow sines
	uv.x += sin(uv.y * wave_freq + TIME * wave_speed) * wave_amp;
	uv.y += cos(uv.x * wave_freq * 0.7 + TIME * wave_speed * 0.8) * wave_amp;

	// warped diagonal stripes in the background
	float stripe = sin((uv.x + uv.y) * 11.0 - TIME * 0.7) * 0.5 + 0.5;
	stripe = smoothstep(0.30, 0.70, stripe);
	vec3 col = mix(color_bg.rgb, color_bg2.rgb, stripe * stripe_strength);

	// scrolling brick grid of cells
	vec2 guv = uv * tiles + scroll_speed * tiles * TIME;
	guv.x += mod(floor(guv.y), 2.0) * 0.5; // offset alternate rows
	vec2 id = floor(guv);
	vec2 cell = fract(guv);

	// per-cell wobble rotation for that hand-drawn sway
	float wob = sin(TIME * 1.2 + id.x * 1.7 + id.y * 2.3) * 0.12;
	vec2 cp = cell - 0.5;
	float cs = cos(wob);
	float sn = sin(wob);
	cp = vec2(cs * cp.x - sn * cp.y, sn * cp.x + cs * cp.y);
	cp = cp / 0.82 + 0.5; // shrink glyph a touch inside the cell

	// alternate glyphs checkerboard-style
	float g = mod(id.x + id.y, 2.0) < 1.0 ? eighth_note(cp) : beam_notes(cp);

	// slow purple<->amber palette cycle, phase-shifted per cell
	float cyc = sin(TIME * cycle_speed + id.x * 0.9 + id.y * 1.3) * 0.5 + 0.5;
	vec3 note_col = mix(color_note_a.rgb, color_note_b.rgb, cyc);

	col = mix(col, note_col, g * note_alpha);

	// optional cel-band posterize to match the rest of the shader library
	if (posterize_steps > 0.5) {
		col = floor(col * posterize_steps) / posterize_steps;
	}

	COLOR = vec4(col, color_bg.a);
}
