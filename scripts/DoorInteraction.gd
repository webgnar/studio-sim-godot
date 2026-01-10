extends InteractionComponent
class_name DoorInteraction

## Interactable door that can be locked/unlocked with a key

@export var is_locked: bool = true  # Is the door currently locked?
@export var required_key_flag: String = "studio_key"  # Flag name required to unlock
@export var locked_text: String = "Locked - Need Key"
@export var unlocked_text: String = "Open Door"
@export var collision_body_name: String = "model/RigidBody3D"  # Name of the collision body to disable when open

var is_open: bool = false
var animation_player: AnimationPlayer
var collision_body: StaticBody3D = null

func _on_ready() -> void:
	# Find the animation player
	animation_player = find_animation_player()

	if not animation_player:
		push_error("DoorInteraction: No AnimationPlayer found!")

	# Find the collision body
	collision_body = parent_object.get_node_or_null(collision_body_name)

	if not collision_body:
		push_warning("DoorInteraction: Collision body '%s' not found" % collision_body_name)

	# Update interaction text based on lock state
	_update_prompt()

func _on_interacted(_player: PlayerInteractionComponent) -> void:
	if is_locked:
		# Check if player has the required key flag
		if WorldStateManager.has_flag(required_key_flag):
			# Unlock the door
			is_locked = false
			_update_prompt()
			print("Door unlocked!")

			# Play unlock sound if you have one
			if interaction_sound:
				_play_sound(interaction_sound)
		else:
			# Door is still locked
			print("This door is locked. You need a key.")
			# Could play a "locked" sound here
		return

	# Door is unlocked - toggle open/close
	if is_open:
		_close_door()
	else:
		_open_door()

func _open_door() -> void:
	if not animation_player:
		return

	if animation_player.has_animation("open"):
		animation_player.play("open")

	is_open = true
	_update_prompt()

	# Disable collision so player can walk through
	if collision_body:
		collision_body.collision_layer = 0
		collision_body.collision_mask = 0

func _close_door() -> void:
	if not animation_player:
		return

	# Play animation backwards or use a "close" animation if it exists
	if animation_player.has_animation("close"):
		animation_player.play("close")
	else:
		# Play "open" animation in reverse
		animation_player.play_backwards("open")

	is_open = false
	_update_prompt()

	# Re-enable collision
	if collision_body:
		collision_body.collision_layer = 2
		collision_body.collision_mask = 1

func _update_prompt() -> void:
	if is_locked:
		interaction_text = locked_text
	else:
		interaction_text = unlocked_text if not is_open else "Close Door"
