extends Node3D
class_name BasketballHoop

signal basket_scored

const SCORE_COOLDOWN: float = 2.0
const DEBUG_FLASH_TIME: float = 0.6

## Shows the (otherwise invisible) HoopTrigger volume in-game as a wireframe
## cylinder so it's obvious when the ball did/didn't pass through it, and
## flashes it green + plays a chime whenever a basket is scored.
@export var debug_visualize: bool = true

@onready var _hoop_trigger: Area3D = $HoopTrigger

var _scored_recently: Dictionary = {}  # body instance_id -> cooldown remaining
var _score_count: int = 0
var _debug_mesh: MeshInstance3D
var _debug_material: StandardMaterial3D
var _flash_time_left: float = 0.0
var _score_sfx: AudioStreamPlayer3D

func _ready() -> void:
	_hoop_trigger.body_entered.connect(_on_body_entered)
	if debug_visualize:
		_setup_debug_visuals()

func _physics_process(delta: float) -> void:
	var to_remove: Array = []
	for id in _scored_recently:
		_scored_recently[id] -= delta
		if _scored_recently[id] <= 0.0:
			to_remove.append(id)
	for id in to_remove:
		_scored_recently.erase(id)

	if _flash_time_left > 0.0:
		_flash_time_left -= delta
		if _debug_material:
			var t: float = clamp(_flash_time_left / DEBUG_FLASH_TIME, 0.0, 1.0)
			_debug_material.albedo_color = Color(0.2, 1.0, 0.2, 0.15 + 0.55 * t)

func _on_body_entered(body: Node3D) -> void:
	print("[BasketballHoop] body_entered: ", body.name, " | layer: ", body.collision_layer)
	if not body is RigidBody3D:
		print("[BasketballHoop] skipped — not RigidBody3D")
		return
	if not (body.collision_layer & 8):
		print("[BasketballHoop] skipped — not on layer 8")
		return
	var body_id = body.get_instance_id()
	if _scored_recently.has(body_id):
		print("[BasketballHoop] skipped — scored recently")
		return
	_scored_recently[body_id] = SCORE_COOLDOWN
	_score_count += 1
	print("[BasketballHoop] BASKET SCORED! (total: ", _score_count, ")")
	if debug_visualize:
		_flash_time_left = DEBUG_FLASH_TIME
		if _score_sfx:
			_score_sfx.pitch_scale = 1.6
			_score_sfx.play()
	basket_scored.emit()

func _setup_debug_visuals() -> void:
	var trigger_shape: CollisionShape3D = _hoop_trigger.get_node("CollisionShape3D")
	if trigger_shape and trigger_shape.shape is CylinderShape3D:
		var cyl: CylinderShape3D = trigger_shape.shape
		var mesh := CylinderMesh.new()
		mesh.top_radius = cyl.radius
		mesh.bottom_radius = cyl.radius
		mesh.height = cyl.height
		_debug_material = StandardMaterial3D.new()
		_debug_material.albedo_color = Color(1.0, 0.85, 0.1, 0.35)
		_debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_debug_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material = _debug_material
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.mesh = mesh
		_debug_mesh.name = "DebugTriggerVisual"
		_hoop_trigger.add_child(_debug_mesh)

	_score_sfx = AudioStreamPlayer3D.new()
	_score_sfx.name = "DebugScoreSFX"
	_score_sfx.stream = load("res://sounds/basketball.ogg")
	_score_sfx.max_distance = 30.0
	_hoop_trigger.add_child(_score_sfx)
