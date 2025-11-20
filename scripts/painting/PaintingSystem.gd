extends Node3D
class_name PaintingSystem

## Core painting system - manages stickers on canvas
## Handles spawning, movement, ordering, rotation of layers

# Node references (assign in inspector or via code)
@export var canvas_root: Node3D
@export var wall_collision: CollisionObject3D  # The StaticBody3D for raycasting

# Sticker library - available stickers to place
var sticker_library: Array[PaintingLayerDefinition] = []

# Currently placed layers on canvas
var placed_layers: Array[PlacedLayer] = []

# Current state
var selected_sticker_index: int = 0  # Which sticker is selected from library
var selected_layer: PlacedLayer = null  # Currently selected placed layer
var is_dragging: bool = false
var next_order: int = 0  # Next available order value
var last_cycle_time: float = 0.0  # For debouncing Q/E keys

# Input settings
@export var raycast_distance: float = 10.0
@export var rotation_speed: float = 90.0  # Degrees per second

# References
var camera: Camera3D = null

func _ready():
	# Find camera
	camera = get_viewport().get_camera_3d()

	# Load sticker library from folder
	_load_sticker_library()

	print("PaintingSystem ready. Loaded %d stickers." % sticker_library.size())
	if sticker_library.size() > 0:
		print("Selected sticker: %s" % sticker_library[selected_sticker_index].id)

func _load_sticker_library():
	"""Load all sticker textures from the sprites/painting layers folder"""
	var sticker_paths = [
		"res://sprites/painting layers/1.png",
		"res://sprites/painting layers/2.png",
		"res://sprites/painting layers/3.png",
		"res://sprites/painting layers/4.png",
		"res://sprites/painting layers/5.png"
	]

	for i in range(sticker_paths.size()):
		var path = sticker_paths[i]
		var texture = load(path) as Texture2D
		if texture:
			var definition = PaintingLayerDefinition.new("sticker_%d" % (i + 1), texture, 0)
			definition.unlocked = true  # All unlocked for testing
			sticker_library.append(definition)
		else:
			push_error("Failed to load sticker texture: %s" % path)

func _process(delta):
	if not camera or not canvas_root:
		return

	var current_time = Time.get_ticks_msec() / 1000.0

	# Cycle stickers with Q/E keys (debounced)
	if Input.is_physical_key_pressed(KEY_Q) and (current_time - last_cycle_time) > 0.2:
		cycle_sticker(-1)
		last_cycle_time = current_time
	if Input.is_physical_key_pressed(KEY_E) and (current_time - last_cycle_time) > 0.2:
		cycle_sticker(1)
		last_cycle_time = current_time

	# Handle rotation of selected layer
	if selected_layer and Input.is_action_pressed("ui_left"):
		rotate_layer(selected_layer, rotation_speed * delta)
	if selected_layer and Input.is_action_pressed("ui_right"):
		rotate_layer(selected_layer, -rotation_speed * delta)

	# Handle z-order adjustment
	if selected_layer and Input.is_action_just_pressed("ui_up"):
		raise_layer_order(selected_layer)
	if selected_layer and Input.is_action_just_pressed("ui_down"):
		lower_layer_order(selected_layer)

func _input(event):
	if not camera or not canvas_root:
		return

	# Left click to place sticker or start dragging
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_mouse_click()
		else:
			is_dragging = false

	# Mouse motion for dragging
	if event is InputEventMouseMotion and is_dragging and selected_layer:
		_handle_drag_motion()

	# Right click to deselect
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		selected_layer = null
		print("Deselected layer")

func _handle_mouse_click():
	"""Handle left mouse click - place new sticker or select existing one"""
	var raycast_result = _raycast_from_mouse()

	if not raycast_result:
		return

	var hit_position = raycast_result.position
	var hit_normal = raycast_result.normal

	# Check if we clicked on an existing sticker (with better tolerance)
	var clicked_layer = _get_layer_at_position(hit_position)

	if clicked_layer:
		# Select existing layer and prepare for dragging
		selected_layer = clicked_layer
		is_dragging = true
		print("Selected layer: %s (order: %d)" % [selected_layer.id, selected_layer.order])
	else:
		# Only place new sticker if we're not currently dragging
		if not is_dragging:
			spawn_sticker(hit_position, hit_normal)

func _handle_drag_motion():
	"""Handle mouse motion while dragging a sticker"""
	var raycast_result = _raycast_from_mouse()

	if raycast_result and selected_layer and selected_layer.node:
		var hit_position = raycast_result.position
		# Convert to canvas local space
		var local_pos = canvas_root.to_local(hit_position)
		selected_layer.node.position = local_pos

