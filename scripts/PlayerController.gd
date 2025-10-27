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

@export_group("Head Bob")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.3

@export_group("FOV Settings")
@export var base_fov: float = 75.0
@export var max_fov_increase: float = 15.0
@export var fov_transition_speed: float = 2.0

@export_group("Interaction Settings")
@export var interaction_distance: float = 5.0
@export var interaction_action: String = "interact"  # Input action name

# --- PRIVATE VARIABLES ---

# We get a reference to the camera in _ready().
var _camera: Camera3D

# Animation controller reference
var _player_animation: PlayerAnimation

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
		print("Camera not found! Please check scene structure.")
		return

	# Capture the mouse when the game starts.
	# This hides the cursor and keeps it centered.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("Mouse captured, camera found at: " + str(_camera.get_path()))
	
	# Store the original camera position for head bob calculations
	_original_camera_position = _camera.position
	
	# Initialize FOV
	_camera.fov = base_fov
	_current_fov = base_fov
	
	# Get reference to animation controller (try common paths)
	if has_node("Model/PlayerAnimation"):
		_player_animation = get_node("Model/PlayerAnimation")
		print("Found PlayerAnimation at: Model/PlayerAnimation")
	elif has_node("PlayerAnimation"):
		_player_animation = get_node("PlayerAnimation")
		print("Found PlayerAnimation at: PlayerAnimation")
	elif has_node("human"):
		_player_animation = get_node("human")
		print("Found PlayerAnimation at: human")
	elif has_node("AnimationController"):
		_player_animation = get_node("AnimationController")
		print("Found PlayerAnimation at: AnimationController")
	
	if _player_animation == null:
		print("PlayerAnimation script not found - animations will be skipped")
		print("Available child nodes:")
		for child in get_children():
			print("  - " + child.name + " (" + child.get_class() + ")")
	else:
		print("PlayerAnimation script found and connected!")

func _process(delta):
	# Update mirrors with camera transform
	if _camera:
		get_tree().call_group("mirrors", "update_cam", _camera.global_transform)

func _physics_process(delta: float) -> void:
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
			var rotation := _camera.rotation
			rotation.x = clamp(rotation.x, deg_to_rad(-80), deg_to_rad(80))
			_camera.rotation = rotation

	# --- INTERACTION ---
	# Handle left mouse click for interacting with objects
	if event is InputEventMouseButton and _camera != null:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# Only interact if mouse is captured (in game mode)
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_handle_interaction()

	# You can also handle other inputs here, like pausing the game.
	if Input.is_action_just_pressed("ui_cancel"): # ESC key
		# Toggle mouse capture
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			print("Mouse released")
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			print("Mouse captured")

func _exit_tree() -> void:
	# Make sure to release the mouse when the player object is removed.
	# This is good practice for when changing scenes or quitting the game.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# --- INTERACTION METHODS ---

func _handle_interaction() -> void:
	# Cast a ray from the camera to see what we're looking at
	var interactable_object = _get_object_under_crosshair()
	
	if interactable_object:
		print("Clicked on: " + str(interactable_object.name))
		_interact_with_object(interactable_object)

func _get_object_under_crosshair() -> Node3D:
	if not _camera:
		return null
	
	# Cast ray from camera center (crosshair position)
	var space_state = _camera.get_world_3d().direct_space_state
	var from = _camera.global_transform.origin
	var to = from + (-_camera.global_transform.basis.z * interaction_distance)
	
	# Create ray query
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]  # Don't hit the player
	query.collision_mask = 1  # Default collision layer
	
	var result = space_state.intersect_ray(query)
	
	if result and result.has("collider"):
		var hit_object = result.collider
		
		# Find the root interactable object (walk up the tree)
		return _find_interactable_parent(hit_object)
	
	return null

func _find_interactable_parent(node: Node) -> Node3D:
	# Walk up the scene tree to find an interactable object
	var current = node
	while current and current != get_tree().root:
		if _is_interactable(current):
			return current
		current = current.get_parent()
	return null

