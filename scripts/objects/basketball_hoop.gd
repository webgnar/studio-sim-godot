extends Node3D
class_name BasketballHoop

signal basket_scored

const SCORE_COOLDOWN: float = 2.0

@onready var _hoop_trigger: Area3D = $HoopTrigger

var _scored_recently: Dictionary = {}  # body instance_id -> cooldown remaining

func _ready() -> void:
	_hoop_trigger.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var to_remove: Array = []
	for id in _scored_recently:
		_scored_recently[id] -= delta
		if _scored_recently[id] <= 0.0:
			to_remove.append(id)
	for id in to_remove:
		_scored_recently.erase(id)

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
	print("[BasketballHoop] BASKET SCORED!")
	basket_scored.emit()
