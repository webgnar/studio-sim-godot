extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_collision_mask_value(8, true)  # Detect basketball layer

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("respawnable"):
		body.respawn()
