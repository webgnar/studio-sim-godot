extends Node

## Manages painting conversion system - converts mission painting to carryable object
## Tracks session counter for paintings created

signal painting_created(painting_number: int)

var paintings_created: int = 0

# Preload scenes
var carryable_painting_scene = preload("res://scenes/CarryablePainting.tscn")
var painting_root_2d_scene = preload("res://scenes/PaintingRoot2D.tscn")

# Sound effect
@onready var spawn_sound: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	# Setup audio player
	add_child(spawn_sound)
	spawn_sound.stream = load("res://sounds/picotron/release2.ogg")
	spawn_sound.volume_db = 0.0
	spawn_sound.bus = "SFX"

func replace_painting_with_carryable(world: Node3D) -> void:
	"""Convert current mission painting to carryable object and spawn new blank painting"""
	var old_painting_root = PaintingModeManager.painting_root_2d
	var old_painting_system = PaintingModeManager.painting_system_2d

	if not old_painting_root or not old_painting_system:
		push_error("PaintingSpawner: No painting system found!")
		return

	# Bake texture from current painting
	var baked_texture = await _bake_painting_texture(old_painting_system)

	# Generate unique painting ID and save texture to disk
	var painting_id = "world_painting_%d_%d" % [Time.get_ticks_msec(), paintings_created]
	var texture_path = _save_painting_texture(baked_texture, painting_id)

	# Store transform
	var wall_position = old_painting_root.global_position
	var wall_rotation = old_painting_root.global_rotation

	# Spawn carryable painting with frozen texture
	var carryable = carryable_painting_scene.instantiate()

	# Set metadata BEFORE adding to tree (so _ready can register)
	carryable.painting_id = painting_id
	carryable.texture_path = texture_path

	world.add_child(carryable)

	# Use spawn marker if available, otherwise use wall position
	var spawn_marker = old_painting_root.get_node_or_null("SpawnMarker")
	var spawn_position = spawn_marker.global_position if spawn_marker else wall_position
	var spawn_rotation = spawn_marker.global_rotation if spawn_marker else wall_rotation

	# Set transform AFTER adding to tree
	carryable.global_position = spawn_position
	carryable.global_rotation = spawn_rotation

	# Apply texture
	var mesh_instance = carryable.get_node("MeshInstance3D")
	var material = mesh_instance.get_surface_override_material(0)
	if not material:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		# Duplicate material to create unique instance (prevents sharing across all paintings)
		material = material.duplicate()

	mesh_instance.set_surface_override_material(0, material)
	material.albedo_texture = baked_texture

	# Add small velocity to push away from wall (use spawn marker's forward direction if available)
	var push_direction = spawn_marker.global_transform.basis.x if spawn_marker else old_painting_root.global_transform.basis.x
	carryable.linear_velocity = push_direction * 0.5

	# Remove old painting
	old_painting_root.queue_free()

	# Spawn new blank painting
	var new_painting = painting_root_2d_scene.instantiate()
	world.add_child(new_painting)
	# Set transform AFTER adding to tree
	new_painting.global_position = wall_position
	new_painting.global_rotation = wall_rotation

	# Re-register with PaintingModeManager
	var new_system = new_painting.get_node("CanvasViewport/CanvasRoot")
	PaintingModeManager.register_2d_system(new_system, new_painting)

	# Sync new 2D system to match 3D system's current selection
	if PaintingModeManager.painting_system_3d:
		var current_index = PaintingModeManager.painting_system_3d.selected_sticker_index
		PaintingModeManager.sync_sticker_selection(current_index)

	# Reconnect PaintingUI to new system
	_reconnect_painting_ui(new_system)

	# Increment counter
	paintings_created += 1
	painting_created.emit(paintings_created)

	# Play spawn sound
	if spawn_sound:
		spawn_sound.play()

func _bake_painting_texture(painting_system: PaintingSystem2D) -> ImageTexture:
	"""Capture viewport texture and freeze it as static ImageTexture"""
	# Temporarily remove preview sprite from tree to prevent it from being re-shown
	var preview_sprite = painting_system.preview_sprite
	var preview_parent = preview_sprite.get_parent() if preview_sprite else null

	if preview_sprite and preview_parent:
		preview_parent.remove_child(preview_sprite)

	# Wait for viewport to render without the preview sprite
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw  # Extra frame to be safe

	# Capture viewport texture
	var viewport_texture = painting_system.canvas_viewport.get_texture()
	var image = viewport_texture.get_image()

	# Re-add preview sprite to tree
	if preview_sprite and preview_parent:
		preview_parent.add_child(preview_sprite)

	# Don't rotate - keep original orientation
	# (Note: save_painting_image rotates 90° clockwise, but we don't need that here)

	# Create static ImageTexture
	var static_texture = ImageTexture.create_from_image(image)

	return static_texture

func _reconnect_painting_ui(new_system: PaintingSystem2D):
	"""Reconnect PaintingUI to the new painting system"""
	# Find PaintingUI in scene tree
	var painting_ui = _find_painting_ui(get_tree().root)
	if not painting_ui:
		return

	# Disconnect from old system if it exists and is still valid
	var old_system = painting_ui.active_system
	if old_system and is_instance_valid(old_system):
		if old_system.layer_equipped.is_connected(painting_ui._on_layer_equipped):
			old_system.layer_equipped.disconnect(painting_ui._on_layer_equipped)

	# Update active system reference
	painting_ui.active_system = new_system
	painting_ui.painting_system_2d = new_system

	# Reconnect signal
	new_system.layer_equipped.connect(painting_ui._on_layer_equipped)

	# Update carousel visuals to reflect current selection (no need to rebuild)
	painting_ui._update_carousel_position(true)

func _find_painting_ui(node: Node) -> PaintingUI:
	"""Recursively find PaintingUI in scene tree"""
	if node is PaintingUI:
		return node

	for child in node.get_children():
		var result = _find_painting_ui(child)
		if result:
			return result

	return null

func _save_painting_texture(baked_texture: ImageTexture, painting_id: String) -> String:
	"""Save baked painting texture to disk and return file path"""
	# Ensure world_paintings directory exists
	WorldStateManager._ensure_directories()

	# Generate filename from painting_id
	var filename = painting_id + ".png"
	var full_path = "user://world_paintings/" + filename

	# Save texture Image to PNG
	var image = baked_texture.get_image()
	var error = image.save_png(full_path)

	if error != OK:
		push_error("Failed to save painting texture: " + str(error))
		return ""

	return full_path

func _spawn_carryable_painting(texture: ImageTexture, pos: Vector3, rot: Vector3) -> RigidBody3D:
	"""Create carryable painting instance with baked texture"""
	var carryable = carryable_painting_scene.instantiate()
	carryable.global_position = pos
	carryable.global_rotation = rot

	# Apply baked texture to mesh material
	var mesh_instance = carryable.get_node("MeshInstance3D")
	var material = mesh_instance.get_surface_override_material(0)

	if not material:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		# Duplicate material to create unique instance (prevents sharing across all paintings)
		material = material.duplicate()

	mesh_instance.set_surface_override_material(0, material)
	material.albedo_texture = texture

	# Add small velocity to push away from wall (prevents clipping)
	carryable.linear_velocity = Vector3(0, 0, -0.5)

	return carryable

func _spawn_blank_painting(pos: Vector3, rot: Vector3) -> Node3D:
	"""Create new blank mission-capable painting"""
	var painting = painting_root_2d_scene.instantiate()
	painting.global_position = pos
	painting.global_rotation = rot
	return painting
