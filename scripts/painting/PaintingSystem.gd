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

	# HTML5 debugging
	if OS.has_feature("web"):
		print("Running in HTML5/WebGL mode")
		print("Sticker library loaded:")
		for i in range(min(3, sticker_library.size())):
			var sticker = sticker_library[i]
			print("  [%d] %s - Texture: %s (%s)" % [
				i,
				sticker.id,
				"valid" if sticker.texture else "null",
				str(sticker.texture.get_size()) if sticker.texture else "n/a"
			])

func _load_sticker_library():
	"""Load all sticker textures from the sprites/painting layers folder"""
	var folder_path = "res://sprites/painting layers/"
	var file_names: Array[String] = []

	# HTML5/WebGL builds can't scan directories dynamically
	# Use a predefined list of sticker files
	if OS.has_feature("web"):
		print("HTML5: Using predefined sticker list")
		file_names = [
			"1.png", "2.png", "3.png", "4.png", "5.png",
			"6.png", "7.png", "8.png", "9.png", "10.png"
		]
	else:
		# Desktop builds: scan directory dynamically
		var dir = DirAccess.open(folder_path)

		if not dir:
			push_error("Failed to open sticker folder: %s" % folder_path)
			return

		# Get all PNG files in the folder
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
	"""Handle mouse motion while dragging a sticker (world-space)"""
	var raycast_result = _raycast_from_mouse()

	if raycast_result and selected_layer and selected_layer.node:
		var hit_position = raycast_result.position
		var hit_normal = raycast_result.normal

		# Calculate z-offset to stay in front of surface
		var z_offset = 0.001 + (selected_layer.order * 0.0001)

		# Use world-space positioning
		selected_layer.node.global_position = hit_position + (hit_normal * z_offset)

func _raycast_from_mouse() -> Dictionary:
	"""Perform raycast from camera through mouse position"""
	if not camera:
		return {}

	# Use camera's viewport to ensure correct mouse coordinates (fixes HTML5 scaling issues)
	var viewport = camera.get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * raycast_distance

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	return result

func _get_layer_at_position(world_position: Vector3) -> PlacedLayer:
	"""Find if there's a placed layer near the clicked position (world-space)"""
	var min_distance = 0.5  # Tolerance for click detection in world units
	var closest_layer: PlacedLayer = null
	var closest_dist = min_distance

	# Check in reverse order (top layers first - higher z-order)
	var reversed_layers = placed_layers.duplicate()
	reversed_layers.reverse()

	for layer in reversed_layers:
		if layer.node:
			# Compare in world space (3D distance)
			var dist = layer.node.global_position.distance_to(world_position)

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
	sprite.centered = true  # Center the sprite at its origin point
	sprite.top_level = true  # Ignore parent transform (use world-space positioning)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.shaded = false  # Unshaded material
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Use LINEAR filter instead of LINEAR_WITH_MIPMAPS for HTML5/WebGL compatibility
	# Mipmaps require power-of-2 textures which may not always be available
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.no_depth_test = false
	# Note: render_priority doesn't work reliably in WebGL, using z-offset instead

	# Calculate pixel size based on texture dimensions and canvas size
	# Goal: Make stickers fit proportionally on the canvas
	var texture_size = definition.texture.get_size()
	var aspect_ratio = texture_size.x / texture_size.y

	# Base pixel size to fit canvas (3x2 wall)
	# This makes the sticker take up roughly 1/4 of the canvas by default
	sprite.pixel_size = sticker_scale / max(texture_size.x, texture_size.y)

	# Add to canvas_root for organization (but use world-space positioning)
	canvas_root.add_child(sprite)

	# Debug logging for HTML5 troubleshooting
	if OS.has_feature("web"):
		print("Sprite3D created (HTML5):")
		print("  ID: %s" % definition.id)
		print("  Texture: %s" % ("valid" if sprite.texture else "null"))
		print("  Texture size: %s" % str(texture_size))
		print("  Pixel size: %.6f" % sprite.pixel_size)
		print("  Order: %d" % next_order)

	# Offset slightly in front of wall to avoid z-fighting
	# Use z-offset stacking for layer ordering (WebGL-compatible alternative to render_priority)
	var z_offset = 0.001 + (next_order * 0.0001)  # Each layer gets progressively more offset
	var final_world_position = world_position + (normal * z_offset)

	# Use world-space positioning (enables multi-surface painting)
	# PaintingRoot can be positioned anywhere - stickers use global coordinates
	sprite.global_position = final_world_position

	# Align sprite to face away from wall (opposite of normal)
	# The sprite should face outward (toward camera)
	var look_target = world_position - normal
	sprite.look_at(look_target, Vector3.UP)

	# Debug: Verify sprite visibility in HTML5
	if OS.has_feature("web"):
		print("  Position: %s" % str(sprite.global_position))
		print("  Visible: %s" % sprite.visible)
		print("  In tree: %s" % sprite.is_inside_tree())
		print("  Material: %s" % ("valid" if sprite.get_active_material(0) else "null"))

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
