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

	# === STEP 2: Determine target info based on raycast result ===
	var has_valid_target = false
	var target_position = Vector3.ZERO
	var target_normal = Vector3.UP
	var fire_direction = camera_forward
	var nail_spawn_pos = nail_spawn_marker.global_position

	if raycast_result:
		var surface_normal = raycast_result.normal
		var hit_position = raycast_result.position

		# Check if surface is floor (validation for WallNail spawning, not firing)
		var up_alignment = surface_normal.dot(Vector3.UP)
		if up_alignment > 0.7:
			print("NailGun: Floor detected - nail will bounce off")
			# has_valid_target stays false
		else:
			# Valid wall hit
			has_valid_target = true
			target_position = hit_position
			target_normal = surface_normal
			print("NailGun: Valid wall hit at ", hit_position)

		# Calculate fire direction to hit point
		fire_direction = (hit_position - nail_spawn_pos).normalized()
	else:
		# No hit - aim at max range (same pattern as regular bullets)
		print("NailGun: No surface hit - nail will fly into distance")
		var far_point = camera_pos + camera_forward * max_nail_range
		fire_direction = (far_point - nail_spawn_pos).normalized()

	# === STEP 3: ALWAYS create and launch projectile nail ===
	var projectile_nail = projectile_nail_scene.instantiate()

	# Set fire direction
	projectile_nail.fire_direction = fire_direction

	# Pass WallNail scene to projectile
	projectile_nail.wall_nail_scene = nail_scene

	# Pass target info (may be invalid - ProjectileNail will handle it)
	projectile_nail.target_hit_position = target_position
	projectile_nail.target_hit_normal = target_normal
	projectile_nail.has_target = has_valid_target  # Only true for valid walls

	# Add to world first (required for global transforms)
	get_tree().root.add_child(projectile_nail)

	# Set position AFTER adding to tree
	projectile_nail.global_position = nail_spawn_pos

	# Orient nail so sharp point (at negative X) faces forward in fire_direction
	# We want: -X axis aligned with fire_direction
	# So: +X axis aligned with -fire_direction
	var up = Vector3.UP
	if abs(fire_direction.dot(up)) > 0.99:
		up = Vector3.RIGHT

	# Build basis with X pointing backward (so -X points forward)
	var nail_right = up.cross(fire_direction).normalized()  # Z axis
	var nail_up = fire_direction.cross(nail_right).normalized()  # Y axis

	# X axis should point opposite to fire direction (so -X points in fire_direction)
	var basis = Basis(-fire_direction, nail_up, nail_right)
	projectile_nail.global_transform.basis = basis

	# Launch the nail AFTER position is set
	projectile_nail.launch()

	print("=== PROJECTILE NAIL SPAWNED ===")
	print("  Spawn pos: ", nail_spawn_pos)
	print("  Has valid target: ", has_valid_target)
	if has_valid_target:
		print("  Target hit pos: ", target_position)
		print("  Surface normal: ", target_normal)
	else:
		print("  Aiming at invalid target - will despawn naturally")
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
