extends Node
class_name CanvasPulseHint

## Reusable component that fades the canvas_pulse shader opacity in/out.
## Auto-discovers a sibling MeshInstance3D named "pulse shader planemesh" if mesh is not set.

@export var mesh: MeshInstance3D
@export var fade_duration: float = 1.0

var _visible_state: bool = false
var _tween: Tween

func _ready() -> void:
	if not mesh:
		mesh = get_parent().get_node_or_null("pulse shader planemesh") as MeshInstance3D
	if not mesh:
		push_warning("CanvasPulseHint: could not find target MeshInstance3D")

func show_hint() -> void:
	_fade(true)

func hide_hint() -> void:
	_fade(false)

func _get_mat() -> ShaderMaterial:
	var override := mesh.get_surface_override_material(0) as ShaderMaterial
	if override:
		return override
	return mesh.mesh.surface_get_material(0) as ShaderMaterial

func _fade(show: bool) -> void:
	if _visible_state == show:
		return
	_visible_state = show
	var mat := _get_mat()
	if not mat:
		push_warning("CanvasPulseHint: no ShaderMaterial found on mesh")
		return
	var from: float = mat.get_shader_parameter("opacity")
	var to: float = 1.0 if show else 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("opacity", v), from, to, fade_duration)
