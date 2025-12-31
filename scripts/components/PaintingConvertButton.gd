extends InteractionComponent
class_name PaintingConvertButton

## Button component for converting paintings to carryable objects
## Extends InteractionComponent for proper HUD integration

@export var button_cooldown: float = 1.0

var last_pressed: float = 0.0

func _on_ready() -> void:
	# Always set interaction text to support both abort and convert
	interaction_text = "Abort / New Painting"

## Called by PlayerInteractionComponent when player interacts
func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	# Cooldown check
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_pressed < button_cooldown:
		return

	last_pressed = current_time

	# Check if mission is active
	if MissionManager and MissionManager.current_mission:
		# Abort the active mission
		MissionManager.abort_mission()
		print("Red button: Mission aborted")

	# Convert painting to carryable (regardless of mission state)
	PaintingSpawner.replace_painting_with_carryable(get_tree().current_scene)

	# Play animation if available
	var anim_player = _find_animation_player()
	if anim_player and anim_player.has_animation("press"):
		anim_player.play("press")

		# Queue release animation after press finishes
		if anim_player.has_animation("release"):
			anim_player.animation_finished.connect(_on_press_finished.bind(anim_player), CONNECT_ONE_SHOT)

func _on_press_finished(_anim_name: String, anim_player: AnimationPlayer) -> void:
	"""Called when press animation finishes, plays release animation"""
	anim_player.play("release")

func _find_animation_player() -> AnimationPlayer:
	"""Recursively search for AnimationPlayer in parent hierarchy"""
	return _find_animation_player_recursive(get_parent())

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var result = _find_animation_player_recursive(child)
		if result:
			return result

	return null
