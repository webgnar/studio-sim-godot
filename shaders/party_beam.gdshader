shader_type spatial;
// Soft visible light cone for the dance party (disco spots + projector throws). Use on a
// CylinderMesh whose narrow end sits at the lamp. Additive + unshaded; brightest along the
// axis and near the lamp, fading out toward the far end and the cone's silhouette edges.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 beam_color : source_color = vec4(1.0);
uniform float intensity = 0.25;
uniform bool narrow_end_at_top = false; // CylinderMesh UV.y runs top(0) -> bottom(1)

void fragment() {
	float along = narrow_end_at_top ? UV.y : 1.0 - UV.y; // 0 at lamp, 1 at far end
	float length_fade = pow(1.0 - clamp(along, 0.0, 1.0), 1.6);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge_fade = facing * facing;
	ALBEDO = beam_color.rgb * intensity * length_fade * edge_fade;
}
