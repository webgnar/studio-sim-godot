extends Node3D
class_name PaintingSystem

## Core painting system - manages stickers on canvas
## Handles spawning, movement, ordering, rotation of layers

# Signals
signal layer_equipped(index: int)  # Emitted when Q/E changes the equipped sticker

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
var input_enabled: bool = true  # Can be disabled when not active mode

# Input settings
@export var raycast_distance: float = 10.0
@export var sticker_scale: float = 1  # Scale stickers to fit canvas better
@export var enable_dragging: bool = false  # Disable dragging for now

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
	var folder_path = "res://sprites/painting layers/"
	var dir = DirAccess.open(folder_path)

	if not dir:
		push_error("Failed to open sticker folder: %s" % folder_path)
		return

	# Get all PNG files in the folder
	var file_names: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			file_names.append(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	# Sort alphabetically so they're in consistent order
	file_names.sort()

	# Load each texture
	for i in range(file_names.size()):
		var path = folder_path + file_names[i]
		var texture = load(path) as Texture2D
		if texture:
			var sticker_name = file_names[i].get_basename()  # Remove .png extension
			var definition = PaintingLayerDefinition.new(sticker_name, texture, 0)
			definition.unlocked = true  # All unlocked for testing
			sticker_library.append(definition)
		else:
			push_error("Failed to load sticker texture: %s" % path)

func _process(delta):
	if not camera or not canvas_root or not input_enabled:
		return

	# Cycle stickers with Q/E keys or mouse wheel
	if Input.is_action_just_pressed("cycle_sticker_prev"):
		cycle_sticker(-1)
	if Input.is_action_just_pressed("cycle_sticker_next"):
		cycle_sticker(1)

	# Number keys 1-5 to select placed stickers
	if Input.is_action_just_pressed("ui_text_delete"):  # Delete selected sticker
		delete_selected_layer()

	# Handle rotation of selected layer (90 degree snapping)
	if selected_layer and Input.is_action_just_pressed("ui_left"):
		rotate_layer_90(selected_layer, -1)  # Counter-clockwise
	if selected_layer and Input.is_action_just_pressed("ui_right"):
		rotate_layer_90(selected_layer, 1)  # Clockwise

	# Handle z-order adjustment
	if selected_layer and Input.is_action_just_pressed("ui_up"):
		raise_layer_order(selected_layer)
	if selected_layer and Input.is_action_just_pressed("ui_down"):
		lower_layer_order(selected_layer)

func _input(event):
	if not camera or not canvas_root or not input_enabled:
		return

	# Left click to place sticker only (no selection)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var raycast_result = _raycast_from_mouse()
		if raycast_result:
			spawn_sticker(raycast_result.position, raycast_result.normal)

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
	sprite.no_depth_test = false
	sprite.render_priority = next_order

	# Calculate pixel size based on texture dimensions and canvas size
	# Goal: Make stickers fit proportionally on the canvas
	var texture_size = definition.texture.get_size()
	var aspect_ratio = texture_size.x / texture_size.y

	# Base pixel size to fit canvas (3x2 wall)
	# This makes the sticker take up roughly 1/4 of the canvas by default
	sprite.pixel_size = sticker_scale / max(texture_size.x, texture_size.y)

	# Add to canvas FIRST
	canvas_root.add_child(sprite)

	# Position sticker at raycast hit point (in world space first)
	sprite.global_position = world_position

	# Align sprite to face away from wall (opposite of normal)
	# The sprite should face the camera/player
	sprite.look_at(world_position - normal, Vector3.UP)

	# Offset slightly in front of wall to avoid z-fighting
	sprite.global_position = world_position + (normal * 0.001)

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

	# Notify UI that the equipped layer changed
	layer_equipped.emit(selected_sticker_index)

func rotate_layer_90(layer: PlacedLayer, direction: int):
	"""Rotate a layer by 90 degrees (snapping)"""
	if not layer or not layer.node:
		return

	# Snap to 90-degree increments
	var rotation_step = 90.0 * direction
	layer.rotation_deg += rotation_step

	# Normalize to 0-360 range
	layer.rotation_deg = fmod(layer.rotation_deg, 360.0)
	if layer.rotation_deg < 0:
		layer.rotation_deg += 360.0

	# Apply rotation around Z axis
	var radians = deg_to_rad(rotation_step)
	layer.node.rotate_object_local(Vector3(0, 0, 1), radians)

func raise_layer_order(layer: PlacedLayer):
	"""Increase layer's z-order (bring forward)"""
	if not layer or not layer.node:
		return

	layer.order += 1
	layer.node.render_priority = layer.order

func lower_layer_order(layer: PlacedLayer):
	"""Decrease layer's z-order (send backward)"""
	if not layer or not layer.node:
		return

	layer.order -= 1
	layer.node.render_priority = layer.order

func delete_selected_layer():
	"""Delete the currently selected layer"""
	if not selected_layer:
		print("No layer selected to delete")
		return

	# Remove from scene
	if selected_layer.node:
		selected_layer.node.queue_free()

	# Remove from array
	placed_layers.erase(selected_layer)

	print("Deleted layer: %s" % selected_layer.id)
	selected_layer = null

func select_layer_by_index(index: int):
	"""Select a placed layer by its index in the array"""
	if index >= 0 and index < placed_layers.size():
		selected_layer = placed_layers[index]
	else:
		selected_layer = null

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

# Mode management
func set_input_enabled(enabled: bool):
	"""Enable or disable input processing for this painting system"""
	input_enabled = enabled
