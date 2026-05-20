extends Node2D
class_name PaintingSystem2D

## 2D painting system using SubViewport
## Handles sticker placement with automatic canvas clipping for accurate validation

# Signals
@warning_ignore("UNUSED_SIGNAL")
signal layer_equipped(index: int)  # Emitted when Q/E changes the equipped sticker
signal sticker_placed               # Emitted when a sticker is successfully placed on the canvas

# Node references (assign in inspector)
@export var painting_plane: MeshInstance3D  # The plane mesh displaying the canvas
@export var plane_collision: CollisionObject3D  # StaticBody3D for raycasting
@export var canvas_viewport: SubViewport  # The SubViewport containing this Node2D

# Currently placed layers on canvas
var placed_layers: Array[PlacedLayer2D] = []

# Auto-bake background (flattens live Sprite2D nodes into a single texture for performance)
@export var auto_bake_threshold: int = 150  # 0 = disabled
var _background_sprite: Sprite2D = null

# Current state
var selected_sticker_index: int = 0  # Which sticker is selected from library
var selected_layer: PlacedLayer2D = null  # Currently selected placed layer
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

# Commission tracking: true if this canvas passed a commission validation
var was_commission_validated: bool = false

# Splat effect (pre-allocated, reused each stamp)
var _splat_sprite: Sprite2D = null
var _splat_tween: Tween = null

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

	# Create preview sprite
	_setup_preview_sprite()

	# Find or create background sprite for auto-bake
	_setup_background_sprite()

	# Pre-allocate splat sprite
	_splat_sprite = Sprite2D.new()
	_splat_sprite.visible = false
	_splat_sprite.z_index = 0
	add_child(_splat_sprite)

func _setup_background_sprite():
	var existing = get_node_or_null("BackgroundSprite") as Sprite2D
	if existing:
		_background_sprite = existing
		return
	_background_sprite = Sprite2D.new()
	_background_sprite.name = "BackgroundSprite"
	_background_sprite.centered = false
	_background_sprite.z_index = -1000
	add_child(_background_sprite)
	move_child(_background_sprite, 0)

func _setup_plane_material():
	"""Assign SubViewport texture to the painting plane material"""
	if not painting_plane or not canvas_viewport:
		push_error("painting_plane or canvas_viewport not assigned!")
		return

	var plane_material = painting_plane.get_surface_override_material(0)

	if not plane_material:
		# Create new StandardMaterial3D if none exists
		plane_material = StandardMaterial3D.new()
		plane_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL  # Use shaded mode for proper lighting
		plane_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		painting_plane.set_surface_override_material(0, plane_material)

	# Assign viewport texture to material
	if plane_material is StandardMaterial3D:
		plane_material.albedo_texture = canvas_viewport.get_texture()
		plane_material.albedo_color = Color(1, 1, 1, 1)  # Full opacity for texture (transparency comes from viewport)
	else:
		push_error("Material is not StandardMaterial3D! Type: " + str(plane_material.get_class()))

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
	if not StickerLibrary.sticker_library.is_empty():
		_update_preview_texture()

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


func handle_primary_action(raycast_result: Dictionary):
	"""Called by PaintingModeManager when user clicks on canvas"""
	if DebugLogger and not OS.has_feature("editor"):
		DebugLogger.write_log("[PaintingSystem2D] handle_primary_action called")
		DebugLogger.write_log("[PaintingSystem2D] raycast_result has data: %s" % (raycast_result != null and not raycast_result.is_empty()))
		if raycast_result:
			DebugLogger.write_log("[PaintingSystem2D] has position: %s" % raycast_result.has("position"))
			if raycast_result.has("position"):
				DebugLogger.write_log("[PaintingSystem2D] position value: %s" % raycast_result.position)

	if raycast_result and raycast_result.has("position"):
		if DebugLogger and not OS.has_feature("editor"):
			DebugLogger.write_log("[PaintingSystem2D] Calling spawn_sticker")
		spawn_sticker(raycast_result.position)
	else:
		if DebugLogger and not OS.has_feature("editor"):
			DebugLogger.write_log("[PaintingSystem2D] Raycast data incomplete, cannot spawn")

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
		preview_sprite.z_index = 100
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
	if not preview_sprite or StickerLibrary.sticker_library.is_empty():
		return

	var definition = StickerLibrary.sticker_library[selected_sticker_index]
	preview_sprite.texture = definition.texture

	# Update scale using the new function
	_update_preview_scale()

	# Reset fade timer so cycling keeps the preview visible
	preview_idle_time = 0.0
	preview_target_opacity = preview_base_opacity

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
	if not preview_sprite or StickerLibrary.sticker_library.is_empty():
		return

	var definition = StickerLibrary.sticker_library[selected_sticker_index]
	var texture_size = definition.texture.get_size()

	# Apply base scale calculation with multiplier
	var base_scale = sticker_scale * viewport_size.x / max(texture_size.x, texture_size.y)
	var final_scale = base_scale * preview_scale_multiplier

	preview_sprite.scale = Vector2(final_scale, final_scale)

