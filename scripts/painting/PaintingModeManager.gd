extends Node

## Global manager for painting system input routing
## Handles automatic routing between 3D (Sprite3D) and 2D (SubViewport) painting systems
## based on raycast detection of canvas plane

# References to painting systems (set by world scene)
var painting_system_3d: PaintingSystem = null
var painting_system_2d: PaintingSystem2D = null
var painting_root_3d: Node3D = null
var painting_root_2d: Node3D = null

# Camera reference
var camera: Camera3D = null

# Raycast settings
@export var raycast_distance: float = 10.0

func _ready():
	pass

func _unhandled_input(event):
	"""Route painting input to appropriate system based on raycast target"""
	var should_place = false
	var should_undo = false

	# Detect painting actions
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			should_place = true
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			should_undo = true
	elif event.is_action_pressed("action_primary"):
		should_place = true
	elif event.is_action_pressed("action_secondary"):
		should_undo = true

	# Handle placement action
	if should_place:
		var raycast_result = _perform_unified_raycast()
		if not raycast_result:
			return

		if _is_canvas_plane(raycast_result):
			# Route to 2D system
			if painting_system_2d:
				painting_system_2d.handle_primary_action(raycast_result)
				get_viewport().set_input_as_handled()
		else:
			# Route to 3D system (with interactable check)
			if not _is_raycast_hitting_interactable(raycast_result):
				if painting_system_3d:
					painting_system_3d.handle_primary_action(raycast_result)
					get_viewport().set_input_as_handled()

	# Handle undo action
	if should_undo:
		var raycast_result = _perform_unified_raycast()
		if _is_canvas_plane(raycast_result):
			# Undo from 2D system
			if painting_system_2d:
				painting_system_2d.handle_secondary_action()
				get_viewport().set_input_as_handled()
		else:
			# Undo from 3D system
			if painting_system_3d:
				painting_system_3d.handle_secondary_action()
				get_viewport().set_input_as_handled()

func _perform_unified_raycast() -> Dictionary:
	"""Perform raycast from camera through mouse position"""
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return {}

	var viewport = camera.get_viewport()
	var mouse_pos: Vector2

	# Handle FPS mode (captured mouse)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_pos = viewport.get_visible_rect().size / 2.0
	else:
		mouse_pos = viewport.get_mouse_position()

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * raycast_distance

	# Get world from camera (Node extends Node, doesn't have get_world_3d)
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	return space_state.intersect_ray(query)

func _is_canvas_plane(raycast_result: Dictionary) -> bool:
	"""Check if raycast hit the 2D painting canvas"""
	if not raycast_result or not raycast_result.has("collider"):
		return false

	var collider = raycast_result.collider

	# Primary: Check group membership
	if collider.is_in_group("2d_painting_canvas"):
		return true

	# Fallback: Check collision layer
	if collider.collision_layer & 4:  # Layer 4
		return true

	return false

func _is_raycast_hitting_interactable(raycast_result: Dictionary) -> bool:
	"""Check if raycast hit an interactable object (should block sticker placement)"""
	if not raycast_result or not raycast_result.has("collider"):
		return false

	var hit_object = raycast_result.collider

	# Walk up the node tree to find if this is part of an interactable
	var current = hit_object
	var max_depth = 10  # Prevent infinite loops
	var depth = 0

	while current and depth < max_depth:
		# Check if node is in "interactable" group
		if current.is_in_group("interactable"):
			return true

		# Check if node has CarryableComponent (pickupable objects)
		for child in current.get_children():
			if child is CarryableComponent:
				return true

		current = current.get_parent()
		depth += 1

	return false

func register_3d_system(system: PaintingSystem, root: Node3D):
	"""Register the 3D painting system"""
	painting_system_3d = system
	painting_root_3d = root

func register_2d_system(system: PaintingSystem2D, root: Node3D):
	"""Register the 2D painting system"""
	painting_system_2d = system
	painting_root_2d = root

func sync_sticker_selection(index: int):
	"""Sync sticker selection across both systems"""
	if painting_system_3d:
		painting_system_3d.selected_sticker_index = index

	if painting_system_2d:
		painting_system_2d.selected_sticker_index = index
