extends Node2D
class_name PaintingSystem2D

## 2D painting system using SubViewport
## Handles sticker placement with automatic canvas clipping for accurate validation

# Signals
signal layer_equipped(index: int)  # Emitted when Q/E changes the equipped sticker

# Node references (assign in inspector)
@export var painting_plane: MeshInstance3D  # The plane mesh displaying the canvas
@export var plane_collision: CollisionObject3D  # StaticBody3D for raycasting
@export var canvas_viewport: SubViewport  # The SubViewport containing this Node2D

# Sticker library - available stickers to place
var sticker_library: Array[PaintingLayerDefinition] = []

# Currently placed layers on canvas
var placed_layers: Array[PlacedLayer2D] = []

# Current state
var selected_sticker_index: int = 0  # Which sticker is selected from library
var selected_layer: PlacedLayer2D = null  # Currently selected placed layer
var next_order: int = 0  # Next available z-index value
var input_enabled: bool = false  # Starts disabled (3D mode is default)

# Input settings
@export var raycast_distance: float = 10.0
@export var sticker_scale: float = 0.002  # Scale for 2D stickers (pixel size equivalent)

# Plane dimensions (should match PlaneMesh size)
@export var plane_width: float = 3.0
@export var plane_height: float = 2.0

# References
var camera: Camera3D = null
var viewport_size: Vector2

func _ready():
	# Find camera from the painting plane's world (not from SubViewport)
	if painting_plane:
		camera = painting_plane.get_viewport().get_camera_3d()
	else:
		push_error("painting_plane not assigned, cannot find camera!")

	# Get viewport size
	if canvas_viewport:
		viewport_size = canvas_viewport.size
	else:
		push_error("canvas_viewport not assigned!")
		viewport_size = Vector2(1024, 1024)

	# Bind SubViewport texture to plane material
	_setup_plane_material()

	# Add visible background to SubViewport
	_setup_viewport_background()

	# Load sticker library from folder
	_load_sticker_library()

	print("PaintingSystem2D ready. Loaded %d stickers." % sticker_library.size())

func _setup_plane_material():
	"""Assign SubViewport texture to the painting plane material"""
	if not painting_plane or not canvas_viewport:
		push_error("painting_plane or canvas_viewport not assigned!")
		return

	var material = painting_plane.get_surface_override_material(0)

	if not material:
		# Create new StandardMaterial3D if none exists
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		painting_plane.set_surface_override_material(0, material)

	# Assign viewport texture to material
	if material is StandardMaterial3D:
		material.albedo_texture = canvas_viewport.get_texture()
		material.albedo_color = Color(1, 1, 1, 1)  # White background
	else:
		push_error("Material is not StandardMaterial3D! Type: " + str(material.get_class()))

func _setup_viewport_background():
	"""Add a visible background to the SubViewport canvas"""
	var background = ColorRect.new()
	background.color = Color(0.9, 0.9, 0.9, 1.0)  # Light gray background
	background.size = viewport_size
	background.z_index = -1000  # Behind all stickers
	add_child(background)
	move_child(background, 0)  # Make it first child

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
	if not camera or not input_enabled:
		return

	# Cycle stickers with Q/E keys or mouse wheel
	if Input.is_action_just_pressed("cycle_sticker_prev"):
		cycle_sticker(-1)
	if Input.is_action_just_pressed("cycle_sticker_next"):
		cycle_sticker(1)

	# Delete selected sticker
	if Input.is_action_just_pressed("ui_text_delete"):
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
	if not camera or not input_enabled:
		return

	# Left click to place sticker
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var raycast_result = _raycast_from_mouse()
		if raycast_result:
			spawn_sticker(raycast_result.position)

func _raycast_from_mouse() -> Dictionary:
	"""Perform raycast from camera through mouse position"""
	if not camera or not painting_plane:
		return {}

	# Get mouse position from the painting plane's viewport (not SubViewport)
	var mouse_pos = painting_plane.get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * raycast_distance

	var space_state = painting_plane.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	# Verify we hit the painting plane collision
	if result and result.has("collider"):
		if result.collider == plane_collision or result.collider.get_parent() == painting_plane:
			return result

	return {}

func _world_to_viewport_coords(world_pos: Vector3) -> Vector2:
	"""Convert world space hit position to SubViewport pixel coordinates"""
	if not painting_plane:
		return Vector2.ZERO

	# Convert to plane local space
	var local_pos = painting_plane.to_local(world_pos)

	# Map plane space to UV (0 to 1)
	# Plane origin is center, so we need to offset by half dimensions
	var uv = Vector2(
		(local_pos.x / plane_width) + 0.5,
		(local_pos.z / plane_height) + 0.5  # Removed negative - was causing Y inversion
	)

	# Map UV to viewport pixels
	var viewport_pos = uv * viewport_size

	# Clamp to viewport bounds (auto-clip stickers)
	viewport_pos = viewport_pos.clamp(Vector2.ZERO, viewport_size)

	return viewport_pos

