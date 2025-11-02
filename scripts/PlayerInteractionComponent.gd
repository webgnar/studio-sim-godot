extends Node3D
class_name PlayerInteractionComponent

## Centralized interaction system for the player
## Handles raycast detection and interaction with objects in the "interactable" group
## Replaces individual raycast logic in each clickable object

# --- SIGNALS ---
signal interactive_object_detected(interactable: Node3D)
signal nothing_detected()
signal interaction_prompt_changed(prompt_text: String)

# --- EXPORTED VARIABLES ---
@export_group("Raycast Settings")
@export var interaction_distance: float = 5.0
@export var raycast_collision_mask: int = 15  # Layers 1-4: All physics layers (Player, Static World, Moving Objects, Interactables)

# --- PRIVATE VARIABLES ---
var _raycast: RayCast3D
var _camera: Camera3D
var current_interactable: Node3D = null

# --- GODOT METHODS ---

func _ready() -> void:
	# Find the camera (should be sibling or child of player)
	_camera = _find_camera()
	
	if not _camera:
		push_error("PlayerInteractionComponent: No camera found! Interaction system disabled.")
		set_process(false)
		return
	
	# Create raycast as child of camera
	_setup_raycast()
	
	print("✅ PlayerInteractionComponent ready - Interaction distance: " + str(interaction_distance) + "m")

func _process(_delta: float) -> void:
	_update_interactable()

func _input(event: InputEvent) -> void:
	# Handle interaction input (E key or left click)
	if event.is_action_pressed("interact") and current_interactable:
		_handle_interaction()

# --- PRIVATE METHODS ---

func _find_camera() -> Camera3D:
	# Try to find camera in player node
	var player = get_parent()
	
	# Try common paths
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
		var result = _find_camera_recursive(child)
		if result:
			return result
	
	return null

func _setup_raycast() -> void:
	_raycast = RayCast3D.new()
	_raycast.name = "InteractionRaycast"
	_raycast.target_position = Vector3(0, 0, -interaction_distance)
	_raycast.collision_mask = raycast_collision_mask
	_raycast.collide_with_areas = false
	_raycast.collide_with_bodies = true
	
	# Add as child of camera so it points where we're looking
	_camera.add_child(_raycast)
	_raycast.enabled = true

func _update_interactable() -> void:
	if not _raycast.is_colliding():
		_clear_interactable()
		return
	
	var hit = _raycast.get_collider()
	
	if not hit:
		_clear_interactable()
		return
	
	# Find the root interactable (might be a parent of what we hit)
	# The raycast might hit a child (like StaticBody3D), but the parent has the group
	var interactable = _find_interactable_root(hit)
	
	if not interactable:
		_clear_interactable()
		return
	
	if interactable != current_interactable:
		_set_interactable(interactable)

func _find_interactable_root(node: Node) -> Node3D:
	# Walk up the tree to find the node in "interactable" group
	var current = node
	var max_depth = 10  # Prevent infinite loops
	var depth = 0
	
	while current and depth < max_depth:
		if current.is_in_group("interactable"):
			return current
		current = current.get_parent()
		depth += 1
	
	return null  # Return null if not found instead of original node

func _set_interactable(new_interactable: Node3D) -> void:
	current_interactable = new_interactable
	interactive_object_detected.emit(new_interactable)
	_update_interaction_prompt()

func _clear_interactable() -> void:
	if current_interactable:
		current_interactable = null
		nothing_detected.emit()
		interaction_prompt_changed.emit("")

func _update_interaction_prompt() -> void:
	if not current_interactable:
		interaction_prompt_changed.emit("")
		return
	
	# Try to get interaction text from InteractionComponent first
	var interaction_component = _find_interaction_component(current_interactable)
	var prompt_text = ""
	
	if interaction_component and "interaction_text" in interaction_component:
		prompt_text = interaction_component.interaction_text
	elif "interaction_text" in current_interactable:
		prompt_text = current_interactable.interaction_text
	else:
		# Default fallback
		prompt_text = "Interact"
	
	interaction_prompt_changed.emit(prompt_text)

func _handle_interaction() -> void:
	if not current_interactable:
		return
	
	# Find the InteractionComponent (might be a child of the interactable)
	var interaction_component = _find_interaction_component(current_interactable)
	
	if interaction_component and interaction_component.has_method("interact"):
		interaction_component.interact(self)
	elif current_interactable.has_method("interact"):
		# Fallback: call interact directly on the object
		current_interactable.interact(self)
	else:
		push_warning("Object " + current_interactable.name + " has no InteractionComponent or interact() method!")

func _find_interaction_component(node: Node) -> Node:
	# Check if node itself is an InteractionComponent
	if node is InteractionComponent:
		return node
	
	# Search children for InteractionComponent
	for child in node.get_children():
		if child is InteractionComponent:
			return child
		# Recursively search deeper
		var found = _find_interaction_component(child)
		if found:
			return found
	
	return null

# --- PUBLIC METHODS ---

## Get the currently targeted interactable object
func get_current_interactable() -> Node3D:
	return current_interactable

## Check if we're currently looking at an interactable
func is_looking_at_interactable() -> bool:
	return current_interactable != null

## Get the camera being used for raycasting
func get_camera() -> Camera3D:
	return _camera

## Get the raycast node
func get_raycast() -> RayCast3D:
	return _raycast

## Update interaction distance at runtime
func set_interaction_distance(distance: float) -> void:
	interaction_distance = distance
	if _raycast:
		_raycast.target_position = Vector3(0, 0, -distance)
