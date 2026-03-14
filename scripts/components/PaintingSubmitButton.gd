extends InteractionComponent
class_name PaintingSubmitButton

## Button component for submitting paintings to mission validation
## Extends InteractionComponent for proper HUD integration

@export var button_cooldown: float = 1.0

var last_pressed: float = 0.0
var pending_painting_system: PaintingSystem2D = null
var _error_sound: AudioStreamPlayer3D
var _error_stream: AudioStream = preload("res://sounds/picotron/error.ogg")
var _glow_overlay: MeshInstance3D

func _on_ready() -> void:
	_error_sound = AudioStreamPlayer3D.new()
	_error_sound.name = "ErrorSound"
	_error_sound.max_distance = 15.0
	_error_sound.bus = "SFX"
	_error_sound.stream = _error_stream
	add_child(_error_sound)

	_glow_overlay = get_node_or_null("../green button/GlowOverlay") as MeshInstance3D
	if not _glow_overlay:
		push_warning("PaintingSubmitButton: GlowOverlay not found.")

	_update_interaction_text()
	MissionManager.mission_started.connect(func(_m): _update_interaction_text())
	MissionManager.mission_completed.connect(func(_m, _r): _update_interaction_text())
	MissionManager.mission_failed.connect(func(_m, _r): _update_interaction_text())
	MissionManager.mission_aborted.connect(func(_m): _update_interaction_text())

func _update_interaction_text() -> void:
	if MissionManager and MissionManager.current_mission:
		interaction_text = "Submit Painting"
		is_disabled = false
		if _glow_overlay:
			_glow_overlay.visible = true
	else:
		interaction_text = "No Mission"
		is_disabled = true
		if _glow_overlay:
			_glow_overlay.visible = false

func interact(player_interaction_component: PlayerInteractionComponent) -> void:
	if is_disabled:
		_error_sound.play()
		return
	super.interact(player_interaction_component)

## Called by PlayerInteractionComponent when player interacts
func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	# Cooldown check
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_pressed < button_cooldown:
		return

	last_pressed = current_time

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