func _spawn_sticker_debris(sprite: Sprite2D) -> void:
	if _splat_tween:
		_splat_tween.kill()

	_splat_sprite.texture = sprite.texture
	_splat_sprite.position = sprite.position
	_splat_sprite.rotation = sprite.rotation
	_splat_sprite.scale = sprite.scale
	_splat_sprite.modulate = Color(1, 1, 1, 0.5)
	_splat_sprite.visible = true
	move_child(_splat_sprite, sprite.get_index() - 1)

	_splat_tween = create_tween().set_parallel(true)
	_splat_tween.tween_property(_splat_sprite, "scale", sprite.scale * 2.5, 0.3)
	_splat_tween.tween_property(_splat_sprite, "modulate:a", 0.0, 0.3)
	_splat_tween.chain().tween_callback(func(): _splat_sprite.visible = false)


func spawn_sticker(world_position: Vector3):
	"""Spawn a new sticker at the given world position"""
	if DebugLogger and not OS.has_feature("editor"):
		DebugLogger.write_log("[PaintingSystem2D] spawn_sticker called at world position: %s" % world_position)
		DebugLogger.write_log("[PaintingSystem2D] StickerLibrary.sticker_library size: %d" % StickerLibrary.sticker_library.size())
		DebugLogger.write_log("[PaintingSystem2D] selected_sticker_index: %d" % selected_sticker_index)
		DebugLogger.write_log("[PaintingSystem2D] painting_plane: %s" % painting_plane)
		DebugLogger.write_log("[PaintingSystem2D] canvas_viewport: %s" % canvas_viewport)

	if StickerLibrary.sticker_library.is_empty():
		push_error("No stickers in library!")
		if DebugLogger and not OS.has_feature("editor"):
			DebugLogger.write_log("[PaintingSystem2D] ERROR: No stickers in library!")
		return

	var definition = StickerLibrary.sticker_library[selected_sticker_index]

	# Convert world position to viewport coordinates
	var viewport_pos = _world_to_viewport_coords(world_position)

	if DebugLogger and not OS.has_feature("editor"):
		DebugLogger.write_log("[PaintingSystem2D] Converted to viewport coords: %s" % viewport_pos)

	# Create Sprite2D node
	var sprite = Sprite2D.new()
	sprite.texture = definition.texture
	sprite.centered = true
	sprite.position = viewport_pos

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
	var placed = PlacedLayer2D.new(definition.id, sprite)
	placed.rotation_deg = preview_rotation  # Track the rotation that was set in preview
	placed.scale_multiplier = preview_scale_multiplier  # Track the scale multiplier
	placed_layers.append(placed)
	sticker_placed.emit()
	_spawn_sticker_debris(sprite)

	if DebugLogger and not OS.has_feature("editor"):
		DebugLogger.write_log("[PaintingSystem2D] Sticker spawned successfully! Total placed: %d" % placed_layers.size())
		DebugLogger.write_log("[PaintingSystem2D] Sprite position: %s, scale: %s, rotation: %.1f" % [sprite.position, sprite.scale, sprite.rotation_degrees])

	# Track 2D sticker placement in Steam
	if SteamManager:
		SteamManager.increment_stat("STAT_STICKERS_PLACED_2D")
		if SteamManager.get_stat("STAT_STICKERS_PLACED_2D") >= 500:
			SteamManager.unlock_achievement("ACH_PAINTER")

	# Select the newly placed sticker
	selected_layer = placed

	if auto_bake_threshold > 0 and placed_layers.size() >= auto_bake_threshold:
		_bake_to_background()  # fire-and-forget coroutine
	
	# Play random sticker sound (create new player for each sound to allow overlap)
	var sounds = [sticker_sound_1, sticker_sound_2, sticker_sound_3, sticker_sound_4, sticker_sound_5]
	var available_sounds = sounds.filter(func(s): return s != null)
	if AudioManager.painting_sounds_enabled and not available_sounds.is_empty():
		var random_sound = available_sounds[randi() % available_sounds.size()]
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "StickerSound"
		audio_player.stream = random_sound
		audio_player.max_distance = 15.0
		audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		audio_player.bus = "SFX"
		painting_plane.add_child(audio_player)
		audio_player.play()
		# Auto-cleanup when sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())

