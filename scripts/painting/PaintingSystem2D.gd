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
var input_enabled: bool = true  # Always enabled (routing handled by PaintingModeManager)

# Input settings
@export var raycast_distance: float = 10.0
@export var sticker_scale: float = 0.002  # Scale for 2D stickers (pixel size equivalent)

# Plane dimensions (should match PlaneMesh size)
@export var plane_width: float = 3.0
@export var plane_height: float = 3.0

# References
var camera: Camera3D = null
var viewport_size: Vector2

# Preview sticker (shows where sticker will be placed before clicking)
var preview_sprite: Sprite2D = null
var preview_rotation: float = -90.0  # Rotation in degrees (starts at -90 to match plane orientation)
var preview_scale_multiplier: float = 1.0  # Scale multiplier (1.0 = default size)

# Preview fade-out settings
@export var preview_fade_delay: float = 2.0  # Seconds of idle before fade starts
@export var preview_fade_speed: float = 3.0  # How fast it fades (higher = faster)

# Preview scale settings
@export var scale_speed: float = 0.5  # Scale change per second when button held
@export var min_scale: float = 0.2  # Minimum scale (20% of original)
@export var max_scale: float = 3.0  # Maximum scale (300% of original)

# Preview rotation settings
@export var rotation_speed: float = 90.0  # Rotation degrees per second when button held

# Sticker sound effects
@export var sticker_sound_1: AudioStream
@export var sticker_sound_2: AudioStream
@export var sticker_sound_3: AudioStream
@export var sticker_sound_4: AudioStream
@export var sticker_sound_5: AudioStream

var preview_idle_time: float = 0.0
var preview_last_position: Vector2 = Vector2.ZERO
var preview_target_opacity: float = 0.5
var preview_base_opacity: float = 0.5  # Set by PaintingRoot2D

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
	# _setup_viewport_background()  # Commented out for transparent background

	# Load sticker library from folder
	_load_sticker_library()

	# Create preview sprite
	_setup_preview_sprite()

func _setup_plane_material():
	"""Assign SubViewport texture to the painting plane material"""
	if not painting_plane or not canvas_viewport:
		push_error("painting_plane or canvas_viewport not assigned!")
		return

	var material = painting_plane.get_surface_override_material(0)

	if not material:
		# Create new StandardMaterial3D if none exists
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL  # Use shaded mode for proper lighting
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		painting_plane.set_surface_override_material(0, material)

	# Assign viewport texture to material
	if material is StandardMaterial3D:
		material.albedo_texture = canvas_viewport.get_texture()
		material.albedo_color = Color(1, 1, 1, 1)  # Full opacity for texture (transparency comes from viewport)
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

func _setup_preview_sprite():
	"""Create a semi-transparent preview sprite to show placement before clicking"""
	preview_sprite = Sprite2D.new()
	preview_sprite.centered = true
	preview_sprite.modulate = Color(1, 1, 1, 0.5)  # Semi-transparent
	preview_sprite.visible = false  # Hidden by default

	# Rotate to compensate for horizontal plane orientation (matches actual stickers)
	preview_sprite.rotation_degrees = preview_rotation

	add_child(preview_sprite)

	# Set initial texture if sticker library is loaded
	if not sticker_library.is_empty():
		_update_preview_texture()

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
			definition.unlocked = true
			sticker_library.append(definition)
		else:
			push_error("Failed to load sticker texture: %s" % path)

func _process(delta):
	if not camera:
		return

	# Update preview sprite position based on raycast
	_update_preview_position()

	# Handle preview fade-out
	_update_preview_fade(delta)

	# F8 to submit painting for validation (only when mission is active)
	if Input.is_key_pressed(KEY_F8) and MissionManager and MissionManager.current_mission:
		submit_painting()
		return

	# Sticker cycling now handled by PaintingModeManager

	# Delete selected sticker
	if Input.is_action_just_pressed("ui_text_delete"):
		delete_selected_layer()

	# Handle rotation of preview sprite (continuous while button held)
	if Input.is_action_pressed("rotate_counter"):
		rotate_preview(delta, -1)  # Counter-clockwise
	elif Input.is_action_pressed("rotate_clockwise"):
		rotate_preview(delta, 1)  # Clockwise

	# Handle preview scaling (continuous while button held)
	if Input.is_action_pressed("scale_sticker_up"):
		scale_preview(delta, 1)  # Increase scale
	elif Input.is_action_pressed("scale_sticker_down"):
		scale_preview(delta, -1)  # Decrease scale

	# Handle z-order adjustment
	if selected_layer and Input.is_action_just_pressed("ui_up"):
		raise_layer_order(selected_layer)
	if selected_layer and Input.is_action_just_pressed("ui_down"):
		lower_layer_order(selected_layer)

