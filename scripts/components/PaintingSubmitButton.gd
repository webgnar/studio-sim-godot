extends InteractionComponent
class_name PaintingSubmitButton

## Button component for submitting paintings to mission validation
## Extends InteractionComponent for proper HUD integration

@export var button_cooldown: float = 1.0

var last_pressed: float = 0.0
var pending_painting_system: PaintingSystem2D = null

func _on_ready() -> void:
	# Always set interaction text
	interaction_text = "Submit Painting"

## Called by PlayerInteractionComponent when player interacts
func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	# Cooldown check
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_pressed < button_cooldown:
		return

	last_pressed = current_time

	# Check if mission is active
	if not MissionManager or not MissionManager.current_mission:
		push_warning("PaintingSubmitButton: No active mission! Cannot submit painting.")
		return

	# Get painting system
	var painting_system = PaintingModeManager.painting_system_2d
	if not painting_system:
		push_error("PaintingSubmitButton: Could not find PaintingSystem2D!")
		return

	# Store painting system for later submission
	pending_painting_system = painting_system

	# Play press animation first, then submit after it completes
	var anim_player = _find_animation_player()
	if anim_player and anim_player.has_animation("press"):
		anim_player.play("press")
		# Connect to submit painting after press animation finishes
		anim_player.animation_finished.connect(_on_press_finished.bind(anim_player), CONNECT_ONE_SHOT)
	else:
		# No animation, submit immediately
		_submit_and_release(null)

func _on_press_finished(_anim_name: String, anim_player: AnimationPlayer) -> void:
	"""Called when press animation finishes, submits painting then plays release animation"""
	_submit_and_release(anim_player)

func _submit_and_release(anim_player: AnimationPlayer) -> void:
	"""Submit the painting and play release animation"""
	# Submit the painting for validation
	if pending_painting_system:
		pending_painting_system.submit_painting()
		pending_painting_system = null
		print("Green button: Painting submitted for validation")

	# Play release animation if available
	if anim_player and anim_player.has_animation("release"):
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
