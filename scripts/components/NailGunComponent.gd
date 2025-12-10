extends WeaponComponent
class_name NailGunComponent

## Nailgun weapon component - shoots nails that stick into walls
## Extends WeaponComponent but uses instant raycast instead of physics projectiles
## Nails reject floor surfaces and stick perpendicular to walls

# --- EXPORTED VARIABLES ---
@export_group("Nailgun Settings")
@export var nail_scene: PackedScene  ## WallNail.tscn scene
@export var max_nail_range: float = 20.0  ## Maximum distance for placing nails

# --- GODOT METHODS ---

func _ready() -> void:
	super._ready()
	# Override bullet_scene to use nail_scene
	bullet_scene = nail_scene

# --- OVERRIDDEN METHODS ---

func _spawn_bullet() -> void:
	"""Override to spawn nail at raycast hit point instead of physics bullet"""
	if not nail_scene:
		push_warning("NailGunComponent: No nail scene!")
		return

	# Get camera for aiming direction
	var camera = player_ref.get_camera()
	if not camera:
		push_warning("NailGunComponent: No camera!")
		return

	# === STEP 1: Raycast from camera to find wall hit ===
	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z

	# Do raycast from camera forward
	var space_state = get_world_3d().direct_space_state
	var ray_query = PhysicsRayQueryParameters3D.create(
		camera_pos,
		camera_pos + camera_forward * max_nail_range
	)
	# Don't hit the gun itself or player
	ray_query.exclude = [parent_object]
	ray_query.collision_mask = 2  # Only Static World layer

	var raycast_result = space_state.intersect_ray(ray_query)

	if not raycast_result:
		print("NailGun: No surface hit")
		return  # No hit, no nail

	# === STEP 2: Validate surface (reject floors) ===
	var surface_normal = raycast_result.normal
	var hit_position = raycast_result.position

	# Check if surface is floor (normal pointing up)
	# If dot product > 0.7, it's too horizontal (floor)
	var up_alignment = surface_normal.dot(Vector3.UP)
	if up_alignment > 0.7:
		print("NailGun: Cannot place nail on floor! (alignment: ", up_alignment, ")")
		return

	# === STEP 3: Calculate nail rotation (perpendicular to wall) ===
	var nail_rotation = _calculate_nail_rotation(surface_normal)

	# === STEP 4: Spawn nail at hit point ===
	var nail = nail_scene.instantiate()

	# Add to world first
	get_tree().root.add_child(nail)

	# Set position slightly into wall to avoid floating
	nail.global_position = hit_position + surface_normal * 0.01

	# Set rotation to stick perpendicular to surface
	nail.global_rotation = nail_rotation

	print("=== NAIL PLACED ===")
	print("  Position: ", nail.global_position)
	print("  Surface normal: ", surface_normal)
	print("  Up alignment: ", up_alignment)
	print("  Hit object: ", raycast_result.collider.name if raycast_result.has("collider") else "unknown")

func _calculate_nail_rotation(surface_normal: Vector3) -> Vector3:
	"""Calculate rotation to make nail stick perpendicular to surface"""
	# Nail model points forward along -Z axis
	# We want it to point along surface_normal (outward from wall)

	# Create a basis where Z points along surface normal
	var up = Vector3.UP

	# Handle edge case: surface is perfectly vertical (normal perpendicular to up)
	if abs(surface_normal.dot(up)) > 0.99:
		up = Vector3.RIGHT

	# Build orthonormal basis
	var right = surface_normal.cross(up).normalized()
	up = right.cross(surface_normal).normalized()

	# Basis: right=X, up=Y, -surface_normal=Z (nail points OUT from wall)
	var basis = Basis(right, up, -surface_normal)

	return basis.get_euler()