func _bake_to_background() -> void:
	if not canvas_viewport or not _background_sprite:
		return
	var was_visible = false
	if preview_sprite:
		was_visible = preview_sprite.visible
		preview_sprite.visible = false
	await RenderingServer.frame_post_draw
	var image = canvas_viewport.get_texture().get_image()
	if preview_sprite:
		preview_sprite.visible = was_visible
	if not image:
		return
	_background_sprite.texture = ImageTexture.create_from_image(image)
	_background_sprite.scale = Vector2.ONE
	for layer in placed_layers:
		if layer.node:
			layer.node.queue_free()
	placed_layers.clear()
	selected_layer = null

func cycle_sticker(direction: int):
	"""Cycle through available stickers in library (deprecated - use PaintingModeManager)"""
	if StickerLibrary.sticker_library.is_empty():
		return

	selected_sticker_index = (selected_sticker_index + direction) % StickerLibrary.sticker_library.size()
	if selected_sticker_index < 0:
		selected_sticker_index = StickerLibrary.sticker_library.size() - 1

	# Update preview to show new sticker
	_update_preview_texture()

	# Note: Syncing and signal emission now handled by PaintingModeManager
	# This function kept for backward compatibility

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

	var last_layer = placed_layers.back()
	if last_layer.node:
		last_layer.node.queue_free()
	placed_layers.pop_back()

	if selected_layer == last_layer:
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
	selected_layer = null

# Validation system
func verify_painting(target: PaintingMission) -> ValidationResult:
	"""Check if current canvas matches the target painting using visual similarity"""
	var result = ValidationResult.new()

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
						current_image.rotate_90(CLOCKWISE)

						# Store images for heatmap regeneration
						result.debug_data["current_image"] = current_image.duplicate()
						result.debug_data["reference_image"] = reference_image.duplicate()

						# Get color tolerance based on difficulty
						var color_tolerance = target.get_color_tolerance()
						result.debug_data["color_tolerance"] = color_tolerance

						# Perform pixel-by-pixel comparison
						var visual_result = VisualValidator.compare_images(current_image, reference_image, color_tolerance)
						visual_percentage = visual_result["visual_score"]

						# Generate and store heatmap for visualization
						result.debug_data["heatmap_data"] = _generate_heatmap_data(current_image, reference_image, color_tolerance)
						result.debug_data["total_pixels"] = visual_result["total_pixels"]
						result.debug_data["matching_pixels"] = visual_result["matching_pixels"]

						# Compare color distributions
						var current_hist = VisualValidator.calculate_color_distribution(current_image)
						var reference_hist = VisualValidator.calculate_color_distribution(reference_image)
						color_distribution_percentage = VisualValidator.compare_color_distributions(current_hist, reference_hist)

						# Store histogram data for visualization
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
	result.debug_data["visual_score"] = visual_percentage
	result.debug_data["color_score"] = color_distribution_percentage
	result.debug_data["pass_threshold"] = pass_threshold

	# Set simple score (blends visual and color scores)
	result.set_simple_score(visual_percentage, color_distribution_percentage, pass_threshold)

	# Store final results for visualization
	result.debug_data["blended_score"] = result.match_percentage
	result.debug_data["grade"] = result.get_grade()

	# Add detailed feedback if not passing
	if not result.success:
		result.add_error(tr("Match score: %.1f%% (need %.1f%% to pass)") % [
			result.match_percentage,
			result.pass_threshold
		])
		result.add_error(tr("Breakdown - Precision: %.1f%%, Color Field: %.1f%%") % [
			visual_percentage,
			color_distribution_percentage
		])

	return result