func handle_primary_action(raycast_result: Dictionary):
	"""Called by PaintingModeManager when user clicks on canvas"""
	if raycast_result and raycast_result.has("position"):
		spawn_sticker(raycast_result.position)

func handle_secondary_action():
	"""Called by PaintingModeManager when user right-clicks"""
	undo_last_sticker()

func _raycast_from_mouse() -> Dictionary:
	"""Perform raycast from camera through mouse position"""
	if not camera or not painting_plane:
		return {}

	# Get mouse position from the painting plane's viewport (not SubViewport)
	var viewport = painting_plane.get_viewport()

	# Always raycast from center of screen (controller-first design)
	# This ensures it works regardless of mouse capture state
	var mouse_pos: Vector2 = viewport.get_visible_rect().size / 2.0

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

	# Allow stickers to be placed partially off-canvas (like 3D system)
	# Removed clamping to enable creative edge placement
	# viewport_pos = viewport_pos.clamp(Vector2.ZERO, viewport_size)

	return viewport_pos

func _update_preview_position():
	"""Update preview sprite position based on raycast from mouse"""
	if not preview_sprite:
		return

	var raycast_result = _raycast_from_mouse()

	if raycast_result:
		# Show preview at raycast position
		var viewport_pos = _world_to_viewport_coords(raycast_result.position)

		# Detect movement - reset fade timer if position changed
		if viewport_pos.distance_to(preview_last_position) > 0.1:  # Small threshold to avoid jitter
			preview_idle_time = 0.0
			preview_target_opacity = preview_base_opacity

		preview_sprite.position = viewport_pos
		preview_last_position = viewport_pos
		preview_sprite.visible = true

		# Set z_index higher than all placed stickers to ensure it renders on top
		preview_sprite.z_index = next_order + 100
	else:
		# Hide preview when not hovering over canvas
		preview_sprite.visible = false
		preview_idle_time = 0.0  # Reset timer when not visible

func _update_preview_fade(delta: float):
	"""Handle fade-out effect for preview sprite when idle"""
	if not preview_sprite or not preview_sprite.visible:
		return

	# Increment idle timer
	preview_idle_time += delta

	# After delay, start fading out
	if preview_idle_time > preview_fade_delay:
		preview_target_opacity = 0.0

	# Smoothly interpolate current opacity toward target
	var current_alpha = preview_sprite.modulate.a
	preview_sprite.modulate.a = lerp(current_alpha, preview_target_opacity, delta * preview_fade_speed)

func _update_preview_texture():
	"""Update the preview sprite's texture to match currently selected sticker"""
	if not preview_sprite or sticker_library.is_empty():
		return

	var definition = sticker_library[selected_sticker_index]
	preview_sprite.texture = definition.texture

	# Update scale using the new function
	_update_preview_scale()

func rotate_preview(delta: float, direction: int):
	"""Rotate the preview sprite continuously while button is held"""
	if not preview_sprite:
		return

	# Rotate smoothly based on delta time
	preview_rotation += (direction * rotation_speed * delta)

	# Normalize to 0-360 range
	preview_rotation = fmod(preview_rotation, 360.0)
	if preview_rotation < 0:
		preview_rotation += 360.0

	# Apply rotation to preview sprite
	preview_sprite.rotation_degrees = preview_rotation

	# Reset fade timer to keep preview visible while rotating
	preview_idle_time = 0.0
	preview_target_opacity = preview_base_opacity

func scale_preview(delta: float, direction: int):
	"""Scale the preview sprite continuously while button is held"""
	if not preview_sprite:
		return

	# Adjust scale multiplier based on delta time for smooth continuous scaling
	preview_scale_multiplier += (direction * scale_speed * delta)

	# Clamp to min/max range
	preview_scale_multiplier = clamp(preview_scale_multiplier, min_scale, max_scale)

	# Update preview sprite scale
	_update_preview_scale()

	# Reset fade timer to keep preview visible while scaling
	preview_idle_time = 0.0
	preview_target_opacity = preview_base_opacity

