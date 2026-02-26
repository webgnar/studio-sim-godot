extends CharacterBody3D

# --- EXPORTED VARIABLES ---
# These values will be editable in the Godot Inspector.

@export_group("Movement Stats")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var air_control: float = 2.0
@export var inertia: float = 10.0
@export var standing_height: float = 2.0
@export var crouch_height: float = 1.0
@export var crouch_head_y: float = 0.0

@export_group("Camera Stats")
@export var sensitivity: float = 0.003
@export var joystick_sensitivity_multiplier: float = 100.0  # How much to scale joystick input
@export var damping: float = 12.0  # Camera smoothing strength (higher = faster response)

@export_group("Head Bob")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.3

@export_group("FOV Settings")
@export var base_fov: float = 75.0
@export var max_fov_increase: float = 15.0
@export var fov_transition_speed: float = 2.0

@export_group("Interaction Settings")
@export var interaction_distance: float = 5.0

# --- PRIVATE VARIABLES ---

# We get a reference to the camera in _ready().
var _camera: Camera3D

# Camera rotation smoothing variables
var _target_rot: Vector2 = Vector2.ZERO  # Target rotation (pitch, yaw)
var _current_rot: Vector2 = Vector2.ZERO  # Current smoothed rotation

# Animation controller reference
var _player_animation: PlayerAnimation

# Interaction component reference
var _interaction_component: PlayerInteractionComponent

# Head bob variables
var _bob_time: float = 0.0
var _original_camera_position: Vector3
var _prev_bob_y: float = 0.0
var _footstep_triggered: bool = false

# Footstep sounds
var _footstep_streams: Array[AudioStream] = []
@onready var _footstep_player: AudioStreamPlayer = $FootstepSound

# FOV variables
var _current_fov: float

# Crouch state
var _is_crouching: bool = false
var _head_node: Node3D
var _capsule_shape: CapsuleShape3D
var _collision_shape_node: CollisionShape3D
var _standing_head_y: float

# Current speed property - returns appropriate speed based on movement state
var current_speed: float:
	get:
		if _is_crouching:
			return crouch_speed
		return sprint_speed if _is_sprinting() else walk_speed

# --- GODOT METHODS ---

func _ready() -> void:
	# Add player to group for easy reference
	add_to_group("player")
	
	# Get a reference to the Camera3D node.
	# Try multiple possible paths for the camera
	if has_node("Head/Camera3D"):
		_camera = get_node("Head/Camera3D")
	elif has_node("Head/Camera"):
		_camera = get_node("Head/Camera")
	elif has_node("Camera3D"):
		_camera = get_node("Camera3D")
	elif has_node("Camera"):
		_camera = get_node("Camera")
	else:
		push_error("Camera not found! Please check scene structure.")
		return

	# Mouse capture is now handled by UIManager to avoid conflicts
	# PlayerController only recaptures when clicking in-game after ESC
	
	# Store the original camera position for head bob calculations
	_original_camera_position = _camera.position
	
	# Initialize FOV
	_camera.fov = base_fov
	_current_fov = base_fov

	# Initialize camera rotation tracking
	_current_rot = Vector2(_camera.rotation.x, rotation.y)
	_target_rot = _current_rot

	# Register player camera with CameraManager
	if _camera:
		CameraManager.register_player_camera(_camera)
	
	# Get crouch-related references
	_head_node = get_node_or_null("Head")
	if _head_node:
		_standing_head_y = _head_node.position.y
	_collision_shape_node = get_node_or_null("CollisionShape3D")
	if _collision_shape_node:
		_capsule_shape = _collision_shape_node.shape as CapsuleShape3D

	# Get reference to animation controller (try common paths)
	if has_node("Model/PlayerAnimation"):
		_player_animation = get_node("Model/PlayerAnimation")
	elif has_node("PlayerAnimation"):
		_player_animation = get_node("PlayerAnimation")
	elif has_node("human"):
		_player_animation = get_node("human")
	elif has_node("AnimationController"):
		_player_animation = get_node("AnimationController")
	
	# Preload footstep sounds
	_footstep_streams = [
		preload("res://sounds/ftstep.ogg"),
		preload("res://sounds/ftstep2.ogg"),
	]

	# Setup interaction component
	_setup_interaction_component()

