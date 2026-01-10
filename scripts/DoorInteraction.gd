extends InteractionComponent
class_name DoorInteraction

## Physics-based door with grab-and-drag interaction

@export var is_locked: bool = true  # Is the door currently locked?
@export var required_key_flag: String = "studio_key"  # Flag name required to unlock
@export var locked_text: String = "Locked - Need Key"
@export var grab_text: String = "Grab Door"
@export var collision_body_name: String = "DoorBody"  # Name of the RigidBody3D door

@export_group("Physics")
@export var drag_force: float = 800.0  # Force applied when dragging
@export var mouse_sensitivity: float = 2.0  # How responsive to mouse movement

var door_body: RigidBody3D = null
var hinge_joint: HingeJoint3D = null
var is_grabbed: bool = false
var player_ref: Node = null

func _on_ready() -> void:
	print("========== DOOR SETUP DEBUG ==========")
	print("🚪 Door initializing...")
	print("🚪 Required key flag: '%s'" % required_key_flag)
	print("🚪 Is locked: %s" % is_locked)
	print("🚪 Door object: %s" % parent_object.name if parent_object else "NONE")

	# Find the door rigid body
	door_body = parent_object.get_node_or_null(collision_body_name)

	if not door_body:
		push_error("DoorInteraction: Door body '%s' not found!" % collision_body_name)
	else:
		print("🚪 Door RigidBody3D found: %s" % door_body.name)

	# Find the hinge joint
	hinge_joint = parent_object.get_node_or_null("HingeJoint3D")
	if hinge_joint:
		print("🚪 HingeJoint3D found")

		# Lock the door initially by enabling the motor and setting target to 0
		if is_locked:
			hinge_joint.set("motor/enable", true)
			hinge_joint.set("motor/target_velocity", 0.0)
			hinge_joint.set("motor/max_impulse", 999.0)  # High value = locked tight
			print("🚪 Door motor locked")
	else:
		push_warning("🚪 HingeJoint3D not found - door may not work properly")

	print("======================================")

	# Update interaction text based on lock state
	_update_prompt()

func _input(event: InputEvent) -> void:
	if not is_grabbed or not door_body or not hinge_joint:
		return

	# Only process if door is unlocked
	if is_locked:
		return

	# Detect mouse movement while grabbed
	if event is InputEventMouseMotion:
		var mouse_delta: Vector2 = event.relative

		# Horizontal mouse movement controls door rotation
		# Positive delta = mouse moving right = push door open
		# Negative delta = mouse moving left = pull door closed
		var torque_strength = mouse_delta.x * mouse_sensitivity

		print("🚪 [Drag] Mouse delta: %s, Torque: %s" % [mouse_delta.x, torque_strength])

		# Apply torque to door - Y axis (door rotates around Y due to axis locks)
		var torque = Vector3(0, torque_strength * drag_force, 0)
		door_body.apply_torque(torque)
		print("🚪 [Drag] Applying torque: %s" % torque)

	# Detect when player releases interact button
	if event.is_action_released("interact"):
		_release_door()

func _on_interacted(_player: PlayerInteractionComponent) -> void:
	print("========== DOOR INTERACTION DEBUG ==========")
	print("🚪 Door '%s' interacted with" % parent_object.name if parent_object else "Unknown")
	print("🚪 Is locked: %s" % is_locked)
	print("🚪 Is grabbed: %s" % is_grabbed)

	if is_locked:
		print("🚪 Door is locked, checking for key flag: '%s'" % required_key_flag)
		# Check if player has the required key flag
		var has_key = WorldStateManager.has_flag(required_key_flag)
		print("🚪 Player has key flag: %s" % has_key)

		if has_key:
			# Unlock the door
			is_locked = false
			print("🚪 ✅ DOOR UNLOCKED!")

			# Unlock the door by disabling the motor
			if hinge_joint:
				hinge_joint.set("motor/enable", false)
				print("🚪 Door motor unlocked")

			# Play unlock sound if you have one
			if interaction_sound:
				_play_sound(interaction_sound)

			_update_prompt()

			# Now grab the door
			_grab_door(_player)
		else:
			# Door is still locked
			print("🚪 ❌ Door is locked. Player needs key '%s'" % required_key_flag)
		print("=============================================")
		return

	# Door is unlocked - grab it
	if not is_grabbed:
		_grab_door(_player)
	else:
		_release_door()

	print("===============================================")

func _grab_door(_player: PlayerInteractionComponent) -> void:
	print("🚪 [Grab] Player grabbed door!")
	is_grabbed = true
	player_ref = _player
	interaction_text = "Release Door"

	# Optionally capture mouse if you want (commented out for now)
	# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_door() -> void:
	print("🚪 [Release] Player released door!")
	is_grabbed = false
	player_ref = null
	_update_prompt()

func _update_prompt() -> void:
	if is_locked:
		interaction_text = locked_text
	else:
		interaction_text = grab_text if not is_grabbed else "Release Door"
