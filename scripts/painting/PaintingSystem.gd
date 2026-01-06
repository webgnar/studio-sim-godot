extends Node3D
class_name PaintingSystem3D

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
var next_order: int = 0  # Next available order value (DEPRECATED - use surface_order_counters)

# Surface-based order tracking (NEW)
var surface_order_counters: Dictionary = {}  # surface_key -> int (next order for that surface)

# Performance optimizations (NEW)
var spatial_hash: Dictionary = {}  # grid_key -> Array[PlacedLayer] (fast sticker lookup)
var material_cache: Dictionary = {}  # texture_path -> StandardMaterial3D (shared materials)
const GRID_SIZE = 0.5  # 50cm grid cells for spatial hashing

# Input settings
@export var raycast_distance: float = 10.0
@export var sticker_scale: float = 1  # Scale stickers to fit canvas better

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

	# Platform builds (Windows, macOS, Linux, Steam Deck) can't scan res:// directories dynamically
	# Use a predefined list for all exported builds to ensure reliability across platforms
	if not OS.has_feature("editor"):
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
		# Editor only: scan directory dynamically for development convenience
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
			if DebugLogger and not OS.has_feature("editor"):
				DebugLogger.write_log("[PaintingSystem3D] Failed to load sticker: %s" % path)

	if DebugLogger and not OS.has_feature("editor"):
		DebugLogger.write_log("[PaintingSystem3D] Loaded %d stickers into library" % sticker_library.size())

func _generate_surface_key(collider: Node, hit_position: Vector3, normal: Vector3) -> String:
	"""Generate a unique key for a surface based on collider, position, and normal"""
	# Combine collider ID with quantized position and normal to identify unique surfaces
	# This handles cases where multiple walls are part of the same collider
	var collider_id = str(collider.get_instance_id())

	# Quantize position to 1m grid to group nearby hits on the same plane
	var pos_key = Vector3(
		snapped(hit_position.x, 1.0),
		snapped(hit_position.y, 1.0),
		snapped(hit_position.z, 1.0)
	)

	# Quantize normal to 0.1 precision to group similar facing directions
	# This identifies which wall face we're on
	var norm_key = Vector3(
		snapped(normal.x, 0.1),
		snapped(normal.y, 0.1),
		snapped(normal.z, 0.1)
	).normalized()

	return "%s_%.1f_%.1f_%.1f_%.2f_%.2f_%.2f" % [
		collider_id,
		pos_key.x, pos_key.y, pos_key.z,
		norm_key.x, norm_key.y, norm_key.z
	]

func _get_next_order_for_surface(surface_key: String) -> int:
	"""Get the next available order value for a specific surface"""
	if not surface_order_counters.has(surface_key):
		surface_order_counters[surface_key] = 0

	var order = surface_order_counters[surface_key]
	surface_order_counters[surface_key] += 1
	return order

func _get_grid_key(world_pos: Vector3) -> Vector3i:
	"""Convert world position to spatial hash grid key"""
	return Vector3i(
		int(world_pos.x / GRID_SIZE),
		int(world_pos.y / GRID_SIZE),
		int(world_pos.z / GRID_SIZE)
	)

func _add_to_spatial_hash(layer: PlacedLayer):
	"""Add a placed layer to the spatial hash for fast lookup"""
	var key = _get_grid_key(layer.node.global_position)
	if not spatial_hash.has(key):
		spatial_hash[key] = []
	spatial_hash[key].append(layer)

func _get_or_create_material(texture: Texture2D, order: int = 0) -> StandardMaterial3D:
	"""Get or create a material for a texture with specific render priority"""
	# Can't share materials if they have different render priorities
	# So we create unique materials per order
	var material_key = texture.resource_path + "_" + str(order)
	if material_cache.has(material_key):
		return material_cache[material_key]

	# Create new material for this texture + order combination
	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Try to set render_priority (may not work in GL Compatibility, but worth trying)
	if "render_priority" in material:
		material.render_priority = order
		print("[DEBUG] Set render_priority to ", order)

	material_cache[material_key] = material
	return material

