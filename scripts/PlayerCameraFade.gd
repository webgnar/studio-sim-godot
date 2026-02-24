extends Node
class_name PlayerCameraFade
## Applies a dithered camera-proximity fade to all player mesh surfaces.
## Prevents the player body from visibly clipping through the first-person camera.

@export var fade_inner_radius: float = 0.3
@export var fade_outer_radius: float = 0.6

const SHADER_PATH = "res://shaders/player_fade.gdshader"
var _shader: Shader
var _meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	_shader = load(SHADER_PATH)
	if not _shader:
		push_error("[PlayerCameraFade] Could not load shader: " + SHADER_PATH)
		return
	_find_meshes()
	call_deferred("_apply_all")  # defer so GLB surfaces are guaranteed ready

func _find_meshes() -> void:
	var human = get_parent().get_node_or_null("human")
	if not human:
		push_error("[PlayerCameraFade] 'human' node not found on parent")
		return
	_meshes = _collect(human)

func _collect(node: Node) -> Array[MeshInstance3D]:
	var r: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		r.append(node)
	for c in node.get_children():
		r.append_array(_collect(c))
	return r

func _apply_all() -> void:
	for mesh in _meshes:
		if not mesh.mesh:
			continue
		for i in range(mesh.mesh.get_surface_count()):
			var existing = mesh.get_surface_override_material(i)
			if not existing:
				existing = mesh.mesh.surface_get_material(i)
			mesh.set_surface_override_material(i, _make_fade_mat(existing))

func _make_fade_mat(source: Material) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("fade_inner_radius", fade_inner_radius)
	mat.set_shader_parameter("fade_outer_radius", fade_outer_radius)
	_copy_textures(mat, source)
	return mat

func _copy_textures(target: ShaderMaterial, source: Material) -> void:
	if source is StandardMaterial3D:
		var s := source as StandardMaterial3D
		target.set_shader_parameter("albedo_texture", s.albedo_texture)
		target.set_shader_parameter("normal_texture", s.normal_texture)
		target.set_shader_parameter("ao_texture",     s.ao_texture)
		target.set_shader_parameter("normal_enabled", s.normal_enabled)
		target.set_shader_parameter("ao_enabled",     s.ao_enabled)
	# If source is null or another type, shader uses its default textures
