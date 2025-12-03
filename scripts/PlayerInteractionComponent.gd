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

@export_group("Carry Settings")
@export var carry_marker: Node3D  # Marker3D that defines carry position (child of camera)

# --- PRIVATE VARIABLES ---
var _raycast: RayCast3D
var _camera: Camera3D
var current_interactable: Node3D = null
var outline_manager: OutlineManager = null

# --- CARRY STATE ---
var carried_object: CarryableComponent = null

var is_carrying: bool:
	get: return carried_object != null

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

	# Setup outline manager
	outline_manager = OutlineManager.new()
	add_child(outline_manager)

func _process(_delta: float) -> void:
	_update_interactable()

func _input(event: InputEvent) -> void:
	# LEFT CLICK - Pickup or Throw
	if event.is_action_pressed("action_primary"):
		# If carrying, throw the object
		if is_carrying and is_instance_valid(carried_object):
			# Special case: carrying a power plug near an outlet
			if carried_object is PowerCordPlugComponent:
				var plug = carried_object as PowerCordPlugComponent
				if plug.is_near_outlet():
					# Plug it in instead of throwing
					plug.drop()  # This will auto-plug due to auto_plug_on_release
					get_viewport().set_input_as_handled()  # Prevent sticker placement
					return

			# Normal throw - use object's throw_power setting
			var throw_force = carried_object.throw_power if carried_object else 15.0
			throw_carried_object(throw_force)
			get_viewport().set_input_as_handled()  # Prevent sticker placement
			return

		# If not carrying, check if looking at a carryable object
		if current_interactable:
			var carryable = _find_carryable_component(current_interactable)
			if carryable and not carryable.is_being_carried():
				# Pickup the object (don't call interact())
				carryable.pickup(self)
				get_viewport().set_input_as_handled()  # Prevent sticker placement
				return
	
	# RIGHT CLICK - Drop (gentle release)
	if event.is_action_pressed("action_secondary"):
		if is_carrying and is_instance_valid(carried_object):
			# Gentle drop
			drop_carried_object()
			return
	
	# E KEY - Interact (always interaction, never drop)
	if event.is_action_pressed("interact"):
		# If carrying an object with E-key interaction enabled, interact with it
		if is_carrying and is_instance_valid(carried_object):
			# Check if carried object has E-key interaction
			if carried_object.has_e_key_interaction and carried_object.can_interact_while_carried:
				# Call the interaction on the carried object
				carried_object._handle_e_key_interaction(self)
				get_viewport().set_input_as_handled()
				return

			# Special case: carrying a power plug near an outlet
			if carried_object is PowerCordPlugComponent:
				var plug = carried_object as PowerCordPlugComponent
				if plug.nearby_outlet:
					# Plug it in
					plug.nearby_outlet.accept_plug(plug)
					get_viewport().set_input_as_handled()
					return

			# If no E-key interaction, do nothing (use right-click to drop)
			return

		# Not carrying - interact with what we're looking at
		if current_interactable:
			_handle_interaction()
			get_viewport().set_input_as_handled()

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
	# Temporarily extend raycast distance to check for objects with custom distances
	var original_distance = interaction_distance
	var max_check_distance = 20.0  # Maximum distance to check for custom interactions
	_raycast.target_position = Vector3(0, 0, -max_check_distance)
	_raycast.force_raycast_update()

	if not _raycast.is_colliding():
		_raycast.target_position = Vector3(0, 0, -original_distance)
		_clear_interactable()
		return

	var hit = _raycast.get_collider()

	if not hit:
		_raycast.target_position = Vector3(0, 0, -original_distance)
		_clear_interactable()
		return

	# Find the root interactable (might be a parent of what we hit)
	# The raycast might hit a child (like StaticBody3D), but the parent has the group
	var interactable = _find_interactable_root(hit)

	if not interactable:
		_raycast.target_position = Vector3(0, 0, -original_distance)
		_clear_interactable()
		return

	# Check if this interactable has a custom interaction distance
	var interaction_comp = _find_interaction_component(interactable)
	var effective_distance = original_distance

	if interaction_comp and "custom_interaction_distance" in interaction_comp:
		if interaction_comp.custom_interaction_distance > 0:
			effective_distance = interaction_comp.custom_interaction_distance

	# Check if we're within the effective interaction distance
	var distance_to_object = _raycast.get_collision_point().distance_to(_camera.global_position)
	if distance_to_object > effective_distance:
		_raycast.target_position = Vector3(0, 0, -original_distance)
		_clear_interactable()
		return

	# Restore original raycast distance
	_raycast.target_position = Vector3(0, 0, -original_distance)

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

	# Show outline on new interactable
	if outline_manager:
		outline_manager.show_outline(new_interactable)

