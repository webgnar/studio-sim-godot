extends WeaponComponent
class_name NailGunComponent

## Nailgun weapon component - shoots nails that stick into walls
## Extends WeaponComponent but uses instant raycast instead of physics projectiles
## Nails reject floor surfaces and stick perpendicular to walls

# --- EXPORTED VARIABLES ---
@export_group("Nailgun Settings")
@export var nail_scene: PackedScene  ## WallNail.tscn scene
@export var projectile_nail_scene: PackedScene  ## ProjectileNail.tscn scene
@export var max_nail_range: float = 20.0  ## Maximum distance for placing nails

# --- PRIVATE VARIABLES ---
var nail_spawn_marker: Marker3D

# --- GODOT METHODS ---

func _ready() -> void:
	super._ready()
	# Override bullet_scene to use nail_scene
	bullet_scene = nail_scene

	# Find nail spawn marker
	nail_spawn_marker = parent_object.get_node_or_null("nail_spawn")
	if not nail_spawn_marker:
		push_error("NailGunComponent: No 'nail_spawn' Marker3D found!")

# --- OVERRIDDEN METHODS ---

func _spawn_bullet() -> void:
	"""Spawn projectile nail that flies through air"""
	if not projectile_nail_scene:
		push_warning("NailGunComponent: No projectile nail scene!")
		return

	if not nail_spawn_marker:
		push_warning("NailGunComponent: No nail spawn marker!")
		return

	# Get camera for aiming
	var camera = player_ref.get_camera()
	if not camera:
		push_warning("NailGunComponent: No camera!")
		return

	# === STEP 1: Raycast from camera to find wall hit (THE CLEAN WAY) ===
	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z

	var space_state = get_world_3d().direct_space_state
	var ray_query = PhysicsRayQueryParameters3D.create(
		camera_pos,
		camera_pos + camera_forward * max_nail_range
	)
	ray_query.exclude = [parent_object]
	ray_query.collision_mask = 2  # Static World layer

	var raycast_result = space_state.intersect_ray(ray_query)

	if not raycast_result:
		print("NailGun: No surface hit")
		return  # No hit, don't fire

	# === STEP 2: Validate surface (reject floors) ===
	var surface_normal = raycast_result.normal
	var hit_position = raycast_result.position

	var up_alignment = surface_normal.dot(Vector3.UP)
	if up_alignment > 0.7:
		print("NailGun: Cannot place nail on floor! (alignment: ", up_alignment, ")")
		return  # Don't fire at floors

	# === STEP 3: Calculate fire direction from nail spawn to hit point ===
	var nail_spawn_pos = nail_spawn_marker.global_position
	var fire_direction = (hit_position - nail_spawn_pos).normalized()

	# === STEP 4: Create and launch projectile nail ===
	var projectile_nail = projectile_nail_scene.instantiate()

	# Set fire direction
	projectile_nail.fire_direction = fire_direction

	# Pass WallNail scene to projectile
	projectile_nail.wall_nail_scene = nail_scene

	# Pass pre-calculated hit info (from the clean raycast!)
	projectile_nail.target_hit_position = hit_position
	projectile_nail.target_hit_normal = surface_normal
	projectile_nail.has_target = true

	# Add to world first (required for global transforms)
	get_tree().root.add_child(projectile_nail)

	# Set position and rotation AFTER adding to tree
	projectile_nail.global_position = nail_spawn_pos
	projectile_nail.look_at(nail_spawn_pos + fire_direction * 10.0, Vector3.UP)

	# Launch the nail AFTER position is set
	projectile_nail.launch()

	print("=== PROJECTILE NAIL SPAWNED ===")
	print("  Spawn pos: ", nail_spawn_pos)
	print("  Target hit pos: ", hit_position)
	print("  Surface normal: ", surface_normal)
	print("  Fire direction: ", fire_direction)

func _calculate_nail_rotation(surface_normal: Vector3) -> Vector3:
	"""Calculate rotation to make nail stick perpendicular to surface"""
	# Nail model's length runs along X axis:
	# - Head (positive X) should point OUT from wall (along surface_normal)
	# - Point (negative X) should point INTO wall (along -surface_normal)

	var up = Vector3.UP

	# Handle edge case: surface is perfectly vertical (normal perpendicular to up)
	if abs(surface_normal.dot(up)) > 0.99:
		up = Vector3.RIGHT

	# Build orthonormal basis
	# We want surface_normal to be the nail's X axis (head points out)
	var right = surface_normal.cross(up).normalized()
	up = right.cross(surface_normal).normalized()

	# Basis: X=surface_normal (head out), Y=up, Z=right
	var basis = Basis(surface_normal, up, right)

	return basis.get_euler()
