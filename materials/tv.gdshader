shader_type spatial;

uniform sampler2D tv_tex : source_color;

uniform float scanline_strength = 0.3;
uniform float noise_strength = 0.04;
uniform float flicker_strength = 0.03;

void fragment() {
    vec2 uv = UV;

    vec3 col = texture(tv_tex, uv).rgb;

    float scan = sin(uv.y * 900.0) * 0.5 + 0.5;
    col *= mix(1.0, scan, scanline_strength);

    float n = fract(sin(dot(uv * TIME, vec2(12.9898,78.233))) * 43758.5453);
    col += (n - 0.5) * noise_strength;

    col *= 1.0 + sin(TIME * 60.0) * flicker_strength;

    ALBEDO = col;
    EMISSION = col * 0.4;
}