func _update_preview_scale():
	"""Update preview sprite scale based on current multiplier"""
	if not preview_sprite or sticker_library.is_empty():
		return

	var definition = sticker_library[selected_sticker_index]
	var texture_size = definition.texture.get_size()

	# Apply base scale calculation with multiplier
	var base_scale = sticker_scale * viewport_size.x / max(texture_size.x, texture_size.y)
	var final_scale = base_scale * preview_scale_multiplier

	preview_sprite.scale = Vector2(final_scale, final_scale)

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

	# Scale sticker to fit canvas proportionally with user's scale multiplier
	var texture_size = definition.texture.get_size()
	var base_scale = sticker_scale * viewport_size.x / max(texture_size.x, texture_size.y)
	var final_scale = base_scale * preview_scale_multiplier
	sprite.scale = Vector2(final_scale, final_scale)

	# Apply rotation from preview sprite
	sprite.rotation_degrees = preview_rotation

	# Add to canvas (this Node2D is inside the SubViewport)
	add_child(sprite)

	# Create placed layer data
	var placed = PlacedLayer2D.new(definition.id, sprite, next_order)
	placed.rotation_deg = preview_rotation  # Track the rotation that was set in preview
	placed.scale_multiplier = preview_scale_multiplier  # Track the scale multiplier
	placed_layers.append(placed)

	next_order += 1

	# Select the newly placed sticker
	selected_layer = placed
	
	# Play random sticker sound (create new player for each sound to allow overlap)
	var sounds = [sticker_sound_1, sticker_sound_2, sticker_sound_3, sticker_sound_4, sticker_sound_5]
	var available_sounds = sounds.filter(func(s): return s != null)
	if not available_sounds.is_empty():
		var random_sound = available_sounds[randi() % available_sounds.size()]
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "StickerSound"
		audio_player.stream = random_sound
		audio_player.max_distance = 15.0
		audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		audio_player.bus = "SFX"
		add_child(audio_player)
		audio_player.play()
		# Auto-cleanup when sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())

func cycle_sticker(direction: int):
	"""Cycle through available stickers in library (deprecated - use PaintingModeManager)"""
	if sticker_library.is_empty():
		return

	selected_sticker_index = (selected_sticker_index + direction) % sticker_library.size()
	if selected_sticker_index < 0:
		selected_sticker_index = sticker_library.size() - 1

	# Update preview to show new sticker
	_update_preview_texture()

	# Note: Syncing and signal emission now handled by PaintingModeManager
	# This function kept for backward compatibility

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
	var last_layer: PlacedLayer2D = null
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

