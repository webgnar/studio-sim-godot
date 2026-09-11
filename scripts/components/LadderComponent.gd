extends InteractionComponent
class_name LadderComponent

## Attaches to a stowed ladder. Until the player deploys it (E-key, from the roof
## where the stowed ladder is actually reachable), it just sits there as an
## interactable. On deploy it tweens the ladder's own Y position down to
## `deployed_y`, hands climbing off to a sibling LadderClimbZone, and persists
## the deployed state via WorldStateManager so it stays down across saves.

@export var deployed_y: float = 2.8
@export var drop_duration: float = 0.6
@export var deployed_flag: String = "ladder_deployed"  ## WorldStateManager flag key

var is_deployed: bool = false

@onready var _climb_zone: Area3D = get_parent().get_node_or_null("ClimbZone")

func _on_ready() -> void:
	if interaction_text.is_empty() or interaction_text == "Interact":
		interaction_text = "Drop Ladder"

	if WorldStateManager.has_flag(deployed_flag):
		_apply_deployed_state(false)
	else:
		# Flag data may not be loaded from the save file yet when this node's own
		# _ready() runs (same reasoning as HiddenDoorFog.gd's re-sync) — re-check
		# once world state actually loads.
		WorldStateManager.world_state_loaded.connect(_recheck_deployed_flag, CONNECT_ONE_SHOT)

func _recheck_deployed_flag() -> void:
	if not is_deployed and WorldStateManager.has_flag(deployed_flag):
		_apply_deployed_state(false)

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	if is_deployed:
		return
	# Guard immediately (synchronous) so a repeat E-press mid-tween is a no-op —
	# interact() re-checks is_disabled before _on_interacted runs again.
	is_deployed = true
	is_disabled = true

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(parent_object, "position:y", deployed_y, drop_duration)
	await tween.finished

	_finish_deploy()
	WorldStateManager.set_flag(deployed_flag, true)

## Restores a previously-deployed ladder on load. `animate` is currently always
## false (a past session's drop shouldn't replay) but kept as a parameter in
## case a future caller wants the tween instead of an instant snap.
func _apply_deployed_state(animate: bool) -> void:
	is_deployed = true
	is_disabled = true
	if animate:
		var tween := create_tween()
		tween.tween_property(parent_object, "position:y", deployed_y, drop_duration)
		await tween.finished
	else:
		parent_object.position.y = deployed_y
	_finish_deploy()

func _finish_deploy() -> void:
	# Ladder is down — stop offering the E-key prompt and let the player climb it instead.
	if parent_object.is_in_group("interactable"):
		parent_object.remove_from_group("interactable")
	if _climb_zone:
		_climb_zone.monitoring = true
