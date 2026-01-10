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
	print("========== DOOR SETUP DEBUG ==========")
	print("🚪 Door initializing...")
	print("🚪 Required key flag: '%s'" % required_key_flag)
	print("🚪 Is locked: %s" % is_locked)
	print("🚪 Door object: %s" % parent_object.name if parent_object else "NONE")

	# Find the animation player
	animation_player = find_animation_player()

	if not animation_player:
		push_error("DoorInteraction: No AnimationPlayer found!")
	else:
		print("🚪 AnimationPlayer found: %s" % animation_player.name)

	# Find the collision body
	collision_body = parent_object.get_node_or_null(collision_body_name)

	if not collision_body:
		push_warning("DoorInteraction: Collision body '%s' not found" % collision_body_name)
	else:
		print("🚪 Collision body found: %s" % collision_body.name)

	print("======================================")

	# Update interaction text based on lock state
	_update_prompt()

func _on_interacted(_player: PlayerInteractionComponent) -> void:
	print("========== DOOR INTERACTION DEBUG ==========")
	print("🚪 Door '%s' interacted with" % parent_object.name if parent_object else "Unknown")
	print("🚪 Is locked: %s" % is_locked)
	print("🚪 Is open: %s" % is_open)

	if is_locked:
		print("🚪 Door is locked, checking for key flag: '%s'" % required_key_flag)
		# Check if player has the required key flag
		var has_key = WorldStateManager.has_flag(required_key_flag)
		print("🚪 Player has key flag: %s" % has_key)

		if has_key:
			# Unlock the door
			is_locked = false
			print("🚪 ✅ DOOR UNLOCKED! Now opening...")

			# Play unlock sound if you have one
			if interaction_sound:
				_play_sound(interaction_sound)

			# Immediately open the door after unlocking
			_open_door()
		else:
			# Door is still locked
			print("🚪 ❌ Door is locked. Player needs key '%s'" % required_key_flag)
			# Could play a "locked" sound here
		print("=============================================")
		return

	# Door is unlocked - toggle open/close
	print("🚪 Door is unlocked, toggling open/close state")
	if is_open:
		print("🚪 Closing door...")
		_close_door()
	else:
		print("🚪 Opening door...")
		_open_door()
	print("===============================================")

func _open_door() -> void:
	print("🚪 [_open_door] Starting...")
	if not animation_player:
		print("🚪 [_open_door] ❌ No animation player!")
		return

	if animation_player.has_animation("open"):
		print("🚪 [_open_door] ▶️ Playing 'open' animation")
		animation_player.play("open")
	else:
		print("🚪 [_open_door] ⚠️ No 'open' animation found!")

	is_open = true
	_update_prompt()

	# Disable collision so player can walk through
	if collision_body:
		print("🚪 [_open_door] Disabling collision...")
		collision_body.collision_layer = 0
		collision_body.collision_mask = 0

func _close_door() -> void:
	print("🚪 [_close_door] Starting...")
	if not animation_player:
		print("🚪 [_close_door] ❌ No animation player!")
		return

	# Play animation backwards or use a "close" animation if it exists
	if animation_player.has_animation("close"):
		print("🚪 [_close_door] ▶️ Playing 'close' animation")
		animation_player.play("close")
	else:
		# Play "open" animation in reverse
		print("🚪 [_close_door] ◀️ Playing 'open' animation in REVERSE")
		animation_player.play_backwards("open")

	is_open = false
	_update_prompt()

	# Re-enable collision
	if collision_body:
		print("🚪 [_close_door] Re-enabling collision...")
		collision_body.collision_layer = 2
		collision_body.collision_mask = 1

func _update_prompt() -> void:
	if is_locked:
		interaction_text = locked_text
	else:
		interaction_text = unlocked_text if not is_open else "Close Door"