# Validation system
func verify_painting(target: PaintingMission) -> ValidationResult:
	"""Check if current canvas matches the target painting using visual similarity"""
	var result = ValidationResult.new()

	# Always enable debug data capture for heatmap and histogram visualizations
	result.debug_enabled = true

	# Perform visual validation using pixel comparison and color distribution
	var visual_percentage: float = 0.0
	var color_distribution_percentage: float = 0.0

	# Get reference image and compare with current canvas
	if target.reference_image_path and target.reference_image_path != "":
		# Capture current viewport as image
		if canvas_viewport:
			var current_texture = canvas_viewport.get_texture()
			if current_texture:
				var current_image = current_texture.get_image()

				# Load reference image
				var reference_texture = load(target.reference_image_path) as Texture2D
				if reference_texture:
					var reference_image = reference_texture.get_image()

					# Decompress images if needed (required for get_pixel() calls)
					if current_image and current_image.is_compressed():
						current_image.decompress()
					if reference_image and reference_image.is_compressed():
						reference_image.decompress()

					if current_image and reference_image:
						# Rotate current image to match reference orientation
						# (Reference images are rotated 90° clockwise during capture)
						current_image.rotate_90(CLOCKWISE)

						# Store images for heatmap regeneration
						if result.debug_enabled:
							result.debug_data["current_image"] = current_image.duplicate()
							result.debug_data["reference_image"] = reference_image.duplicate()

						# Get color tolerance based on difficulty
						var color_tolerance = target.get_color_tolerance()

						# Store color tolerance
						if result.debug_enabled:
							result.debug_data["color_tolerance"] = color_tolerance

						# Perform pixel-by-pixel comparison
						var visual_result = VisualValidator.compare_images(current_image, reference_image, color_tolerance)
						visual_percentage = visual_result["visual_score"]

						# Generate and store heatmap for visualization
						if result.debug_enabled:
							result.debug_data["heatmap_data"] = _generate_heatmap_data(current_image, reference_image, color_tolerance)
							result.debug_data["total_pixels"] = visual_result["total_pixels"]
							result.debug_data["matching_pixels"] = visual_result["matching_pixels"]

						# Compare color distributions
						var current_hist = VisualValidator.calculate_color_distribution(current_image)
						var reference_hist = VisualValidator.calculate_color_distribution(reference_image)
						color_distribution_percentage = VisualValidator.compare_color_distributions(current_hist, reference_hist)

						# Store histogram data for visualization
						if result.debug_enabled:
							result.debug_data["current_histogram"] = current_hist
							result.debug_data["reference_histogram"] = reference_hist
					else:
						push_warning("PaintingSystem2D: Could not extract images for visual validation")
				else:
					push_warning("PaintingSystem2D: Could not load reference image from '%s'" % target.reference_image_path)
	else:
		push_warning("PaintingSystem2D: No reference image path set, validation may not work correctly")

	# Get pass threshold based on difficulty
	var pass_threshold = target.get_pass_threshold()

	# Store all scores for visualization
	if result.debug_enabled:
		result.debug_data["visual_score"] = visual_percentage
		result.debug_data["color_score"] = color_distribution_percentage
		result.debug_data["pass_threshold"] = pass_threshold

	# Set simple score (blends visual and color scores)
	result.set_simple_score(visual_percentage, color_distribution_percentage, pass_threshold)

	# Store final results for visualization
	if result.debug_enabled:
		result.debug_data["blended_score"] = result.match_percentage
		result.debug_data["grade"] = result.get_grade()

	# Add detailed feedback if not passing
	if not result.success:
		result.add_error("Match score: %.1f%% (need %.1f%% to pass)" % [
			result.match_percentage,
			result.pass_threshold
		])
		result.add_error("Breakdown - Precision: %.1f%%, Color Field: %.1f%%" % [
			visual_percentage,
			color_distribution_percentage
		])

	return result

func verify_painting_async(target: PaintingMission, loading_overlay) -> ValidationResult:
	"""Async version of verify_painting() with loading overlay progress updates"""
	var result = ValidationResult.new()

	# Always enable debug data capture for heatmap and histogram visualizations
	result.debug_enabled = true

	# Perform visual validation using pixel comparison and color distribution
	var visual_percentage: float = 0.0
	var color_distribution_percentage: float = 0.0

	# Get reference image and compare with current canvas
	if target.reference_image_path and target.reference_image_path != "":
		# Capture current viewport as image
		if canvas_viewport:
			var current_texture = canvas_viewport.get_texture()
			if current_texture:
				var current_image = current_texture.get_image()

				# Load reference image
				var reference_texture = load(target.reference_image_path) as Texture2D
				if reference_texture:
					var reference_image = reference_texture.get_image()

					# Decompress images if needed (required for get_pixel() calls)
					if current_image and current_image.is_compressed():
						current_image.decompress()
					if reference_image and reference_image.is_compressed():
						reference_image.decompress()

					if current_image and reference_image:
						# Rotate current image to match reference orientation
						# (Reference images are rotated 90° clockwise during capture)
						current_image.rotate_90(CLOCKWISE)

						# Store images for heatmap regeneration
						if result.debug_enabled:
							result.debug_data["current_image"] = current_image.duplicate()
							result.debug_data["reference_image"] = reference_image.duplicate()

						# Get color tolerance based on difficulty
						var color_tolerance = target.get_color_tolerance()

						# Store color tolerance
						if result.debug_enabled:
							result.debug_data["color_tolerance"] = color_tolerance

						# Step 1: Perform pixel-by-pixel comparison
						if loading_overlay:
							loading_overlay.update_step(2, 5, "Comparing pixels...")
							await get_tree().process_frame

						var visual_result = VisualValidator.compare_images(current_image, reference_image, color_tolerance)
						visual_percentage = visual_result["visual_score"]

						# Step 2: Generate and store heatmap for visualization
						if loading_overlay:
							loading_overlay.update_step(3, 5, "Generating heatmap...")
							await get_tree().process_frame

						if result.debug_enabled:
							result.debug_data["heatmap_data"] = _generate_heatmap_data(current_image, reference_image, color_tolerance)
							result.debug_data["total_pixels"] = visual_result["total_pixels"]
							result.debug_data["matching_pixels"] = visual_result["matching_pixels"]

						# Step 3: Compare color distributions
						if loading_overlay:
							loading_overlay.update_step(4, 5, "Analyzing colors...")
							await get_tree().process_frame

						var current_hist = VisualValidator.calculate_color_distribution(current_image)
						var reference_hist = VisualValidator.calculate_color_distribution(reference_image)
						color_distribution_percentage = VisualValidator.compare_color_distributions(current_hist, reference_hist)

						# Store histogram data for visualization
						if result.debug_enabled:
							result.debug_data["current_histogram"] = current_hist
							result.debug_data["reference_histogram"] = reference_hist
					else:
						push_warning("PaintingSystem2D: Could not extract images for visual validation")
				else:
					push_warning("PaintingSystem2D: Could not load reference image from '%s'" % target.reference_image_path)
	else:
		push_warning("PaintingSystem2D: No reference image path set, validation may not work correctly")

	# Get pass threshold based on difficulty
	var pass_threshold = target.get_pass_threshold()

	# Store all scores for visualization
	if result.debug_enabled:
		result.debug_data["visual_score"] = visual_percentage
		result.debug_data["color_score"] = color_distribution_percentage
		result.debug_data["pass_threshold"] = pass_threshold

	# Set simple score (blends visual and color scores)
	result.set_simple_score(visual_percentage, color_distribution_percentage, pass_threshold)

	# Store final results for visualization
	if result.debug_enabled:
		result.debug_data["blended_score"] = result.match_percentage
		result.debug_data["grade"] = result.get_grade()

	# Add detailed feedback if not passing
	if not result.success:
		result.add_error("Match score: %.1f%% (need %.1f%% to pass)" % [
			result.match_percentage,
			result.pass_threshold
		])
		result.add_error("Breakdown - Precision: %.1f%%, Color Field: %.1f%%" % [
			visual_percentage,
			color_distribution_percentage
		])

	return result

