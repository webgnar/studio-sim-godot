extends Node3D
class_name BoxInteraction

# --- SIGNALS ---
signal box_clicked(box_node: Node3D)

# --- EXPORTED VARIABLES ---
@export_group("Interaction Settings")
@export var interaction_distance: float = 5.0  # Maximum distance to interact with box
@export var interaction_key: String = "interact"  # Input action for interaction
@export var show_debug_ray: bool = false  # Show debug ray in editor

# --- PRIVATE VARIABLES ---
var _camera: Camera3D
var _player_controller: CharacterBody3D

# --- GODOT METHODS ---

func _ready() -> void:
	# Find the player and camera
	_find_player_and_camera()
	
	# Add the interact input action if it doesn't exist
	_setup_input_action()
	
	print("BoxInteraction system ready!")

func _find_player_and_camera() -> void:
	# Try to find player in the scene
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Fallback: look for CharacterBody3D with PlayerController script
		for node in get_tree().get_nodes_in_group("player"):
			if node.has_method("_physics_process"):  # Basic check for player
				player = node
				break
	
	if not player:
		# Last resort: search by script name
		player = _find_node_with_script("PlayerController")
	
	if player:
		_player_controller = player
		# Find camera in player
		_camera = _find_camera_in_player(player)
		if _camera:
			print("Found player and camera successfully")
		else:
			print("Warning: Camera not found in player")
	else:
		print("Warning: Player not found")

func _find_node_with_script(script_name: String) -> Node:
	var nodes = get_tree().get_nodes_in_group("player")
	for node in nodes:
		if node.get_script() and str(node.get_script()).contains(script_name):
			return node
	
	# If not in group, search all nodes
	return _search_tree_for_script(get_tree().root, script_name)

func _search_tree_for_script(node: Node, script_name: String) -> Node:
	if node.get_script() and str(node.get_script()).contains(script_name):
		return node
	
	for child in node.get_children():
		var result = _search_tree_for_script(child, script_name)
		if result:
			return result
	return null

func _find_camera_in_player(player: Node) -> Camera3D:
	# Common camera paths in FPS setups
	var camera_paths = [
		"Head/Camera3D",
		"Head/Camera", 
		"Camera3D",
		"Camera"
	]
	
	for path in camera_paths:
		if player.has_node(path):
			return player.get_node(path)
	
	# Search recursively
	return _find_camera_recursive(player)

func _find_camera_recursive(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	
	for child in node.get_children():
		var camera = _find_camera_recursive(child)
		if camera:
			return camera
	return null

func _setup_input_action() -> void:
	# Check if interact action exists, if not create it
	if not InputMap.has_action(interaction_key):
		InputMap.add_action(interaction_key)
		
		# Add left mouse button as default
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(interaction_key, mouse_event)
		
		print("Added 'interact' input action with left mouse button")

func _unhandled_input(event: InputEvent) -> void:
	if not _camera or not _player_controller:
		return
	
	# Check for interaction input (left mouse click by default)
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_interaction()

func _handle_interaction() -> void:
	var box = _get_box_under_crosshair()
	if box:
		print("Box clicked: " + str(box.name))
		box_clicked.emit(box)
		_on_box_interacted(box)

func _get_box_under_crosshair() -> Node3D:
	if not _camera:
		return null
	
	# Cast ray from camera center (crosshair position)
	var space_state = _camera.get_world_3d().direct_space_state
	var from = _camera.global_transform.origin
	var to = from + (-_camera.global_transform.basis.z * interaction_distance)
	
	# Create ray query
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_player_controller]  # Don't hit the player
	query.collision_mask = 1  # Default collision layer
	
	var result = space_state.intersect_ray(query)
	
	if show_debug_ray:
		print("Ray from: ", from, " to: ", to)
		if result:
			print("Hit: ", result.collider, " at: ", result.position)
	
	if result and result.has("collider"):
		var hit_object = result.collider
		
		# Check if we hit a box or any part of it
		return _find_box_in_hierarchy(hit_object)
	
	return null

func _find_box_in_hierarchy(node: Node) -> Node3D:
	# Look for box-related names or check if it's the box itself
	var current = node
	while current:
		if _is_box_node(current):
			return current
		current = current.get_parent()
	return null

func _is_box_node(node: Node) -> bool:
	# Check if this node is a box we want to interact with
	var node_name = node.name.to_lower()
	
	# Check for box-related names
	var box_keywords = ["box", "bottom", "lid", "crate", "container"]
	for keyword in box_keywords:
		if keyword in node_name:
			return true
	
	# You can add more specific checks here
	return false

func _on_box_interacted(box: Node3D) -> void:
	# This is where you define what happens when a box is clicked
	print("Interacting with box: " + box.name)
	
	# Example interactions:
	
	# 1. If it has an AnimationPlayer, play a different animation
	var anim_player = _find_animation_player_in_box(box)
	if anim_player:
		print("Found AnimationPlayer, playing interaction animation")
		# You can change the animation or trigger different behavior
		if anim_player.has_animation("open"):
			anim_player.play("open")
		elif anim_player.has_animation("rotate"):
			# Stop and restart the rotation
			anim_player.stop()
			anim_player.play("rotate")
	
	# 2. Change material or appearance
	_change_box_appearance(box)
	
	# 3. Emit a signal for other systems to respond
	# (Already done above with box_clicked.emit())
	
	# 4. Play a sound effect (if you have audio)
	# _play_interaction_sound()

func _find_animation_player_in_box(box: Node3D) -> AnimationPlayer:
	# Search for AnimationPlayer in the box hierarchy
	return _find_animation_player_recursive(box)

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	
	for child in node.get_children():
		var anim_player = _find_animation_player_recursive(child)
		if anim_player:
			return anim_player
	return null

func _change_box_appearance(box: Node3D) -> void:
	# Example: Change emission or color of the box when clicked
	var mesh_instances = _get_mesh_instances_in_box(box)
	for mesh_instance in mesh_instances:
		if mesh_instance.get_surface_override_material_count() > 0:
			var material = mesh_instance.get_surface_override_material(0)
			if material is StandardMaterial3D:
				var std_mat = material as StandardMaterial3D
				# Make it glow briefly
				std_mat.emission_enabled = true
				std_mat.emission = Color.WHITE
				# Reset after delay
				await get_tree().create_timer(0.5).timeout
				std_mat.emission = Color.BLACK

func _get_mesh_instances_in_box(box: Node3D) -> Array[MeshInstance3D]:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances_recursive(box, mesh_instances)
	return mesh_instances

func _collect_mesh_instances_recursive(node: Node, collection: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		collection.append(node)
	
	for child in node.get_children():
		_collect_mesh_instances_recursive(child, collection)

# --- PUBLIC METHODS ---

func set_interaction_distance(distance: float) -> void:
	interaction_distance = distance

func set_camera(camera: Camera3D) -> void:
	_camera = camera

func set_player(player: CharacterBody3D) -> void:
	_player_controller = player