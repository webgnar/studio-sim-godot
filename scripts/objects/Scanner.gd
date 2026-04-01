extends Node3D
class_name Scanner

signal scan_complete

const SCAN_DURATION: float = 2.0
const SWEEP_AMPLITUDE: float = 0.3  # radians
const SWEEP_SPEED: float = 4.0      # radians/sec

@onready var _beam_pivot: Node3D = $BeamPivot
@onready var _beam_mesh: MeshInstance3D = $BeamPivot/BeamMesh
@onready var _overlay_mesh: MeshInstance3D = $ScanOverlay
@onready var _overlay_mat: ShaderMaterial = _overlay_mesh.material_override

var _active: bool = false
var _elapsed: float = 0.0

func _ready() -> void:
	_beam_mesh.visible = false
	_overlay_mesh.visible = false

func activate() -> void:
	var canvas := _find_canvas()
	if not canvas:
		push_error("Scanner: no node in group 2d_painting_canvas")
		scan_complete.emit()
		return

	_position_overlay(canvas)
	_set_bounds(canvas)

	_overlay_mat.set_shader_parameter("active", true)
	_overlay_mat.set_shader_parameter("progress", 0.0)
	_beam_mesh.visible = true
	_overlay_mesh.visible = true
	_active = true
	_elapsed = 0.0

	var tween := create_tween()
	tween.tween_method(
		func(v: float): _overlay_mat.set_shader_parameter("progress", v),
		0.0, 1.0, SCAN_DURATION
	)
	tween.tween_callback(_finish)

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_beam_pivot.rotation.y = sin(_elapsed * SWEEP_SPEED) * SWEEP_AMPLITUDE

func _finish() -> void:
	_active = false
	_overlay_mat.set_shader_parameter("active", false)
	_beam_mesh.visible = false
	_overlay_mesh.visible = false
	scan_complete.emit()

func _find_canvas() -> Node3D:
	var nodes := get_tree().get_nodes_in_group("2d_painting_canvas")
	return nodes[0] as Node3D if not nodes.is_empty() else null

func _position_overlay(canvas: Node3D) -> void:
	# Place overlay flush with canvas surface, tiny offset toward viewer (-Z)
	_overlay_mesh.global_transform = canvas.global_transform
	_overlay_mesh.global_position += Vector3(0, 0, -0.02)

func _set_bounds(canvas: Node3D) -> void:
	var cx: float = canvas.global_transform.origin.x
	var half: float = 1.515  # half of 3.03 (PlaneMesh size 3 * scale 1.01)
	_overlay_mat.set_shader_parameter("world_x_min", cx - half)
	_overlay_mat.set_shader_parameter("world_x_max", cx + half)
