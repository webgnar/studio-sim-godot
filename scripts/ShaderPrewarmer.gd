class_name ShaderPrewarmer
extends RefCounted

## Forces a shader to compile now, off-screen, so its first real use later
## doesn't pay the compile-time cost during active gameplay. A shader's
## render pipeline is normally built lazily on its first actual draw call —
## for an involved shader (heavy noise loops, domain warping, etc.) that
## first compile is a well-known source of a one-time stutter. Rendering it
## once inside a SubViewport that's never displayed anywhere triggers a real
## draw call (so the compile actually happens) with zero visual side effects,
## then the whole thing is discarded.
##
## `host` must already be inside the SceneTree — the SubViewport is added as
## its child temporarily. Usage: `ShaderPrewarmer.prewarm(MY_SHADER, self)`
## from any Node's _ready().
static func prewarm(shader: Shader, host: Node) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(4, 4)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(viewport)

	var cam := Camera3D.new()
	viewport.add_child(cam)

	var warm_mesh := MeshInstance3D.new()
	warm_mesh.mesh = BoxMesh.new()
	var warm_mat := ShaderMaterial.new()
	warm_mat.shader = shader
	warm_mesh.material_override = warm_mat
	warm_mesh.position = Vector3(0, 0, -2)  # in front of the throwaway camera
	viewport.add_child(warm_mesh)

	await RenderingServer.frame_post_draw
	if is_instance_valid(viewport):
		viewport.queue_free()
