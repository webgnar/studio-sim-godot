extends Node3D

## Studio Assistant NPC character controller
## Starts in meditation pose. When hired via AutomationManager, stands up and loops work animation.

var animation_player: AnimationPlayer
var _is_hired: bool = false

func _ready():
	animation_player = _find_animation_player(self)

	if not animation_player:
		push_warning("StudioAssistantCharacter: No AnimationPlayer found!")
		return

	# Check if already hired (game loaded with assistant active)
	if has_node("/root/AutomationManager") and AutomationManager.is_assistant_active():
		_start_work_immediately()
	else:
		_start_meditation_sequence()

	# Connect to hire signal
	if has_node("/root/AutomationManager"):
		AutomationManager.assistant_purchased.connect(_on_assistant_purchased)


func _start_meditation_sequence() -> void:
	"""Play sit then loop meditate — default idle state before hiring"""
	_play_animation("sit")
	await animation_player.animation_finished
	_play_animation("meditate")


func _start_work_immediately() -> void:
	"""Skip sit-down sequence and go straight to work (used on load when already hired)"""
	_is_hired = true
	_play_animation("walk")


func _on_assistant_purchased() -> void:
	"""Stand up and begin working"""
	if _is_hired:
		return
	_is_hired = true

	# Stand up: play sit backwards
	if animation_player.has_animation("sit"):
		animation_player.play_backwards("sit")
		await animation_player.animation_finished

	# Brief idle moment
	_play_animation("idle")
	await get_tree().create_timer(1.5).timeout

	# Begin looping work animation
	_play_animation("walk")


func _play_animation(anim_name: String) -> void:
	if not animation_player:
		return
	if not animation_player.has_animation(anim_name):
		push_warning("StudioAssistantCharacter: Animation '%s' not found. Available: %s" % [anim_name, str(animation_player.get_animation_list())])
		return
	if anim_name in ["idle", "walk", "meditate"]:
		animation_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	animation_player.play(anim_name)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null
