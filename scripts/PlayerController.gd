extends CharacterBody3D

# --- EXPORTED VARIABLES ---
# These values will be editable in the Godot Inspector.

@export_group("Movement Stats")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var air_control: float = 2.0
@export var inertia: float = 10.0

@export_group("Camera Stats")
@export var sensitivity: float = 0.003
@export var joystick_sensitivity_multiplier: float = 100.0  # How much to scale joystick input

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

# Animation controller reference
var _player_animation: PlayerAnimation

# Interaction component reference
var _interaction_component: PlayerInteractionComponent

# Head bob variables
var _bob_time: float = 0.0
var _original_camera_position: Vector3

# FOV variables
var _current_fov: float

# Current speed property - returns walk or sprint speed based on Shift key
var current_speed: float:
	get:
		return sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed

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

	# Capture the mouse when the game starts.
	# This hides the cursor and keeps it centered.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Store the original camera position for head bob calculations
	_original_camera_position = _camera.position
	
	# Initialize FOV
	_camera.fov = base_fov
	_current_fov = base_fov
	
	# Register player camera with CameraManager
	if _camera:
		CameraManager.register_player_camera(_camera)
	
	# Get reference to animation controller (try common paths)
	if has_node("Model/PlayerAnimation"):
		_player_animation = get_node("Model/PlayerAnimation")
	elif has_node("PlayerAnimation"):
		_player_animation = get_node("PlayerAnimation")
	elif has_node("human"):
		_player_animation = get_node("human")
	elif has_node("AnimationController"):
		_player_animation = get_node("AnimationController")
	
	# Setup interaction component
	_setup_interaction_component()

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
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# --- MOVEMENT ---
	# Get the input direction vector from the input actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
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
	# Handle camera rotation with right stick (axes 2 and 3)
	if _camera:
		var look_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)  # Axis 2
		var look_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)  # Axis 3

		# Apply deadzone to avoid drift
		var deadzone = 0.15
		if abs(look_x) < deadzone:
			look_x = 0.0
		if abs(look_y) < deadzone:
			look_y = 0.0

		# Apply joystick camera rotation (scaled for smooth feel)
		if look_x != 0.0 or look_y != 0.0:
			var joystick_sens = sensitivity * joystick_sensitivity_multiplier

			# Rotate player horizontally (yaw)
			rotate_y(-look_x * joystick_sens * delta)

			# Rotate camera vertically (pitch)
			_camera.rotate_x(-look_y * joystick_sens * delta)

			# Clamp vertical rotation
			var cam_rotation := _camera.rotation
			cam_rotation.x = clamp(cam_rotation.x, deg_to_rad(-80), deg_to_rad(80))
			_camera.rotation = cam_rotation

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
		
		# Apply the bob to the camera position
		_camera.position = _original_camera_position + Vector3(bob_x, bob_y, 0)
	else:
		# When not moving, smoothly return camera to original position
		_camera.position = _camera.position.lerp(_original_camera_position, 5.0 * delta)
		
		# Reset bob time when not moving
		if velocity.length() < 0.1:
			_bob_time = 0.0

	# --- APPLY MOVEMENT ---
	# This is the core function of CharacterBody3D. It moves the character and handles collisions.
	move_and_slide()
	
	# --- UPDATE ANIMATIONS ---
	# Send movement data to animation controller
	if _player_animation != null:
		var is_sprinting := Input.is_key_pressed(KEY_SHIFT)
		_player_animation.update_animation_state(velocity, is_on_floor(), is_sprinting)

func _unhandled_input(event: InputEvent) -> void:
	# Skip input if CameraManager has disabled it (e.g., during cinematic cameras)
	if not CameraManager.player_input_enabled:
		return
	
	# --- MOUSE LOOK ---
	# This function handles mouse rotation for the camera.
	if event is InputEventMouseMotion and _camera != null:
		var mouse_motion := event as InputEventMouseMotion
		# Only process mouse look if mouse is captured
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# Rotate the player horizontally (Yaw).
			# We rotate the entire CharacterBody3D node.
			rotate_y(-mouse_motion.relative.x * sensitivity)

			# Rotate the camera vertically (Pitch).
			# We rotate the Camera3D node itself.
			_camera.rotate_x(-mouse_motion.relative.y * sensitivity)

			# Clamp the vertical rotation to prevent the camera from flipping over.
			var cam_rotation := _camera.rotation
			cam_rotation.x = clamp(cam_rotation.x, deg_to_rad(-80), deg_to_rad(80))
			_camera.rotation = cam_rotation

	# --- MOUSE CLICK HANDLING ---
	# Handle mouse clicks to recapture mouse or interact with objects
	if event is InputEventMouseButton and _camera != null:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# If mouse is not captured, capture it (re-enter game mode)
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return  # Don't process other interactions while recapturing

	# You can also handle other inputs here, like pausing the game.
	if Input.is_action_just_pressed("ui_cancel"): # ESC key
		# Toggle mouse capture
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	# Make sure to release the mouse when the player object is removed.
	# This is good practice for when changing scenes or quitting the game.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