func _notification(what: int) -> void:
	"""Handle window focus events for mouse capture"""
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			# Re-capture mouse when window gains focus (if in gameplay state)
			if CameraManager and CameraManager.player_input_enabled:
				# Wait a frame to ensure fullscreen mode is stable before capturing
				call_deferred("_recapture_mouse_on_focus")
				if DebugLogger:
					DebugLogger.write_log("[PlayerController] Window focused - recapturing mouse")
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			# Optional: Log when window loses focus
			var mouse_locked = (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or
								Input.mouse_mode == Input.MOUSE_MODE_CONFINED_HIDDEN)
			if DebugLogger and mouse_locked:
				DebugLogger.write_log("[PlayerController] Window focus lost")

func _recapture_mouse_on_focus() -> void:
	"""Recapture mouse when window regains focus via UIManager"""
	# Use UIManager to ensure proper fullscreen and capture handling
	if UIManager and UIManager.current_state == UIManager.GameState.GAMEPLAY:
		# Re-trigger GAMEPLAY state to recapture mouse properly
		UIManager.change_state(UIManager.GameState.GAMEPLAY)

func _setup_interaction_component() -> void:
	# Check if PlayerInteractionComponent already exists as a child
	for child in get_children():
		if child is PlayerInteractionComponent:
			_interaction_component = child
			_setup_carry_marker()
			return

	# If not found, create one programmatically
	_interaction_component = PlayerInteractionComponent.new()
	_interaction_component.name = "PlayerInteractionComponent"
	_interaction_component.interaction_distance = interaction_distance  # Set from PlayerController export
	add_child(_interaction_component)
	
	# Setup carry marker
	_setup_carry_marker()

func _setup_carry_marker() -> void:
	"""Create or find the carry marker for the interaction component"""
	if not _camera:
		return

	# Check if CarryMarker already exists
	var carry_marker = _camera.get_node_or_null("CarryMarker")

	if not carry_marker:
		# Create it programmatically
		carry_marker = Marker3D.new()
		carry_marker.name = "CarryMarker"
		_camera.add_child(carry_marker)
		carry_marker.position = Vector3(0, 0, -2)  # 2 units in front of camera

	# Assign to interaction component
	if _interaction_component:
		_interaction_component.carry_marker = carry_marker

func _process(_delta) -> void:
	# Update mirrors with camera transform
	if _camera:
		get_tree().call_group("mirrors", "update_cam", _camera.global_transform)

