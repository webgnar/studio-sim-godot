shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float speed : hint_range(0.0, 10.0) = 3.0;
uniform float line_density : hint_range(4.0, 128.0) = 48.0;
uniform float line_width : hint_range(0.001, 0.9) = 0.35;
uniform float edge_softness : hint_range(0.001, 0.2) = 0.04;
uniform float glow : hint_range(0.0, 5.0) = 1.5;
uniform vec4 line_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;

    float angle = atan(uv.y, uv.x);
    float radius = length(uv);

    float movement = fract(radius * line_density + TIME * speed);

    float lines = smoothstep(line_width, line_width - edge_softness, movement);

    float fade = smoothstep(1.0, 0.2, radius);

    float intensity = lines * fade * glow;

    ALBEDO = line_color.rgb * intensity;
    EMISSION = line_color.rgb * intensity;
    ALPHA = intensity * opacity;
}
