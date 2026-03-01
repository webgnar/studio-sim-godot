shader_type spatial;
render_mode unshaded, cull_disabled;

// ─── Signal ───────────────────────────────────────────────────────────────────
uniform int   waveform       : hint_range(0, 5)       = 0;   // 0=sine 1=square 2=sawtooth 3=triangle
uniform float amplitude      : hint_range(0.0, 0.5)   = .28;
uniform float frequency      : hint_range(0.1, 20.0)  = 2.0;
uniform float speed          : hint_range(0.0, 10.0)  = 2.0;

// ─── Line appearance ──────────────────────────────────────────────────────────
uniform vec3  line_color     : source_color             = vec3(0.0, 1.0, 0.2);
uniform float line_thickness : hint_range(0.001, 0.05)  = 0.007;
uniform float glow_intensity : hint_range(0.0, 12.0)    = 4.0;

// ─── Phosphor persistence ─────────────────────────────────────────────────────
uniform float trail_decay     : hint_range(0.3, 0.95)  = 1;
uniform float trail_step_time : hint_range(0.005, 0.15) = 0.1;

// ─── Grid ─────────────────────────────────────────────────────────────────────
uniform float grid_divisions   : hint_range(2.0, 20.0) = 10.0;
uniform float major_grid_alpha : hint_range(0.0, 1.0)  = 0.15;
uniform float minor_grid_alpha : hint_range(0.0, 1.0)  = 0.05;
uniform int   minor_per_major  : hint_range(2, 10)     = 5;

// ─── Screen effects ───────────────────────────────────────────────────────────
uniform float curvature         : hint_range(0.0, 0.4)    = 0.1;
uniform float vignette_power    : hint_range(0.0, 2.0)    = 0.5;
uniform float scanline_strength : hint_range(0.0, 0.4)    = 0.07;
uniform float scanline_count    : hint_range(20.0, 500.0) = 120.0;
uniform float noise_strength    : hint_range(0.0, 0.1)    = 0.012;

// ─── Background ───────────────────────────────────────────────────────────────
uniform vec3 bg_color : source_color = vec3(0.0, 0.015, 0.005);

// ─────────────────────────────────────────────────────────────────────────────

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float get_wave(float x, float t) {
	float phase = (x + t * speed) * frequency;
	if (waveform == 1) {
		// Square
		return sign(sin(phase)) * amplitude;
	} else if (waveform == 2) {
		// Sawtooth
		return (fract(phase / TAU) * 2.0 - 1.0) * amplitude;
	} else if (waveform == 3) {
		// Triangle
		return (abs(fract(phase / TAU) * 2.0 - 1.0) * 2.0 - 1.0) * amplitude;
	}
	// Sine (default)
	return sin(phase) * amplitude;
}

// Sample beam brightness at a UV coordinate for a given time.
// Uses finite-difference slope to dim the beam where the trace moves fast —
// matching how a real CRT electron beam works (dwell time = brightness).
float sample_trace(vec2 uv, float t) {
	float x      = uv.x * 2.0 - 1.0;
	float wave_y = 0.5 + get_wave(x, t);
	float dist   = abs(uv.y - wave_y);

	float dx    = 0.002;
	float slope = abs(get_wave(x + dx, t) - get_wave(x - dx, t)) / (2.0 * dx);
	float beam  = 1.0 / (1.0 + slope * 1.5);

	float core = smoothstep(line_thickness, 0.0, dist) * beam;
	float halo = smoothstep(line_thickness * 7.0, 0.0, dist) * 0.2 * beam;
	return core + halo;
}

void fragment() {
	vec2 uv = UV;

	// ── CRT barrel distortion ──
	vec2 p = uv * 2.0 - 1.0;
	p.x *= 1.0 + p.y * p.y * curvature;
	p.y *= 1.0 + p.x * p.x * curvature;
	uv = p * 0.5 + 0.5;

	// Hard screen edge with tiny AA border
	vec2 border      = smoothstep(0.0, 0.008, uv) * smoothstep(1.0, 0.992, uv);
	float screen_mask = border.x * border.y;

	// ── Phosphor persistence: 6 time-lagged samples ──
	// Manually unrolled for broad GPU compatibility.
	float b = 0.0;
	float w = 1.0;
	b += sample_trace(uv, TIME)                          * w; w *= trail_decay;
	b += sample_trace(uv, TIME - trail_step_time)        * w; w *= trail_decay;
	b += sample_trace(uv, TIME - trail_step_time * 2.0)  * w; w *= trail_decay;
	b += sample_trace(uv, TIME - trail_step_time * 3.0)  * w; w *= trail_decay;
	b += sample_trace(uv, TIME - trail_step_time * 4.0)  * w; w *= trail_decay;
	b += sample_trace(uv, TIME - trail_step_time * 5.0)  * w;

	vec3 wave_col = line_color * b;

	// ── Grid ──
	// Major lines
	vec2 gv = uv * grid_divisions;
	vec2 gf = abs(fract(gv - 0.5) - 0.5);
	vec2 gw = fwidth(gv);
	float major = 1.0 - smoothstep(0.0, 1.5, min(gf.x / gw.x, gf.y / gw.y));

	// Minor lines (don't overdraw major)
	vec2 mv = uv * grid_divisions * float(minor_per_major);
	vec2 mf = abs(fract(mv - 0.5) - 0.5);
	vec2 mw = fwidth(mv);
	float minor = (1.0 - smoothstep(0.0, 1.5, min(mf.x / mw.x, mf.y / mw.y))) * (1.0 - major);

	vec3 grid_col = line_color * (major * major_grid_alpha + minor * minor_grid_alpha);

	// ── Scanlines (use pre-distortion UV so lines stay straight) ──
	float scan = 1.0 - scanline_strength * (0.5 + 0.5 * sin(UV.y * scanline_count * PI));

	// ── CRT noise ──
	float noise = (hash21(UV + vec2(TIME, TIME * 0.7)) - 0.5) * noise_strength;

	// ── Vignette ──
	vec2 vc = uv * 2.0 - 1.0;
	float vig = 1.0 - vignette_power * pow(dot(vc, vc), 1.2);
	vig = max(vig, 0.0);

	// ── Composite ──
	vec3 col = (bg_color + wave_col + grid_col + noise) * scan * vig * screen_mask;

	ALBEDO   = clamp(col, 0.0, 1.0);
	EMISSION = col * glow_intensity;
}