func _physics_process(delta: float) -> void:
	# Skip movement if CameraManager has disabled input (e.g., cinematic camera zones)
	if not CameraManager.player_input_enabled:
		# Still apply gravity and move_and_slide to keep physics working
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return
	
	# --- GRAVITY ---
	# Add gravity. If the character is on the floor, we don't apply gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- JUMPING ---
	# Handle the jump action.
	if SteamInput.is_action_just_pressed("jump") and is_on_floor():
		if _is_crouching:
			# Un-crouch instead of jumping
			_is_crouching = false
			_apply_crouch_shape()
		else:
			velocity.y = jump_velocity

	# --- CROUCH TOGGLE ---
	if SteamInput.is_action_just_pressed("crouch"):
		_is_crouching = !_is_crouching
		_apply_crouch_shape()

	# --- SMOOTH CAMERA CROUCH ---
	if _head_node:
		var target_head_y := crouch_head_y if _is_crouching else _standing_head_y
		_head_node.position.y = lerp(_head_node.position.y, target_head_y, 10.0 * delta)

	# --- MOVEMENT ---
	# Get the input direction vector from the input actions.
	var input_dir := SteamInput.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Convert the 2D input vector to a 3D direction vector.
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		# Full control when on the ground
		if direction != Vector3.ZERO:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			# If no input, apply inertia-based friction to stop the character smoothly.
			var horizontal_velocity := Vector3(velocity.x, 0, velocity.z)
			horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, inertia * delta)
			velocity.x = horizontal_velocity.x
			velocity.z = horizontal_velocity.z
	else:
		# Limited air control - lerp velocity towards input direction
		if direction != Vector3.ZERO:
			var target_velocity := Vector3(direction.x * current_speed, velocity.y, direction.z * current_speed)
			var current_horizontal := Vector3(velocity.x, 0, velocity.z)
			var target_horizontal := Vector3(target_velocity.x, 0, target_velocity.z)
			
			# Lerp horizontal velocity towards target with limited air control
			var new_horizontal := current_horizontal.lerp(target_horizontal, air_control * delta * 3.0)
			velocity.x = new_horizontal.x
			velocity.z = new_horizontal.z

	# --- JOYSTICK CAMERA LOOK ---
	# Handle camera rotation with right stick (accumulate into target rotation)
	if _camera:
		# Use SteamInput for camera - works with Steam Input API or falls back to Godot Input
		var camera_input = SteamInput.get_analog_action("camera")
		var look_x = camera_input.x
		var look_y = camera_input.y

		# Accumulate joystick input into target rotation
		if look_x != 0.0 or look_y != 0.0:
			var joystick_sens = sensitivity * joystick_sensitivity_multiplier

			# Accumulate into target rotation
			# NOTE: Delta scaling is CORRECT here - Steam Input returns normalized -1..1 values,
			# we scale by delta to make rotation frame-rate independent
			_target_rot.y -= look_x * joystick_sens * delta  # Yaw (horizontal)
			_target_rot.x -= look_y * joystick_sens * delta  # Pitch (vertical)

			# Clamp the target pitch to prevent flipping
			_target_rot.x = clamp(_target_rot.x, deg_to_rad(-80), deg_to_rad(80))

	# --- CAMERA SMOOTHING ---
	# Interpolate current rotation toward target rotation using exponential decay
	# This creates smooth, frame-rate independent camera movement
	_current_rot = _current_rot.lerp(_target_rot, 1.0 - exp(-damping * delta))

	# Apply the smoothed rotation to camera (pitch) and player (yaw)
	_camera.rotation.x = _current_rot.x
	rotation.y = _current_rot.y

	# --- DYNAMIC FOV ---
	# Adjust FOV based on movement speed for sense of speed
	var speed_ratio := velocity.length() / sprint_speed  # Use sprint speed as max reference
	var target_fov := base_fov + (speed_ratio * max_fov_increase)
	
	# Clamp the FOV to prevent it from getting too crazy
	target_fov = clamp(target_fov, base_fov, base_fov + max_fov_increase)
	
	# Smoothly transition to target FOV
	_current_fov = lerp(_current_fov, target_fov, fov_transition_speed * delta)
	_camera.fov = _current_fov

	# --- HEAD BOB ---
	# Apply head bob when moving and on the ground
	if is_on_floor() and velocity.length() > 0.1:
		# Calculate speed factor (how fast we're moving relative to max speed)
		var speed_factor := velocity.length() / current_speed
		
		# Calculate dynamic frequency - faster when sprinting
		var current_frequency := bob_frequency * (current_speed / walk_speed)
		
		# Increment bob time based on movement speed and dynamic frequency
		_bob_time += delta * current_frequency * speed_factor
		
		# Calculate vertical bob using sine wave (amplitude scales with speed)
		var bob_y := sin(_bob_time) * bob_amplitude * speed_factor
		
		# Calculate horizontal bob synchronized with vertical - side sway happens every other step
		var bob_x := sin(_bob_time * 0.5) * bob_amplitude * 0.3 * speed_factor
		
		# Footstep sound: play once when bob reaches lowest point (local minimum)
		if bob_y > _prev_bob_y and _prev_bob_y < 0 and not _footstep_triggered:
			_play_footstep()
			_footstep_triggered = true
		elif bob_y <= _prev_bob_y:
			_footstep_triggered = false
		_prev_bob_y = bob_y

		# Apply the bob to the camera position
		_camera.position = _original_camera_position + Vector3(bob_x, bob_y, 0)
	else:
		# When not moving, smoothly return camera to original position
		_camera.position = _camera.position.lerp(_original_camera_position, 5.0 * delta)
		
		# Reset bob time when not moving
		if velocity.length() < 0.1:
			_bob_time = 0.0
			_prev_bob_y = 0.0
			_footstep_triggered = false

	# --- APPLY MOVEMENT ---
	# This is the core function of CharacterBody3D. It moves the character and handles collisions.
	move_and_slide()
	
	# --- UPDATE ANIMATIONS ---
	# Send movement data to animation controller
	if _player_animation != null:
		_player_animation.update_animation_state(velocity, is_on_floor(), _is_sprinting(), _is_crouching)