func _process(delta):
	if not camera or not canvas_root:
		return

	# Sticker cycling now handled by PaintingModeManager

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
	if DebugLogger and not OS.has_feature("editor"):
		DebugLogger.write_log("[PaintingSystem3D] handle_primary_action called")
		DebugLogger.write_log("[PaintingSystem3D] raycast_result has data: %s" % (raycast_result != null and not raycast_result.is_empty()))
		if raycast_result:
			DebugLogger.write_log("[PaintingSystem3D] has position: %s" % raycast_result.has("position"))
			DebugLogger.write_log("[PaintingSystem3D] has normal: %s" % raycast_result.has("normal"))

	if raycast_result and raycast_result.has("position") and raycast_result.has("normal"):
		if DebugLogger and not OS.has_feature("editor"):
			DebugLogger.write_log("[PaintingSystem3D] Calling spawn_sticker")
		spawn_sticker(raycast_result.position, raycast_result.normal, raycast_result)
	else:
		if DebugLogger and not OS.has_feature("editor"):
			DebugLogger.write_log("[PaintingSystem3D] Raycast data incomplete, cannot spawn")

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
	# Use spatial hash to check only nearby stickers (100x faster than checking all)
	var grid_key = _get_grid_key(world_position)
	var candidates = []

	# Check nearby grid cells (3x3x3 = 27 cells max)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var check_key = grid_key + Vector3i(dx, dy, dz)
				if spatial_hash.has(check_key):
					candidates.append_array(spatial_hash[check_key])

	# If no candidates in spatial hash, return null
	if candidates.is_empty():
		return null

	var closest_layer: PlacedLayer = null
	var closest_dist = INF

	# Check candidates in reverse order (top layers first - higher z-order)
	# Sort by order descending to check topmost layers first
	candidates.sort_custom(func(a, b): return a.order > b.order)

	for layer in candidates:
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

func spawn_sticker(world_position: Vector3, normal: Vector3, raycast_result: Dictionary = {}):
	"""Spawn a new sticker at the given world position"""
	if DebugLogger and not OS.has_feature("editor"):
		DebugLogger.write_log("[PaintingSystem3D] spawn_sticker called at position: %s" % world_position)
		DebugLogger.write_log("[PaintingSystem3D] sticker_library size: %d" % sticker_library.size())
		DebugLogger.write_log("[PaintingSystem3D] selected_sticker_index: %d" % selected_sticker_index)
		DebugLogger.write_log("[PaintingSystem3D] canvas_root: %s" % canvas_root)

	if sticker_library.is_empty():
		push_error("No stickers in library!")
		if DebugLogger and not OS.has_feature("editor"):
			DebugLogger.write_log("[PaintingSystem3D] ERROR: No stickers in library!")
		return

	var definition = sticker_library[selected_sticker_index]

	# Generate surface key from raycast collider (NEW)
	var surface_key = ""
	if raycast_result.has("collider") and raycast_result.has("position") and raycast_result.has("normal"):
		surface_key = _generate_surface_key(raycast_result.collider, world_position, normal)
		print("[DEBUG] Raycast hit collider: ", raycast_result.collider.name)
		print("[DEBUG] Surface key: ", surface_key)
	else:
		surface_key = "default"  # Fallback for legacy calls
		print("[DEBUG] No collider in raycast - using default surface_key")

	# Get order for THIS surface (not global) (NEW)
	var surface_order = _get_next_order_for_surface(surface_key)
	print("[DEBUG] Surface order: ", surface_order, " on surface: ", surface_key)

	# Create Sprite3D node
	var sprite = Sprite3D.new()
	sprite.texture = definition.texture
	sprite.centered = true  # Center the sprite at its origin point
	sprite.top_level = true  # Ignore parent transform (use world-space positioning)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.no_depth_test = false

	# Use material with render_priority (per-order materials for proper layering)
	sprite.material_override = _get_or_create_material(definition.texture, surface_order)

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
	# Use surface-relative z-offset for layer ordering (FIXED - 3mm per sticker for oblique angle stability)
	# Smaller spacing prevents flickering while maintaining depth ordering at all angles
	var z_offset = 0.005 + (surface_order * 0.003)  # Each layer gets 3mm offset (better for oblique viewing)
	var final_world_position = world_position + (normal * z_offset)
	print("[DEBUG] Z-offset: ", z_offset, " (base: 0.005 + order ", surface_order, " * 0.003)")
	print("[DEBUG] Hit position: ", world_position, " | Normal: ", normal)
	print("[DEBUG] Final position: ", final_world_position)

	# Use world-space positioning (enables multi-surface painting)
	# PaintingRoot can be positioned anywhere - stickers use global coordinates
	sprite.global_position = final_world_position

	# Align sprite to face away from wall (opposite of normal)
	# The sprite should face outward (toward camera)
	var look_target = world_position - normal

	# Choose an up vector that isn't colinear with the normal
	# If normal is nearly vertical, use FORWARD instead of UP
	var up_vector = Vector3.UP
	if abs(normal.dot(Vector3.UP)) > 0.99:  # Normal is nearly vertical
		up_vector = Vector3.FORWARD

	sprite.look_at(look_target, up_vector)

	# Apply current rotation (rotate around surface normal)
	# Negated to match 2D rotation direction
	var rotation_radians = deg_to_rad(-current_rotation)
	sprite.rotate_object_local(Vector3(0, 0, 1), rotation_radians)

	# Create placed layer data with surface key (NEW)
	var placed = PlacedLayer.new(definition.id, sprite, surface_order, current_scale_multiplier, surface_key)
	placed.rotation_deg = current_rotation  # Store the rotation
	placed_layers.append(placed)
	print("[DEBUG] Created sticker #", placed_layers.size(), " - ID: ", definition.id, " | Order: ", surface_order, " | Surface: ", surface_key)

	# Add to spatial hash for fast lookup (NEW)
	_add_to_spatial_hash(placed)
	print("[DEBUG] Total stickers on this surface: ", surface_order_counters[surface_key])
	print("==========================================")

	if DebugLogger and not OS.has_feature("editor"):
		DebugLogger.write_log("[PaintingSystem3D] Sticker spawned successfully! Total placed: %d" % placed_layers.size())

	# Track sticker placement in Steam
	if SteamManager:
		SteamManager.increment_stat("STAT_STICKERS_PLACED")
		if SteamManager.get_stat("STAT_STICKERS_PLACED") >= 1000:
			SteamManager.unlock_achievement("ACH_PAINTER")

