extends Node

## Manages painting conversion system - converts mission painting to carryable object
## Tracks session counter for paintings created

signal painting_created(painting_number: int)

var paintings_created: int = 0

# Preload scenes
var carryable_painting_scene = preload("res://scenes/CarryablePainting.tscn")
var painting_root_2d_scene = preload("res://scenes/PaintingRoot2D.tscn")

func replace_painting_with_carryable(world: Node3D) -> void:
	"""Convert current mission painting to carryable object and spawn new blank painting"""
	print("🔴 replace_painting_with_carryable() called!")
	print("🔴 World: " + str(world))

	var old_painting_root = PaintingModeManager.painting_root_2d
	var old_painting_system = PaintingModeManager.painting_system_2d

	print("🔴 Old painting root: " + str(old_painting_root))
	print("🔴 Old painting system: " + str(old_painting_system))

	if not old_painting_root or not old_painting_system:
		push_error("PaintingSpawner: No painting system found!")
		return

	print("🔴 Starting texture bake...")

	# Bake texture from current painting
	var baked_texture = await _bake_painting_texture(old_painting_system)
	print("🔴 Texture baked: " + str(baked_texture))

	# Store transform
	var wall_position = old_painting_root.global_position
	var wall_rotation = old_painting_root.global_rotation
	print("🔴 Wall position: " + str(wall_position))
	print("🔴 Wall rotation: " + str(wall_rotation))

	# Spawn carryable painting with frozen texture
	print("🔴 Spawning carryable painting...")
	var carryable = _spawn_carryable_painting(baked_texture, wall_position, wall_rotation)
	world.add_child(carryable)
	print("🔴 Carryable added to world: " + str(carryable))

	# Remove old painting
	print("🔴 Removing old painting...")
	old_painting_root.queue_free()

	# Spawn new blank painting
	print("🔴 Spawning new blank painting...")
	var new_painting = _spawn_blank_painting(wall_position, wall_rotation)
	world.add_child(new_painting)
	print("🔴 New painting added to world: " + str(new_painting))

	# Re-register with PaintingModeManager
	print("🔴 Re-registering with PaintingModeManager...")
	var new_system = new_painting.get_node("CanvasViewport/CanvasRoot")
	PaintingModeManager.register_2d_system(new_system, new_painting)
	print("🔴 Re-registration complete!")

	# Increment counter
	paintings_created += 1
	print("🔴 Counter incremented to: " + str(paintings_created))
	painting_created.emit(paintings_created)
	print("✅ Painting conversion complete!")

func _bake_painting_texture(painting_system: PaintingSystem2D) -> ImageTexture:
	"""Capture viewport texture and freeze it as static ImageTexture"""
	# Hide preview sprite to avoid capturing it
	var preview_was_visible = painting_system.preview_sprite.visible
	painting_system.preview_sprite.visible = false

	# Wait for render to complete
	await RenderingServer.frame_post_draw

	# Capture viewport texture
	var viewport_texture = painting_system.canvas_viewport.get_texture()
	var image = viewport_texture.get_image()

	# Rotate 90° clockwise to match painting orientation (same as save_painting_image)
	image.rotate_90(CLOCKWISE)

	# Create static ImageTexture
	var static_texture = ImageTexture.create_from_image(image)

	# Restore preview sprite
	painting_system.preview_sprite.visible = preview_was_visible

	return static_texture

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