func _is_debug_mode_enabled() -> bool:
	"""Check if debug overlay is active"""
	# Check if autoload exists and is visible
	return ValidationDebugOverlay and ValidationDebugOverlay.is_overlay_visible()

func _generate_heatmap_data(current: Image, reference: Image, tolerance: float) -> Image:
	"""
	Generate heatmap showing pixel matching quality
	Green = match (within tolerance)
	Red = no match
	Alpha indicates match quality
	"""
	# Apply multiplier if debug overlay is available
	var adjusted_tolerance = tolerance
	if ValidationDebugOverlay:
		adjusted_tolerance = tolerance * ValidationDebugOverlay.heatmap_tolerance_multiplier

	var width = reference.get_size().x
	var height = reference.get_size().y

	# Optional downsampling for performance
	var max_dim = 512
	if width > max_dim or height > max_dim:
		var scale = float(max_dim) / max(width, height)
		current = current.duplicate()
		reference = reference.duplicate()
		current.resize(int(width * scale), int(height * scale), Image.INTERPOLATE_LANCZOS)
		reference.resize(int(width * scale), int(height * scale), Image.INTERPOLATE_LANCZOS)
		width = current.get_size().x
		height = current.get_size().y

	var heatmap = Image.create(width, height, false, Image.FORMAT_RGBA8)

	for y in range(height):
		for x in range(width):
			var current_color = current.get_pixel(x, y)
			var reference_color = reference.get_pixel(x, y)

			# Skip pixels where reference is transparent (background/outside painting area)
			if reference_color.a < 0.1:
				heatmap.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			# If reference has color but current is transparent, show as bright red (unpainted)
			if current_color.a < 0.1:
				heatmap.set_pixel(x, y, Color(1.0, 0, 0, 1.0))  # Bright red for missing paint
				continue

			# Calculate color distance using public method
			var color_diff = VisualValidator.color_distance(current_color, reference_color)

			if color_diff <= adjusted_tolerance:
				# Bright green for match
				heatmap.set_pixel(x, y, Color(0, 1.0, 0, 1.0))
			else:
				# Bright red for mismatch
				heatmap.set_pixel(x, y, Color(1.0, 0, 0, 1.0))
	return heatmap

# Mode management (deprecated - input always enabled now)
func set_input_enabled(enabled: bool):
	"""Deprecated: Input is now always enabled. Routing handled by PaintingModeManager."""
	pass  # No-op for backward compatibility

