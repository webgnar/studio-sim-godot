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
@export var controller_sensitivity: float = 3.0  # How responsive to controller stick input

@export_group("Sounds")
@export var unlock_sound: AudioStream  # Sound played when door is unlocked
@export var slam_sound: AudioStream  # Sound played when door slams at min/max angle
@export var creak_sound: AudioStream  # Sound played when door swings slowly
@export var slam_velocity_threshold: float = 5.0  # Angular velocity for slam sound
@export var creak_velocity_threshold: float = 1.5  # Angular velocity for creak sound

var door_body: RigidBody3D = null
var hinge_joint: HingeJoint3D = null
var is_grabbed: bool = false
var player_ref: Node = null

# Physics tracking for sounds
var previous_velocity: float = 0.0  # Track velocity from last frame for slam detection
var creak_timer: float = 0.0  # Timer to control creak sound intervals

func _on_ready() -> void:
	# Ensure audio player exists for custom sounds
	if not _audio_player and (unlock_sound or slam_sound or creak_sound):
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "DoorAudio"
		_audio_player.max_distance = 10.0
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_audio_player.bus = "SFX"
		add_child(_audio_player)

	# Find the door rigid body
	door_body = parent_object.get_node_or_null(collision_body_name)

	if not door_body:
		push_error("DoorInteraction: Door body '%s' not found!" % collision_body_name)

	# Find the hinge joint
	hinge_joint = parent_object.get_node_or_null("HingeJoint3D")
	if hinge_joint:
		# Lock the door initially by enabling the motor and setting target to 0
		if is_locked:
			hinge_joint.set("motor/enable", true)
			hinge_joint.set("motor/target_velocity", 0.0)
			hinge_joint.set("motor/max_impulse", 999.0)  # High value = locked tight
	else:
		push_warning("DoorInteraction: HingeJoint3D not found - door may not work properly")

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

		# Apply torque to door - Y axis (door rotates around Y due to axis locks)
		var torque = Vector3(0, torque_strength * drag_force, 0)
		door_body.apply_torque(torque)

	# Detect when player releases interact button
	if event.is_action_released("interact"):
		_release_door()

func _on_interacted(_player: PlayerInteractionComponent) -> void:
	if is_locked:
		# Check if player has the required key flag
		var has_key = WorldStateManager.has_flag(required_key_flag)

		if has_key:
			# Unlock the door
			is_locked = false

			# Unlock the door by disabling the motor
			if hinge_joint:
				hinge_joint.set("motor/enable", false)

			# Play unlock sound
			if unlock_sound:
				_play_sound(unlock_sound)

			_update_prompt()

			# Now grab the door
			_grab_door(_player)
		return

	# Door is unlocked - grab it
	if not is_grabbed:
		_grab_door(_player)
	else:
		_release_door()

func _grab_door(_player: PlayerInteractionComponent) -> void:
	is_grabbed = true
	player_ref = _player
	interaction_text = "Release Door"

	# Optionally capture mouse if you want (commented out for now)
	# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_door() -> void:
	is_grabbed = false
	player_ref = null
	_update_prompt()

func _update_prompt() -> void:
	if is_locked:
		if WorldStateManager.has_flag(required_key_flag):
			interaction_text = "Unlock"
		else:
			interaction_text = locked_text
	else:
		interaction_text = grab_text if not is_grabbed else "Release Door"

func _physics_process(delta: float) -> void:
	# Keep prompt text in sync while locked (flag may change after load)
	if is_locked:
		_update_prompt()
		return
	if not door_body or not hinge_joint:
		return

	# --- CONTROLLER DOOR SWING ---
	# Poll both sticks so the player can swing the door while grabbed.
	# Left stick X = body movement feel, right stick X = look/rotate feel.
	if is_grabbed:
		var move_input = SteamInput.get_analog_action("move")
		var camera_input = SteamInput.get_analog_action("camera")
		var stick_x = clamp(move_input.x + camera_input.x, -1.0, 1.0)
		if abs(stick_x) > 0.1:  # dead zone
			var torque_strength = stick_x * drag_force * controller_sensitivity * delta
			door_body.apply_torque(Vector3(0, torque_strength, 0))

	# Update creak timer
	creak_timer -= delta

	# Get current angle and angular velocity
	var angular_velocity = door_body.angular_velocity.y  # Door rotates around Y axis
	var abs_angular_velocity = abs(angular_velocity)
	var abs_previous_velocity = abs(previous_velocity)

	# Determine if door is opening (moving toward upper limit) or closing (moving toward lower limit)
	var is_opening = angular_velocity > 0  # Positive velocity = opening toward upper limit

	# Detect door slam by checking if velocity suddenly dropped
	# This indicates the door hit a limit and stopped/bounced
	var velocity_drop = abs_previous_velocity - abs_angular_velocity
	var velocity_drop_threshold = 3.0  # How much velocity must drop to count as impact

	# Door slammed if:
	# 1. Previous velocity was above slam threshold (door was moving fast)
	# 2. Velocity suddenly dropped significantly (door hit something)
	# 3. Current velocity is low (door has stopped or bounced)
	if abs_previous_velocity >= slam_velocity_threshold and velocity_drop >= velocity_drop_threshold and abs_angular_velocity < 2.0:
		# Play slam sound
		if slam_sound and not _is_sound_playing():
			_play_sound(slam_sound)

	# Check for door creak (slow opening motion only)
	elif is_opening and abs_angular_velocity > 0.1 and abs_angular_velocity < creak_velocity_threshold:
		# Play creak sound periodically while door is creaking open
		if creak_sound and creak_timer <= 0.0 and not _is_sound_playing():
			_play_sound(creak_sound)
			creak_timer = 0.5  # Play creak sound every 0.5 seconds while creaking

	# Store current state for next frame
	previous_velocity = angular_velocity

func _is_sound_playing() -> bool:
	# Check if the interaction sound player is currently playing
	# This prevents overlapping slam sounds
	if _audio_player:
		return _audio_player.playing
	return false
