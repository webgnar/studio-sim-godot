extends Area3D
class_name LadderClimbZone

## Detects the player touching a deployed ladder and hands vertical movement
## control over to PlayerController for as long as they stay inside the zone.
## Disabled (monitoring = false) until LadderComponent drops the ladder.

@export var climb_speed: float = 3.0

func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 1  # Player body layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("start_climbing"):
		body.start_climbing(self, climb_speed)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("stop_climbing"):
		body.stop_climbing()