func _unhandled_input(event: InputEvent) -> void:
	# Skip input if CameraManager has disabled it (e.g., during cinematic cameras)
	if not CameraManager.player_input_enabled:
		return

	# --- MOUSE LOOK ---
	# Accumulate mouse input into target rotation (smoothing applied in _physics_process)
	if event is InputEventMouseMotion and _camera != null:
		var mouse_motion := event as InputEventMouseMotion
		# Process mouse look if mouse is captured OR confined_hidden (macOS compatibility)
		var mouse_locked = (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or
							Input.mouse_mode == Input.MOUSE_MODE_CONFINED_HIDDEN)

		if mouse_locked:
			# Only process mouse input when there's actual motion
			if mouse_motion.relative.length() > 0.01:
				# Accumulate input into target rotation
				_target_rot.x -= mouse_motion.relative.y * sensitivity  # Pitch (vertical)
				_target_rot.y -= mouse_motion.relative.x * sensitivity  # Yaw (horizontal)

				# Clamp the target pitch to prevent flipping
				_target_rot.x = clamp(_target_rot.x, deg_to_rad(-80), deg_to_rad(80))

	# --- MOUSE CLICK HANDLING ---
	# Handle mouse clicks to recapture mouse or interact with objects
	if event is InputEventMouseButton and _camera != null:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# If mouse is not locked, lock it (re-enter game mode)
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				# Use UIManager's state transition instead of direct capture
				# This ensures proper fullscreen handling
				if UIManager:
					UIManager.change_state(UIManager.GameState.GAMEPLAY)
				get_viewport().set_input_as_handled()  # Stop event propagation
				return  # Don't process other interactions while recapturing

func _exit_tree() -> void:
	# Make sure to release the mouse when the player object is removed.
	# This is good practice for when changing scenes or quitting the game.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _is_sprinting() -> bool:
	"""Check if player is sprinting via keyboard Shift or controller sprint button"""
	return Input.is_key_pressed(KEY_SHIFT) or SteamInput.is_action_pressed("sprint")

func play_death_animation() -> void:
	if _player_animation:
		_player_animation.play_animation("fall", 1.0)

func reset_animation() -> void:
	if _player_animation:
		_player_animation.play_animation("idle", 1.0)
		_player_animation._is_jumping = false

func _apply_crouch_shape() -> void:
	if _capsule_shape == null:
		return
	var h := crouch_height if _is_crouching else standing_height
	_capsule_shape.height = h
	# Shift the shape down so the bottom stays at the same floor level
	_collision_shape_node.position.y = (h - standing_height) / 2.0

func _play_footstep() -> void:
	_footstep_player.stream = _footstep_streams.pick_random()
	_footstep_player.pitch_scale = randf_range(0.8, 1.0)
	_footstep_player.play()