func _is_interactable(node: Node) -> bool:
	# Define what makes an object interactable
	var node_name = node.name.to_lower()
	
	# Check for interactable object names
	var interactable_keywords = ["box", "bottom", "lid", "door", "switch", "button", "lever"]
	
	for keyword in interactable_keywords:
		if keyword in node_name:
			return true
	
	# You can also check for groups or specific scripts
	if node.is_in_group("interactable"):
		return true
	
	return false

func _interact_with_object(object: Node3D) -> void:
	print("Interacting with: " + object.name)
	
	# Handle different types of interactions based on the object
	var object_name = object.name.to_lower()
	
	if "box" in object_name or "bottom" in object_name:
		_interact_with_box(object)
	elif "door" in object_name:
		_interact_with_door(object)
	elif "switch" in object_name or "button" in object_name:
		_interact_with_switch(object)
	else:
		# Generic interaction
		_generic_interaction(object)

func _interact_with_box(box: Node3D) -> void:
	print("Opening/interacting with box: " + box.name)
	
	# Find and control animations
	var animation_players = _find_animation_players_in_object(box)
	
	for anim_player in animation_players:
		if anim_player.has_animation("open"):
			print("Playing 'open' animation")
			anim_player.play("open")
		elif anim_player.has_animation("rotate"):
			print("Restarting 'rotate' animation")
			anim_player.stop()
			anim_player.play("rotate")
		else:
			# Just restart the current animation
			print("Restarting current animation")
			anim_player.stop()
			anim_player.play()
	
	# Add a visual effect (brief glow)
	_add_interaction_effect(box)

func _interact_with_door(door: Node3D) -> void:
	print("Opening/closing door: " + door.name)
	# Add door-specific logic here
	_generic_interaction(door)

func _interact_with_switch(switch: Node3D) -> void:
	print("Toggling switch: " + switch.name)
	# Add switch-specific logic here
	_generic_interaction(switch)

func _generic_interaction(object: Node3D) -> void:
	print("Generic interaction with: " + object.name)
	
	# Find and trigger animations
	var animation_players = _find_animation_players_in_object(object)
	for anim_player in animation_players:
		anim_player.stop()
		anim_player.play()
	
	# Add visual feedback
	_add_interaction_effect(object)

func _find_animation_players_in_object(object: Node3D) -> Array[AnimationPlayer]:
	var animation_players: Array[AnimationPlayer] = []
	_collect_animation_players_recursive(object, animation_players)
	return animation_players

func _collect_animation_players_recursive(node: Node, collection: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		collection.append(node)
	
	for child in node.get_children():
		_collect_animation_players_recursive(child, collection)

func _add_interaction_effect(object: Node3D) -> void:
	# Add a brief visual effect to show interaction
	var mesh_instances = _find_mesh_instances_in_object(object)
	
	for mesh_instance in mesh_instances:
		_create_interaction_glow(mesh_instance)

func _find_mesh_instances_in_object(object: Node3D) -> Array[MeshInstance3D]:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances_recursive(object, mesh_instances)
	return mesh_instances

func _collect_mesh_instances_recursive(node: Node, collection: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		collection.append(node)
	
	for child in node.get_children():
		_collect_mesh_instances_recursive(child, collection)

func _create_interaction_glow(mesh_instance: MeshInstance3D) -> void:
	# Create a brief glow effect
	var original_materials = []
	
	# Store original materials
	for i in mesh_instance.get_surface_override_material_count():
		original_materials.append(mesh_instance.get_surface_override_material(i))
	
	# Apply glow effect
	for i in mesh_instance.get_surface_override_material_count():
		var material = mesh_instance.get_surface_override_material(i)
		if material and material is StandardMaterial3D:
			var glow_material = material.duplicate()
			var std_mat = glow_material as StandardMaterial3D
			std_mat.emission_enabled = true
			std_mat.emission = Color(0.3, 0.3, 1.0)  # Blue glow
			mesh_instance.set_surface_override_material(i, glow_material)
	
	# Remove glow after a short delay
	await get_tree().create_timer(0.3).timeout
	
	# Restore original materials
	for i in original_materials.size():
		mesh_instance.set_surface_override_material(i, original_materials[i])