func save_painting_image(mission_id: String, is_best: bool) -> String:
	"""Save current painting to disk as PNG (HTML5 compatible)"""
	if not canvas_viewport:
		push_error("PaintingSystem2D: No canvas viewport to capture!")
		return ""

	# Hide preview sprite to avoid capturing it in the image
	var preview_was_visible = false
	if preview_sprite:
		preview_was_visible = preview_sprite.visible
		preview_sprite.visible = false

	# Wait for viewport to render without the preview sprite
	await RenderingServer.frame_post_draw

	# Capture current viewport as image
	var viewport_texture = canvas_viewport.get_texture()
	if not viewport_texture:
		push_error("PaintingSystem2D: Failed to get viewport texture!")
		# Restore preview visibility
		if preview_sprite:
			preview_sprite.visible = preview_was_visible
		return ""

	var image = viewport_texture.get_image()
	if not image:
		push_error("PaintingSystem2D: Failed to get image from texture!")
		# Restore preview visibility
		if preview_sprite:
			preview_sprite.visible = preview_was_visible
		return ""

	# Restore preview sprite visibility
	if preview_sprite:
		preview_sprite.visible = preview_was_visible

	# Rotate to match reference orientation (references are rotated 90° clockwise)
	image.rotate_90(CLOCKWISE)

	# Determine filename (latest or best)
	var filename = "%s_%s.png" % [mission_id, "best" if is_best else "latest"]
	var path = "user://mission_paintings/%s" % filename

	# Save image as PNG
	var error = image.save_png(path)

	if error == OK:
		print("PaintingSystem2D: Saved painting to %s" % path)
		return path
	else:
		push_error("PaintingSystem2D: Failed to save painting image! Error: %d" % error)
		return ""

# Mission system
func start_mission(mission: PaintingMission):
	"""Start a new mission by clearing the canvas and preparing for painting"""
	if not mission:
		push_error("PaintingSystem2D: Cannot start null mission!")
		return

	# Clear the canvas
	clear_canvas()

func submit_painting():
	"""Submit the current painting for validation"""
	if not MissionManager or not MissionManager.current_mission:
		push_error("PaintingSystem2D: No active mission to submit!")
		return

	var mission_id = MissionManager.current_mission.mission_id

	# Show loading overlay
	if ValidationLoadingOverlay:
		ValidationLoadingOverlay.show_loading()
		ValidationLoadingOverlay.update_step(1, 5, "Preparing validation...")
		await get_tree().process_frame

	# Validate the painting with async progress updates
	var result = await verify_painting_async(MissionManager.current_mission, ValidationLoadingOverlay)

	# Update debug overlay if active
	if ValidationDebugOverlay and result.debug_enabled:
		ValidationDebugOverlay.update_display(result)

	# Save paintings to disk (await to ensure preview sprite is hidden during capture)
	if ValidationLoadingOverlay:
		ValidationLoadingOverlay.update_step(5, 5, "Saving painting...")
		await get_tree().process_frame

	var latest_path = await save_painting_image(mission_id, false)  # Always save latest

	# Check if this is a new best score
	var mission_data = MissionManager.get_mission_completion(mission_id)
	var is_new_best = result.match_percentage > mission_data.get("best_score", 0.0)
	var best_path = ""

	if is_new_best:
		best_path = await save_painting_image(mission_id, true)  # Save as best too
		print("PaintingSystem2D: New best score! Saved best painting.")

	# Hide loading overlay
	if ValidationLoadingOverlay:
		ValidationLoadingOverlay.hide_loading()

	# Save the result to mission manager with painting paths
	MissionManager.complete_mission(result, latest_path, best_path)

	# Find and show the validation result UI
	var validation_ui = _find_validation_ui()
	if validation_ui:
		validation_ui.show_results(result, MissionManager.current_mission)
	else:
		push_error("PaintingSystem2D: Could not find ValidationResultUI!")
		print("Validation result: %s, Score: %.1f%%" % [result.get_grade(), result.match_percentage])

func _find_validation_ui() -> ValidationResultUI:
	"""Find the ValidationResultUI in the scene tree"""
	var root = get_tree().root
	return _search_for_validation_ui(root)

func _search_for_validation_ui(node: Node) -> ValidationResultUI:
	"""Recursively search for ValidationResultUI"""
	if node is ValidationResultUI:
		return node

	for child in node.get_children():
		var result = _search_for_validation_ui(child)
		if result:
			return result

	return null