func verify_painting_async(target: PaintingMission, loading_overlay) -> ValidationResult:
	"""Async version of verify_painting() with loading overlay progress updates"""
	var result = ValidationResult.new()

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
						current_image.rotate_90(CLOCKWISE)

						# Store images for heatmap regeneration
						result.debug_data["current_image"] = current_image.duplicate()
						result.debug_data["reference_image"] = reference_image.duplicate()

						# Get color tolerance based on difficulty
						var color_tolerance = target.get_color_tolerance()
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
	result.debug_data["visual_score"] = visual_percentage
	result.debug_data["color_score"] = color_distribution_percentage
	result.debug_data["pass_threshold"] = pass_threshold

	# Set simple score (blends visual and color scores)
	result.set_simple_score(visual_percentage, color_distribution_percentage, pass_threshold)

	# Store final results for visualization
	result.debug_data["blended_score"] = result.match_percentage
	result.debug_data["grade"] = result.get_grade()

	# Add detailed feedback if not passing
	if not result.success:
		result.add_error(tr("Match score: %.1f%% (need %.1f%% to pass)") % [
			result.match_percentage,
			result.pass_threshold
		])
		result.add_error(tr("Breakdown - Precision: %.1f%%, Color Field: %.1f%%") % [
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
		var scale_factor = float(max_dim) / max(width, height)
		current = current.duplicate()
		reference = reference.duplicate()
		current.resize(int(width * scale_factor), int(height * scale_factor), Image.INTERPOLATE_LANCZOS)
		reference.resize(int(width * scale_factor), int(height * scale_factor), Image.INTERPOLATE_LANCZOS)
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
func set_input_enabled(_enabled: bool):
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

	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute("user://mission_paintings")

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

	was_commission_validated = false
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
	if ValidationDebugOverlay and not result.debug_data.is_empty():
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

	# Save analysis images (heatmap, swatches) to disk
	var analysis_paths = _save_analysis_images(mission_id, result, is_new_best)

	# Hide loading overlay
	if ValidationLoadingOverlay:
		ValidationLoadingOverlay.hide_loading()

	# Save mission reference before complete_mission() clears current_mission
	var mission = MissionManager.current_mission

	# Save the result to mission manager with painting paths
	MissionManager.complete_mission(result, latest_path, best_path, analysis_paths)

	if result.success:
		was_commission_validated = true

	# Show results inside the pause menu (Commissions tab)
	if UIManager.pause_menu and UIManager.pause_menu.has_method("show_mission_results"):
		UIManager.pause_menu.show_mission_results(result, mission)
	else:
		push_error("PaintingSystem2D: Could not find PauseMenu to show results!")
		print("Validation result: %s, Score: %.1f%%" % [result.get_grade(), result.match_percentage])

func _save_analysis_images(mission_id: String, result: ValidationResult, is_new_best: bool) -> Dictionary:
	"""Save heatmap and swatch images to disk for later viewing"""
	var paths = {}
	var dir_path = "user://mission_paintings"
	DirAccess.make_dir_recursive_absolute(dir_path)

	var debug = result.debug_data

	# Save heatmap (always latest, also best if new best)
	if debug.has("heatmap_data"):
		var heatmap: Image = debug["heatmap_data"]
		var latest_heatmap_path = "%s/%s_heatmap_latest.png" % [dir_path, mission_id]
		heatmap.save_png(latest_heatmap_path)
		paths["latest_heatmap_path"] = latest_heatmap_path
		if is_new_best:
			var best_heatmap_path = "%s/%s_heatmap_best.png" % [dir_path, mission_id]
			heatmap.save_png(best_heatmap_path)
			paths["best_heatmap_path"] = best_heatmap_path

	# Save player color swatch
	if debug.has("current_histogram"):
		var swatch_texture = HistogramRenderer.create_top_colors_swatch(debug["current_histogram"], Vector2i(60, 300))
		if swatch_texture:
			var swatch_image = swatch_texture.get_image()
			var latest_swatch_path = "%s/%s_player_swatch_latest.png" % [dir_path, mission_id]
			swatch_image.save_png(latest_swatch_path)
			paths["latest_player_swatch_path"] = latest_swatch_path
			if is_new_best:
				var best_swatch_path = "%s/%s_player_swatch_best.png" % [dir_path, mission_id]
				swatch_image.save_png(best_swatch_path)
				paths["best_player_swatch_path"] = best_swatch_path

	# Save reference color swatch
	if debug.has("reference_histogram"):
		var swatch_texture = HistogramRenderer.create_top_colors_swatch(debug["reference_histogram"], Vector2i(60, 300))
		if swatch_texture:
			var swatch_image = swatch_texture.get_image()
			var ref_swatch_path = "%s/%s_ref_swatch.png" % [dir_path, mission_id]
			swatch_image.save_png(ref_swatch_path)
			paths["ref_swatch_path"] = ref_swatch_path

	return paths
