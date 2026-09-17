extends Area3D
class_name SkateExitZone

## Detects the player riding into the end of the skateboard track and hands
## control back to PlayerController's normal FPS mode. Modeled directly on
## LadderClimbZone.gd. No body_exited handling — dismount happens once.

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1  # Player body layer
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("stop_skating"):
		body.stop_skating()
