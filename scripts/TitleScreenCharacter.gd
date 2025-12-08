extends Node3D

## Controller for character model in title screen
## Automatically plays animation sequence: idle → sit → meditate
## Supports exit animation when game starts

signal exit_animation_completed

enum State {
	IDLE,
	SITTING,
	MEDITATING,
	EXITING
}

@export var idle_duration: float = 3.0  ## How long to stay in idle before sitting
@export var animation_name: String = "idle"  ## Legacy: initial animation (used for debugging)

var animation_player: AnimationPlayer
var current_state: State = State.IDLE
var is_exiting: bool = false

func _ready():
	# Find AnimationPlayer in children
	animation_player = _find_animation_player(self)

	if not animation_player:
		push_warning("TitleScreenCharacter: No AnimationPlayer found in node tree!")
		_debug_print_tree(self, 0)
		return

	# Start the animation sequence
	_start_animation_sequence()


func _start_animation_sequence() -> void:
	"""Play the automatic animation sequence: idle → sit → meditate"""
	if is_exiting:
		return  # Don't start sequence if we're already exiting

	# Play idle animation
	_play_animation("idle")
	current_state = State.IDLE

	# Wait for idle duration
	await get_tree().create_timer(idle_duration).timeout

	if is_exiting:
		return  # Check again after wait

	# Play sit animation
	_play_animation("sit")
	current_state = State.SITTING

	# Wait for sit animation to finish
	await animation_player.animation_finished

	if is_exiting:
		return  # Check again after animation

	# Play meditate animation (loops indefinitely)
	_play_animation("meditate")
	current_state = State.MEDITATING


func play_exit_animation() -> void:
	"""Play exit animation sequence based on current state"""
	if is_exiting:
		push_warning("TitleScreenCharacter: Already exiting, ignoring play_exit_animation call")
		return

	if not animation_player:
		push_warning("TitleScreenCharacter: No AnimationPlayer, skipping exit animation")
		exit_animation_completed.emit()
		return

	is_exiting = true
	var previous_state = current_state
	current_state = State.EXITING

	match previous_state:
		State.MEDITATING:
			# Stand up from meditate: reverse sit animation then idle
			await _reverse_sit_and_idle()
		State.SITTING:
			# Stand up from sitting: reverse sit then idle
			await _reverse_sit_and_idle()
		State.IDLE, State.EXITING:
			# Already standing or exiting, just stay in idle
			_play_animation("idle")

	exit_animation_completed.emit()


func _reverse_sit_and_idle() -> void:
	"""Helper to play sit animation backwards, then idle"""
	if not animation_player:
		return

	# Play sit animation backwards to stand up
	if animation_player.has_animation("sit"):
		animation_player.play_backwards("sit")
		await animation_player.animation_finished

	# Play idle animation
	_play_animation("idle")


func _play_animation(anim_name: String) -> void:
	"""Helper to play animation with error checking"""
	if not animation_player:
		return

	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	else:
		var available_anims = animation_player.get_animation_list()
		push_warning("TitleScreenCharacter: Animation '%s' not found!" % anim_name)
		push_warning("TitleScreenCharacter: Available animations are: %s" % str(available_anims))

func _find_animation_player(node: Node) -> AnimationPlayer:
	"""Recursively search for AnimationPlayer in node tree"""
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result

	return null

func _debug_print_tree(node: Node, depth: int):
	"""Print the node tree structure for debugging"""
	var indent = ""
	for i in range(depth):
		indent += "  "
	print(indent + node.name + " (" + node.get_class() + ")")

	for child in node.get_children():
		_debug_print_tree(child, depth + 1)
