extends Node3D

## Studio Assistant NPC character controller.
## Uses Tweens (not AnimationPlayer) for position/scale transitions to avoid
## snap-jumping from absolute keyframe values.
##
## States:
##   Before hired — sit → meditate (rig AP)
##   On hire — Phase 1: shrink tween + sit-backwards simultaneously
##              Phase 2: walk tween (position) + rig walk simultaneously
##              Phase 3: rig idle (looping)

@export var shrink_scale: float = 0.25  ## Scale when working
@export var walk_position_delta: Vector3 = Vector3(-0.7672639, 0, -2.819965)  ## Position offset from rest to desk
@export var walk_rotation_delta: Vector3 = Vector3(0, 0.25043726, 0)           ## Rotation offset over walk

const WALK_DURATION := 3.0
const WALK_TURN_DURATION := 1.5
const SHRINK_DURATION := 3.0

var rig_anim_player: AnimationPlayer
var _is_hired: bool = false


func _ready() -> void:
	if has_node("humanrig"):
		rig_anim_player = _find_animation_player($humanrig)
	else:
		push_warning("StudioAssistantCharacter: humanrig node not found!")

	if not rig_anim_player:
		push_warning("StudioAssistantCharacter: Rig AnimationPlayer not found inside humanrig!")

	if has_node("/root/AutomationManager") and AutomationManager.is_assistant_active():
		_start_work_immediately()
	else:
		_start_meditation_sequence()

	if has_node("/root/AutomationManager"):
		AutomationManager.assistant_purchased.connect(_on_assistant_purchased)


func _start_meditation_sequence() -> void:
	"""Play sit then loop meditate — default state before hiring"""
	if not rig_anim_player:
		return
	_play_rig_animation("sit")
	await rig_anim_player.animation_finished
	_play_rig_animation("meditate")


func _start_work_immediately() -> void:
	"""Skip hire sequence, jump to final working state (game loaded with assistant active)"""
	_is_hired = true
	scale = Vector3(shrink_scale, shrink_scale, shrink_scale)
	position += walk_position_delta
	rotation += walk_rotation_delta
	_play_rig_animation("idle")


func _on_assistant_purchased() -> void:
	"""Three-phase on-hire animation: stand up → walk → idle"""
	if _is_hired:
		return
	_is_hired = true

	# --- Phase 1: Shrink (tween) + stand up from sit (rig AP) simultaneously ---
	# Tween from current scale — no snap, no absolute keyframe issues
	var shrink_tween = create_tween()
	shrink_tween.tween_property(self, "scale",
		Vector3(shrink_scale, shrink_scale, shrink_scale), SHRINK_DURATION)

	if rig_anim_player and rig_anim_player.has_animation("sit"):
		rig_anim_player.play_backwards("sit")
		await rig_anim_player.animation_finished
	else:
		await shrink_tween.finished  # fallback if no sit animation

	# Brief idle pause to let shrink finish before walking
	_play_rig_animation("idle")
	await get_tree().create_timer(2.0).timeout

	# --- Phase 2: Walk forward (tween from current position) + bone walk simultaneously ---
	# Both tracks run in parallel: position over 3s, rotation (turn) over 1.06s
	var walk_tween = create_tween().set_parallel(true)
	walk_tween.tween_property(self, "position", position + walk_position_delta, WALK_DURATION)
	walk_tween.tween_property(self, "rotation", rotation + walk_rotation_delta, WALK_TURN_DURATION)

	_play_rig_animation("walk")
	await walk_tween.finished

	# --- Phase 3: Idle at destination ---
	_play_rig_animation("idle")


func _play_rig_animation(anim_name: String) -> void:
	if not rig_anim_player:
		return
	if not rig_anim_player.has_animation(anim_name):
		push_warning("StudioAssistantCharacter: Rig animation '%s' not found. Available: %s" % [
			anim_name, str(rig_anim_player.get_animation_list())])
		return
	if anim_name in ["idle", "walk", "meditate"]:
		rig_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	rig_anim_player.play(anim_name)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null
