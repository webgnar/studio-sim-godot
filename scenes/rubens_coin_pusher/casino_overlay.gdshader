shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D screen_tex : hint_screen_texture;

// --- CRT base ---
uniform float scanline_intensity  = 0.15;
uniform float flicker_intensity   = 0.04;
uniform float aberration          = 0.003;
uniform float distortion          = 0.012;
uniform float brightness          = 1.3;

// --- Casino effects ---
uniform float color_cycle_speed   = 0.8;   // how fast the neon border cycles colors
uniform float neon_edge_width     = 0.07;  // fraction of UV space for the glow band
uniform float neon_intensity      = 0.9;
uniform float bar_speed           = 0.35;  // sweeping light bar (0 = off)
uniform float bar_width           = 0.03;
uniform float bar_intensity       = 0.25;
uniform float sparkle_density     = 60.0;  // grid resolution for sparkle points
uniform float sparkle_brightness  = 2.0;
uniform float gold_pulse          = 0.12;  // strength of the warm gold color wash

// ---- helpers ----

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Four-stop casino neon cycle: gold → hot-pink → cyan → neon-green → gold
vec3 neon_color(float t) {
    vec3 gold  = vec3(1.00, 0.80, 0.10);
    vec3 pink  = vec3(1.00, 0.10, 0.65);
    vec3 cyan  = vec3(0.10, 0.90, 1.00);
    vec3 green = vec3(0.20, 1.00, 0.30);
    float s = fract(t);
    if (s < 0.25) return mix(gold,  pink,  s * 4.0);
    if (s < 0.50) return mix(pink,  cyan,  (s - 0.25) * 4.0);
    if (s < 0.75) return mix(cyan,  green, (s - 0.50) * 4.0);
    return             mix(green, gold,  (s - 0.75) * 4.0);
}

void fragment() {
    // ---- screen texture with CRT distortion ----
    vec2 uv = SCREEN_UV;
    vec2 c  = uv - 0.5;
    uv += c * length(c) * distortion;

    float r = texture(screen_tex, uv + vec2(aberration, 0.0)).r;
    float g = texture(screen_tex, uv).g;
    float b = texture(screen_tex, uv - vec2(aberration, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // scanlines
    col -= sin(uv.y * 600.0) * scanline_intensity;

    // per-frame flicker
    float flicker = fract(sin(dot(uv * TIME, vec2(12.9898, 78.233))) * 43758.5453);
    col *= 1.0 + (flicker - 0.5) * flicker_intensity;

    // ---- casino layer (all in mesh UV space) ----

    // 1. animated neon border glow
    float ex = smoothstep(0.0, neon_edge_width, UV.x) * smoothstep(1.0, 1.0 - neon_edge_width, UV.x);
    float ey = smoothstep(0.0, neon_edge_width, UV.y) * smoothstep(1.0, 1.0 - neon_edge_width, UV.y);
    float edge = 1.0 - ex * ey; // 1 on the border, 0 in the interior

    // double-pulse the edge so it flashes as well as color-cycles
    float border_pulse = 0.75 + 0.25 * sin(TIME * color_cycle_speed * TAU);
    col += neon_color(TIME * color_cycle_speed * 0.25) * edge * neon_intensity * border_pulse;

    // 2. sweeping vertical light bar
    float bar_x   = fract(TIME * bar_speed);
    float bar_mask = smoothstep(bar_width, 0.0, abs(UV.x - bar_x));
    col += neon_color(TIME * color_cycle_speed * 0.25 + 0.5) * bar_mask * bar_intensity;

    // 3. twinkling sparkles scattered over the surface
    vec2 spark_cell = floor(UV * sparkle_density);
    float seed      = hash(spark_cell);
    // each cell blinks at its own speed / phase
    float blink = fract(TIME * (1.0 + seed * 3.0) + seed * 7.0);
    float on    = step(0.94, seed); // only ~6% of cells ever sparkle
    float shape = smoothstep(0.0, 0.15, blink) * smoothstep(1.0, 0.55, blink);
    col += on * shape * neon_color(seed * 3.0 + TIME * 0.5) * sparkle_brightness;

    // 4. warm gold colour wash that pulses gently
    float pulse = sin(TIME * 1.8) * 0.5 + 0.5;
    col *= mix(vec3(1.0), vec3(1.15, 0.95, 0.65), pulse * gold_pulse);

    col *= brightness;

    ALBEDO = col;
    ALPHA  = length(col) * 0.65;
}
