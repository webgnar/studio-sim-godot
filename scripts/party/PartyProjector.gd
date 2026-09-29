extends Node3D
class_name PartyProjector
## A light projector for the DJ dance party. The housing (this node) hangs wherever you like;
## its `Screen` child is a quad placed on a wall/floor where the image lands, and a soft beam is
## stretched from the lens to the screen automatically, so you can move either one freely.
##
## CONTENT: drop textures into `images` and it cycles through them (crossfading) every
## `seconds_per_image`. With no images it cycles the built-in procedural geometric patterns
## from shaders/party_projection.gdshader instead.

@export var images: Array[Texture2D] = []
@export var seconds_per_image: float = 8.0
@export var procedural_patterns: PackedInt32Array = [0, 1, 2, 3] ## used when `images` is empty
@export var tint: Color = Color.WHITE
@export var intensity: float = 1.4
@export var circular_mask: bool = true ## round "lens" edge; turn off for full-frame images
@export var show_beam: bool = true
@export var beam_intensity: float = 0.08
@export var screen_path: NodePath = ^"Screen"
@export var lens_offset: Vector3 = Vector3(0, 0, -0.25) ## lens position in this node's local space

const _BEAM_SHADER := preload("res://shaders/party_beam.gdshader")
const _FADE_TIME := 0.6

var _screen: MeshInstance3D
var _mat: ShaderMaterial
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _index: int = 0
var _timer: float = 0.0
var _fade: float = 1.0
var _fading_out: bool = false


func _ready() -> void:
	_screen = get_node_or_null(screen_path) as MeshInstance3D
	if _screen == null:
		push_warning("PartyProjector '%s': no Screen quad at %s" % [name, screen_path])
		return
	# Own copy of the material so projectors don't share pattern/fade state.
	var src := _screen.get_active_material(0) as ShaderMaterial
	_mat = src.duplicate() if src else ShaderMaterial.new()
	_screen.material_override = _mat
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("circular_mask", circular_mask)
	_mat.set_shader_parameter("time_offset", randf() * 100.0)
	_index = randi() % max(_count(), 1)
	_show(_index)
	if show_beam:
		_build_beam()


func _process(delta: float) -> void:
	if _mat == null:
		return
	if _fading_out:
		_fade = maxf(_fade - delta / _FADE_TIME, 0.0)
		if _fade <= 0.0:
			_fading_out = false
			_index = (_index + 1) % max(_count(), 1)
			_show(_index)
	else:
		_fade = minf(_fade + delta / _FADE_TIME, 1.0)
		_timer += delta
		if _count() > 1 and _timer >= seconds_per_image:
			_timer = 0.0
			_fading_out = true
	_mat.set_shader_parameter("fade", _fade)
	if _beam_mat:
		_beam_mat.set_shader_parameter("intensity", beam_intensity * _fade)


func _count() -> int:
	return images.size() if not images.is_empty() else procedural_patterns.size()


func _show(i: int) -> void:
	if not images.is_empty():
		_mat.set_shader_parameter("use_texture", true)
		_mat.set_shader_parameter("projection_texture", images[i % images.size()])
	elif not procedural_patterns.is_empty():
		_mat.set_shader_parameter("use_texture", false)
		_mat.set_shader_parameter("pattern", procedural_patterns[i % procedural_patterns.size()])


func _build_beam() -> void:
	var lens := global_transform * lens_offset
	var target := _screen.global_position
	var dir := target - lens
	var length := dir.length()
	if length < 0.1:
		return
	# Beam reaches the screen at roughly the screen's own size.
	var quad := _screen.mesh as QuadMesh
	var far_radius := 1.5
	if quad:
		far_radius = 0.45 * minf(quad.size.x * _screen.global_transform.basis.x.length(),
				quad.size.y * _screen.global_transform.basis.y.length())

	var cone := CylinderMesh.new()
	cone.top_radius = 0.08
	cone.bottom_radius = far_radius
	cone.height = length
	cone.radial_segments = 24
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = _BEAM_SHADER
	_beam_mat.set_shader_parameter("narrow_end_at_top", true)
	_beam_mat.set_shader_parameter("beam_color", tint)
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	_beam.mesh = cone
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	# Cylinder +Y (narrow top) must point from the screen back to the lens.
	var y := (lens - target).normalized()
	var x := y.cross(Vector3.UP if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_beam.global_transform = Transform3D(Basis(x, y, z), (lens + target) * 0.5)
