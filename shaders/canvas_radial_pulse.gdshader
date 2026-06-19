shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float speed : hint_range(0.1, 5.0) = 0.4;
uniform float glow : hint_range(0.0, 3.0) = 0.8;
uniform vec4 line_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float radius = length(uv);

    float wave = fract(TIME * speed);
    float ring = 1.0 - abs(radius - wave) * 4.0;
    ring = clamp(ring, 0.0, 1.0);

    float fade = smoothstep(1.0, 0.0, wave);
    float edge_fade = smoothstep(1.0, 0.3, radius);

    float intensity = ring * fade * edge_fade * glow;

    ALBEDO = line_color.rgb * intensity;
    EMISSION = line_color.rgb * intensity;
    ALPHA = intensity * opacity;
}