func spawn_sticker(world_position: Vector3):
	"""Spawn a new sticker at the given world position"""
	if sticker_library.is_empty():
		push_error("No stickers in library!")
		return

	var definition = sticker_library[selected_sticker_index]

	# Convert world position to viewport coordinates
	var viewport_pos = _world_to_viewport_coords(world_position)

	# Create Sprite2D node
	var sprite = Sprite2D.new()
	sprite.texture = definition.texture
	sprite.centered = true
	sprite.position = viewport_pos
	sprite.z_index = next_order

	# Scale sticker to fit canvas proportionally
	var texture_size = definition.texture.get_size()
	var scale_factor = sticker_scale * viewport_size.x / max(texture_size.x, texture_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)

	# Add to canvas (this Node2D is inside the SubViewport)
	add_child(sprite)

	# Create placed layer data
	var placed = PlacedLayer2D.new(definition.id, sprite, next_order)
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

func rotate_layer_90(layer: PlacedLayer2D, direction: int):
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

	# Apply rotation (Sprite2D uses rotation property directly)
	layer.node.rotation_degrees += rotation_step

func raise_layer_order(layer: PlacedLayer2D):
	"""Increase layer's z-order (bring forward)"""
	if not layer or not layer.node:
		return

	layer.order += 1
	layer.node.z_index = layer.order

func lower_layer_order(layer: PlacedLayer2D):
	"""Decrease layer's z-order (send backward)"""
	if not layer or not layer.node:
		return

	layer.order -= 1
	layer.node.z_index = layer.order

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

# Validation system
func verify_painting(target: PaintingMission) -> ValidationResult:
	"""Check if current canvas matches the target painting with placement-based scoring"""
	var result = ValidationResult.new()

	# Check layer count
	if placed_layers.size() != target.target_stickers.size():
		result.add_error("Wrong number of stickers: expected %d, got %d" % [
			target.target_stickers.size(),
			placed_layers.size()
		])
		result.set_placement_score(0.0, [])
		return result

	if target.target_stickers.is_empty():
		result.add_error("Mission has no target stickers defined")
		result.set_placement_score(0.0, [])
		return result

	# Get tolerance settings from mission difficulty
	var tolerances = target.get_tolerance_settings()
	var position_tolerance = tolerances["position"]
	var rotation_tolerance = tolerances["rotation"]

	# Convert placed layers to PlacedStickerData for comparison
	var player_stickers: Array[PlacedStickerData] = []
	for layer in placed_layers:
		if not layer.node:
			continue

		var sticker_data = PlacedStickerData.new()
		sticker_data.sticker_id = layer.id
		sticker_data.position = layer.node.position
		sticker_data.rotation_deg = layer.rotation_deg
		sticker_data.scale = layer.node.scale.x
		sticker_data.z_order = layer.order

		player_stickers.append(sticker_data)

	# Sort both arrays by z_order for comparison
	var sorted_player = player_stickers.duplicate()
	sorted_player.sort_custom(func(a, b): return a.z_order < b.z_order)

	var sorted_target = target.target_stickers.duplicate()
	sorted_target.sort_custom(func(a, b): return a.z_order < b.z_order)

	# Compare each sticker and calculate individual scores
	var sticker_scores: Array[float] = []
	var total_score: float = 0.0

	for i in range(sorted_target.size()):
		if i >= sorted_player.size():
			sticker_scores.append(0.0)
			continue

		var target_sticker = sorted_target[i]
		var player_sticker = sorted_player[i]

		# Calculate match score for this sticker
		var match_score = player_sticker.matches(target_sticker, position_tolerance, rotation_tolerance)
		sticker_scores.append(match_score)
		total_score += match_score

	# Calculate overall percentage
	var match_percentage = (total_score / float(sorted_target.size())) * 100.0

	# Set the placement score
	result.set_placement_score(match_percentage, sticker_scores)

	# Add detailed feedback if not passing
	if not result.success:
		result.add_error("Match score: %.1f%% (need %.1f%% to pass)" % [
			match_percentage,
			result.pass_threshold
		])

	return result

# Mode management
func set_input_enabled(enabled: bool):
	"""Enable or disable input processing for this painting system"""
	input_enabled = enabled