func cycle_sticker(direction: int):
	"""Cycle through available stickers in library (deprecated - use PaintingModeManager)"""
	if sticker_library.is_empty():
		return

	selected_sticker_index = (selected_sticker_index + direction) % sticker_library.size()
	if selected_sticker_index < 0:
		selected_sticker_index = sticker_library.size() - 1

	# Note: Syncing and signal emission now handled by PaintingModeManager
	# This function kept for backward compatibility

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
		# Remove from spatial hash (NEW)
		if last_layer.node:
			var key = _get_grid_key(last_layer.node.global_position)
			if spatial_hash.has(key):
				spatial_hash[key].erase(last_layer)

		# Remove from scene
		if last_layer.node:
			last_layer.node.queue_free()

		# Remove from array
		placed_layers.erase(last_layer)

		# Decrement the counter for THIS surface (NEW - fixed)
		if last_layer.surface_key in surface_order_counters:
			if surface_order_counters[last_layer.surface_key] > 0:
				surface_order_counters[last_layer.surface_key] -= 1

func remove_sticker_at_position(world_position: Vector3):
	"""Remove the sticker at the raycast hit position"""
	var layer_to_remove = _get_layer_at_position(world_position)

	if layer_to_remove:
		# Remove from spatial hash (NEW)
		if layer_to_remove.node:
			var key = _get_grid_key(layer_to_remove.node.global_position)
			if spatial_hash.has(key):
				spatial_hash[key].erase(layer_to_remove)

		# Remove from scene
		if layer_to_remove.node:
			layer_to_remove.node.queue_free()

		# Remove from array
		placed_layers.erase(layer_to_remove)

		print("Removed sticker at position: ", world_position)
	else:
		print("No sticker found at raycast position")

func clear_canvas():
	"""Remove all placed stickers from canvas"""
	for layer in placed_layers:
		if layer.node:
			layer.node.queue_free()
	placed_layers.clear()
	next_order = 0  # Keep for backward compatibility
	surface_order_counters.clear()  # NEW
	spatial_hash.clear()  # NEW
	material_cache.clear()  # NEW

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