func _clear_interactable() -> void:
	if current_interactable:
		current_interactable = null
		nothing_detected.emit()
		interaction_prompt_changed.emit("")

		# Hide outline
		if outline_manager:
			outline_manager.hide_outline()

func _update_interaction_prompt() -> void:
	if not current_interactable:
		interaction_prompt_changed.emit("")
		return
	
	# Don't show interaction prompts while carrying (show carry controls instead)
	if is_carrying:
		interaction_prompt_changed.emit("")
		return
	
	# Check if object is carryable
	var carryable_component = _find_carryable_component(current_interactable)
	var interaction_component = _find_interaction_component(current_interactable)
	
	var prompt_text = ""
	
	# If it's carryable with E-key interaction enabled, show both prompts
	if carryable_component and carryable_component.has_e_key_interaction:
		prompt_text = "[Click] Pick Up | [E] " + carryable_component.e_key_interaction_text
	# If it's only carryable (no E-key interaction), show pickup prompt
	elif carryable_component:
		prompt_text = "[Click] Pick Up"
	# If it has an interaction component (but not carryable), show E-key prompt
	elif interaction_component and "interaction_text" in interaction_component:
		prompt_text = "[E] " + interaction_component.interaction_text
	elif "interaction_text" in current_interactable:
		prompt_text = "[E] " + current_interactable.interaction_text
	else:
		# Default fallback
		prompt_text = "[E] Interact"
	
	interaction_prompt_changed.emit(prompt_text)

func _rebuild_interaction_prompts() -> void:
	"""Rebuild/update interaction prompts - called when carry state changes"""
	_update_interaction_prompt()

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

func _find_carryable_component(node: Node) -> CarryableComponent:
	# Check if node itself is a CarryableComponent
	if node is CarryableComponent:
		return node
	
	# Search children for CarryableComponent
	for child in node.get_children():
		if child is CarryableComponent:
			return child
		# Recursively search deeper
		var found = _find_carryable_component(child)
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

# --- CARRY METHODS ---

## Start carrying an object
func start_carrying(carryable: CarryableComponent) -> void:
	carried_object = carryable
	_rebuild_interaction_prompts()

## Stop carrying the current object
func stop_carrying() -> void:
	carried_object = null
	_rebuild_interaction_prompts()

## Get the carry position in world space (where carried objects float)
func get_carry_position(offset: float = 0.0) -> Vector3:
	# Calculate camera forward direction
	var forward = -_camera.global_transform.basis.z if _camera else Vector3.FORWARD

	if not carry_marker:
		# Fallback: 2 units in front of camera
		if _camera:
			return _camera.global_position + forward * (2.0 + offset)
		return global_position

	# Calculate position with offset along camera forward direction
	var destination = carry_marker.global_position + forward * offset
	
	# Check if raycast hits something between player and destination
	# This prevents carrying objects through walls
	if _raycast.is_colliding():
		var collision_point = _raycast.get_collision_point()
		var to_destination = _raycast.global_position.distance_squared_to(destination)
		var to_collision = _raycast.global_position.distance_squared_to(collision_point)
		
		# Use whichever is closer: destination or wall
		if to_collision < to_destination:
			return collision_point
	
	return destination

## Get the direction the player is looking (normalized)
func get_look_direction() -> Vector3:
	if not _camera:
		return -global_transform.basis.z
	return -_camera.global_transform.basis.z

## Throw the carried object
func throw_carried_object(power: float = 15.0) -> void:
	if not is_carrying or not is_instance_valid(carried_object):
		return

	carried_object.throw(power)

## Drop the carried object gently
func drop_carried_object() -> void:
	if not is_carrying or not is_instance_valid(carried_object):
		return

	var drop_force = carried_object.drop_power if carried_object else 1.0
	carried_object.throw(drop_force)