func _raycast_from_mouse() -> Dictionary:
	"""Perform raycast from camera through mouse position"""
	if not camera:
		return {}

	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * raycast_distance

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	return result

func _get_layer_at_position(world_position: Vector3) -> PlacedLayer:
	"""Find if there's a placed layer near the clicked position"""
	var local_pos = canvas_root.to_local(world_position)
	var min_distance = 0.5  # Increased tolerance for click detection
	var closest_layer: PlacedLayer = null
	var closest_dist = min_distance

	# Check in reverse order (top layers first)
	var reversed_layers = placed_layers.duplicate()
	reversed_layers.reverse()

	for layer in reversed_layers:
		if layer.node:
			# Check 2D distance (ignore Z depth for selection)
			var layer_pos_2d = Vector2(layer.node.position.x, layer.node.position.y)
			var click_pos_2d = Vector2(local_pos.x, local_pos.y)
			var dist = layer_pos_2d.distance_to(click_pos_2d)

			if dist < closest_dist:
				closest_dist = dist
				closest_layer = layer
				break  # Return first hit (topmost layer)

	return closest_layer

func spawn_sticker(world_position: Vector3, normal: Vector3):
	"""Spawn a new sticker at the given world position"""
	if sticker_library.is_empty():
		push_error("No stickers in library!")
		return

	var definition = sticker_library[selected_sticker_index]

	# Create Sprite3D node
	var sprite = Sprite3D.new()
	sprite.texture = definition.texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.shaded = false  # Unshaded material
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = 0.005  # Smaller size - adjust as needed
	sprite.no_depth_test = false
	sprite.render_priority = next_order

	# Add to canvas FIRST
	canvas_root.add_child(sprite)

	# Convert world position to canvas local space
	var local_pos = canvas_root.to_local(world_position)

	# Offset slightly in front of canvas (towards camera) to ensure visibility
	# Assuming canvas faces -Z, we offset in +Z
	local_pos.z = 0.001 * next_order  # Stack stickers slightly apart

	sprite.position = local_pos

	# Make sprite face the camera (along canvas -Z axis)
	# This assumes CanvasRoot is oriented correctly
	sprite.look_at(sprite.global_position + canvas_root.global_transform.basis.z, Vector3.UP)

	# Debug print
	print("Spawned sticker: %s at local pos: %s, global pos: %s" % [definition.id, local_pos, sprite.global_position])

	# Create placed layer data
	var placed = PlacedLayer.new(definition.id, sprite, next_order)
	placed_layers.append(placed)

	next_order += 1

	# Select the newly placed sticker
	selected_layer = placed

func cycle_sticker(direction: int):
	"""Cycle through available stickers in library"""
	if sticker_library.is_empty():
		return

	selected_sticker_index = (selected_sticker_index + direction) % sticker_library.size()
	if selected_sticker_index < 0:
		selected_sticker_index = sticker_library.size() - 1

	print("Selected sticker: %s (%d/%d)" % [
		sticker_library[selected_sticker_index].id,
		selected_sticker_index + 1,
		sticker_library.size()
	])

func rotate_layer(layer: PlacedLayer, degrees: float):
	"""Rotate a layer around the canvas normal"""
	if not layer or not layer.node:
		return

	layer.rotation_deg += degrees

	# Rotate around local Z axis (perpendicular to canvas)
	var radians = deg_to_rad(degrees)
	layer.node.rotate_object_local(Vector3(0, 0, 1), radians)

func raise_layer_order(layer: PlacedLayer):
	"""Increase layer's z-order (bring forward)"""
	if not layer or not layer.node:
		return

	layer.order += 1
	layer.node.render_priority = layer.order
	print("Raised layer %s to order %d" % [layer.id, layer.order])

func lower_layer_order(layer: PlacedLayer):
	"""Decrease layer's z-order (send backward)"""
	if not layer or not layer.node:
		return

	layer.order -= 1
	layer.node.render_priority = layer.order
	print("Lowered layer %s to order %d" % [layer.id, layer.order])

func clear_canvas():
	"""Remove all placed stickers from canvas"""
	for layer in placed_layers:
		if layer.node:
			layer.node.queue_free()
	placed_layers.clear()
	next_order = 0
	selected_layer = null
	print("Canvas cleared")

# Validation system (for Phase 2)
func verify_painting(target: PaintingMission) -> bool:
	"""Check if current canvas matches the target painting"""
	if placed_layers.size() != target.target_layers.size():
		return false

	# Sort player layers by order
	var sorted_layers = placed_layers.duplicate()
	sorted_layers.sort_custom(func(a, b): return a.order < b.order)

	# Compare each layer ID
	for i in range(target.target_layers.size()):
		if sorted_layers[i].id != target.target_layers[i].id:
			return false

	return true
