extends Node3D
class_name PaintingSystem

## Core painting system - manages stickers on canvas
## Handles spawning, movement, ordering, rotation of layers

# Signals
@warning_ignore("UNUSED_SIGNAL")
signal layer_equipped(index: int)  # Emitted when Q/E changes the equipped sticker

# Node references (assign in inspector or via code)
@export var canvas_root: Node3D

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

# Sticker placement settings (rotation and scale applied when placing)
var current_rotation: float = 0.0  # Rotation in degrees around surface normal
var current_scale_multiplier: float = 1.0  # Scale multiplier (1.0 = default size)

# Rotation settings
@export var rotation_speed: float = 90.0  # Rotation degrees per second when button held

# Scale settings
@export var scale_speed: float = 0.5  # Scale change per second when button held
@export var min_scale: float = 0.2  # Minimum scale (20% of original)
@export var max_scale: float = 3.0  # Maximum scale (300% of original)

# References
var camera: Camera3D = null

func _ready():
	# Find camera
	camera = get_viewport().get_camera_3d()

	# Load sticker library from folder
	_load_sticker_library()

func _load_sticker_library():
	"""Load all sticker textures from the sprites/painting layers folder"""
	var folder_path = "res://sprites/painting layers/"
	var file_names: Array[String] = []

	# HTML5/WebGL builds can't scan directories dynamically
	# Use a predefined list of sticker files
	if OS.has_feature("web"):
		file_names = [
			"1.png", "2.png", "3.png", "4.png", "5.png",
			"6.png", "7.png", "8.png", "9.png", "10.png",
			"11.png", "12.png", "13.png", "14.png", "15.png",
			"16.png", "17.png", "18.png", "19.png", "20.png",
			"21.png", "22.png", "23.png", "24.png", "25.png",
			"26.png", "27.png", "28.png", "29.png", "30.png",
			"31.png"
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

		# Natural sort (1, 2, 3... 10 instead of 1, 10, 2...)
		file_names.sort_custom(func(a, b):
			var num_a = a.get_basename().to_int()
			var num_b = b.get_basename().to_int()
			return num_a < num_b
		)

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
	if not camera or not canvas_root:
		return

	# Sticker cycling now handled by PaintingModeManager

	# Delete selected sticker
	if Input.is_action_just_pressed("ui_text_delete"):
		delete_selected_layer()

	# If no layer is selected, handle rotation and scaling adjustments for next placement
	if not selected_layer:
		# Handle rotation adjustment (continuous while button held)
		if Input.is_action_pressed("rotate_counter"):
			adjust_rotation(delta, -1)  # Counter-clockwise
		elif Input.is_action_pressed("rotate_clockwise"):
			adjust_rotation(delta, 1)  # Clockwise

		# Handle scale adjustment (continuous while button held)
		if Input.is_action_pressed("scale_sticker_up"):
			adjust_scale(delta, 1)  # Increase scale
		elif Input.is_action_pressed("scale_sticker_down"):
			adjust_scale(delta, -1)  # Decrease scale
	else:
		# If a layer is selected, handle rotation of selected layer (90 degree snapping)
		if Input.is_action_just_pressed("rotate_counter"):
			rotate_layer_90(selected_layer, -1)  # Counter-clockwise
		if Input.is_action_just_pressed("rotate_clockwise"):
			rotate_layer_90(selected_layer, 1)  # Clockwise

		# Handle z-order adjustment
		if Input.is_action_just_pressed("ui_up"):
			raise_layer_order(selected_layer)
		if Input.is_action_just_pressed("ui_down"):
			lower_layer_order(selected_layer)

func adjust_rotation(delta: float, direction: int):
	"""Adjust rotation for next sticker placement"""
	# Rotate smoothly based on delta time
	current_rotation += (direction * rotation_speed * delta)

	# Normalize to 0-360 range
	current_rotation = fmod(current_rotation, 360.0)
	if current_rotation < 0:
		current_rotation += 360.0

func adjust_scale(delta: float, direction: int):
	"""Adjust scale for next sticker placement"""
	# Adjust scale multiplier based on delta time for smooth continuous scaling
	current_scale_multiplier += (direction * scale_speed * delta)

	# Clamp to min/max range
	current_scale_multiplier = clamp(current_scale_multiplier, min_scale, max_scale)

func handle_primary_action(raycast_result: Dictionary):
	"""Called by PaintingModeManager when user clicks to place sticker"""
	if raycast_result and raycast_result.has("position") and raycast_result.has("normal"):
		spawn_sticker(raycast_result.position, raycast_result.normal)

func handle_secondary_action(raycast_result: Dictionary):
	"""Called by PaintingModeManager when user right-clicks to remove sticker"""
	if raycast_result and raycast_result.has("position"):
		remove_sticker_at_position(raycast_result.position)


func _raycast_from_mouse() -> Dictionary:
	"""Perform raycast from camera through mouse position"""
	if not camera:
		return {}

	# Use camera's viewport to ensure correct mouse coordinates (fixes HTML5 scaling issues)
	var viewport = camera.get_viewport()

	# Always raycast from center of screen (controller-first design)
	# This ensures it works regardless of mouse capture state
	var mouse_pos: Vector2 = viewport.get_visible_rect().size / 2.0

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
	var closest_layer: PlacedLayer = null
	var closest_dist = INF

	# Check in reverse order (top layers first - higher z-order)
	var reversed_layers = placed_layers.duplicate()
	reversed_layers.reverse()

	for layer in reversed_layers:
		if layer.node and layer.node.texture:
			# Calculate the actual size of this sticker based on its texture and scale
			var texture_size = layer.node.texture.get_size()
			var max_dimension = max(texture_size.x, texture_size.y)

			# Calculate the world-space size of the sticker
			# pixel_size * texture dimension = world units
			var world_size = layer.node.pixel_size * max_dimension

			# Use half the diagonal as the detection radius (generous hit area)
			# This ensures clicking anywhere on the sticker will detect it
			var detection_radius = world_size * 0.707  # sqrt(2)/2 for diagonal

			# Compare in world space (3D distance)
			var dist = layer.node.global_position.distance_to(world_position)

			if dist < detection_radius and dist < closest_dist:
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
	sprite.no_depth_test = false

	# Create a StandardMaterial3D for Forward+ renderer compatibility
	var material = StandardMaterial3D.new()
	material.albedo_texture = definition.texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Unshaded for consistent appearance
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
	sprite.material_override = material

	# Calculate pixel size based on texture dimensions and canvas size
	# Goal: Make stickers fit proportionally on the canvas
	var texture_size = definition.texture.get_size()
	var _aspect_ratio = texture_size.x / texture_size.y

	# Base pixel size to fit canvas (3x2 wall)
	# This makes the sticker take up roughly 1/4 of the canvas by default
	# Apply current scale multiplier
	var base_pixel_size = sticker_scale / max(texture_size.x, texture_size.y)
	sprite.pixel_size = base_pixel_size * current_scale_multiplier

	# Add to canvas_root for organization (but use world-space positioning)
	canvas_root.add_child(sprite)

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

	# Apply current rotation (rotate around surface normal)
	var rotation_radians = deg_to_rad(current_rotation)
	sprite.rotate_object_local(Vector3(0, 0, 1), rotation_radians)

	# Create placed layer data
	var placed = PlacedLayer.new(definition.id, sprite, next_order, current_scale_multiplier)
	placed.rotation_deg = current_rotation  # Store the rotation
	placed_layers.append(placed)

	next_order += 1

	# Track sticker placement in Steam
	if SteamManager:
		SteamManager.increment_stat("STAT_STICKERS_PLACED")
		if SteamManager.get_stat("STAT_STICKERS_PLACED") >= 1000:
			SteamManager.unlock_achievement("ACH_PAINTER")

	# Don't select the newly placed sticker - keep rotation/scale active for continuous placement
	# User can click on placed stickers later to select them if needed

func cycle_sticker(direction: int):
	"""Cycle through available stickers in library (deprecated - use PaintingModeManager)"""
	if sticker_library.is_empty():
		return

	selected_sticker_index = (selected_sticker_index + direction) % sticker_library.size()
	if selected_sticker_index < 0:
		selected_sticker_index = sticker_library.size() - 1

	# Note: Syncing and signal emission now handled by PaintingModeManager
	# This function kept for backward compatibility

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
		return

	# Remove from scene
	if selected_layer.node:
		selected_layer.node.queue_free()

	# Remove from array
	placed_layers.erase(selected_layer)

	selected_layer = null

func undo_last_sticker():
	"""Remove the most recently placed sticker (LIFO order)"""
	if placed_layers.is_empty():
		return

	# Find the layer with the highest order value (most recently placed)
	var last_layer: PlacedLayer = null
	var max_order = -1

	for layer in placed_layers:
		if layer.order > max_order:
			max_order = layer.order
			last_layer = layer

	if last_layer:
		# Remove from scene
		if last_layer.node:
			last_layer.node.queue_free()

		# Remove from array
		placed_layers.erase(last_layer)

		# Clear selection if this was the selected layer
		if selected_layer == last_layer:
			selected_layer = null

		# Decrement next_order so it can be reused
		if next_order > 0:
			next_order -= 1

func remove_sticker_at_position(world_position: Vector3):
	"""Remove the sticker at the raycast hit position"""
	var layer_to_remove = _get_layer_at_position(world_position)

	if layer_to_remove:
		# Remove from scene
		if layer_to_remove.node:
			layer_to_remove.node.queue_free()

		# Remove from array
		placed_layers.erase(layer_to_remove)

		# Clear selection if this was the selected layer
		if selected_layer == layer_to_remove:
			selected_layer = null

		print("Removed sticker at position: ", world_position)
	else:
		print("No sticker found at raycast position")

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

# Mode management (deprecated - input always enabled now)
func set_input_enabled(_enabled: bool):
	"""Deprecated: Input is now always enabled. Routing handled by PaintingModeManager."""
	pass  # No-op for backward compatibility
