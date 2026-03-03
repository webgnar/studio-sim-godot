extends Node3D

const SAVE_KEY = "baricade_2_triggered"

@onready var _area: Area3D = $Area3D
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if WorldStateManager.get_data(SAVE_KEY, false):
		# Already triggered in a previous session — snap to end state instantly
		var anim_res = _anim.get_animation("move")
		_anim.play("move")
		_anim.seek(anim_res.length, true)
	else:
		_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_area.body_entered.disconnect(_on_body_entered)
	_anim.play("move")
	WorldStateManager.set_data(SAVE_KEY, true)
