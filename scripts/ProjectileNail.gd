extends RigidBody3D
class_name ProjectileNail

## Physics-based nail projectile
## Flies forward, collides with walls, spawns WallNail on impact

# --- EXPORTED VARIABLES ---
@export_group("Projectile Nail Settings")
@export var speed: float = 20.0  ## Nail flight speed
@export var lifetime: float = 5.0  ## Seconds before auto-despawn
@export var damage: float = 25.0  ## Damage dealt to hit objects
@export var wall_nail_scene: PackedScene  ## WallNail.tscn scene to spawn on impact
@export var visual_rotation_offset: Vector3 = Vector3(0, 90, 0)  ## Model rotation offset (degrees)

# --- PRIVATE VARIABLES ---
var _lifetime_timer: float = 0.0
var fire_direction: Vector3 = Vector3.FORWARD  ## Direction to fire (set by NailGunComponent)

# Pre-calculated hit info (set by NailGunComponent from raycast)
var target_hit_position: Vector3 = Vector3.ZERO
var target_hit_normal: Vector3 = Vector3.UP
var has_target: bool = false

# --- GODOT METHODS ---

func _ready() -> void:
	# Don't apply visual rotation - orientation is set by NailGunComponent
	# var model = get_node_or_null("nail_model")
	# if model:
	# 	model.rotation_degrees = visual_rotation_offset

	print("=== PROJECTILE NAIL _ready() DEBUG ===")
	print("  Nail position: ", global_position)
	print("  Fire direction: ", fire_direction)
	print("  Speed: ", speed)
	print("  Has target: ", has_target)
	print("  Target position: ", target_hit_position)
	print("  Target normal: ", target_hit_normal)
	print("  Wall nail scene: ", wall_nail_scene)

	# Connect collision signal
	if has_signal("body_entered"):
		body_entered.connect(_on_body_entered)
		print("  body_entered signal connected!")
	else:
		print("  ERROR: No body_entered signal!")

func launch() -> void:
	"""Apply impulse to launch the nail - called after position is set"""
	var impulse = fire_direction * speed
	print("  Launching nail with impulse: ", impulse)
	print("  Nail global_position at launch: ", global_position)
	print("  Linear velocity before impulse: ", linear_velocity)
	apply_central_impulse(impulse)
	print("  Linear velocity after impulse: ", linear_velocity)

func _physics_process(delta: float) -> void:
	# Track lifetime
	_lifetime_timer += delta

	# Debug: Print position every 0.5 seconds
	if int(_lifetime_timer * 2) != int((_lifetime_timer - delta) * 2):
		print("  Nail flying - pos: ", global_position, " vel: ", linear_velocity.length())

	# Auto-despawn after lifetime
	if _lifetime_timer >= lifetime:
		print("ProjectileNail: Lifetime expired at pos: ", global_position)
		queue_free()

# --- COLLISION HANDLING ---

func _on_body_entered(body: Node) -> void:
	"""Handle collision - stick to NPC or spawn WallNail using pre-calculated hit info"""

	print("=== PROJECTILE NAIL COLLISION DETECTED ===")
	print("  Hit body: ", (body.name as String) if body else ("null" as String))
	print("  Has target: ", has_target)
	print("  Projectile pos: ", global_position)

	# Try to apply damage to the hit object
	_try_apply_damage(body)

	# NPC hit: attach nail visually to the NPC
	if body.is_in_group("npc"):
		print("  NPC hit - sticking nail to: ", body.name)
		_stick_to_npc(body as Node3D)
		queue_free()
		return

	# Use pre-calculated hit info from the clean raycast (done when gun fired)
	if not has_target:
		print("  No valid target - nail will continue as physics object")
		# Don't despawn - let the nail bounce/collide and despawn naturally after lifetime
		return

	# Use the pre-calculated values from the original raycast
	var collision_normal = target_hit_normal
	var collision_pos = target_hit_position

	print("  Using target pos: ", collision_pos)
	print("  Using target normal: ", collision_normal)

	# === STEP 1: Calculate nail rotation ===
	var nail_rotation = _calculate_nail_rotation(collision_normal)
	print("  Calculated rotation: ", nail_rotation)

	# === STEP 2: Spawn WallNail ===
	if not wall_nail_scene:
		print("  ERROR: No wall nail scene!")
		push_warning("ProjectileNail: No wall nail scene!")
		queue_free()
		return

	print("  Creating WallNail instance...")
	var wall_nail = wall_nail_scene.instantiate()
	get_tree().root.add_child(wall_nail)

	# Position slightly into wall (using pre-calculated position)
	wall_nail.global_position = collision_pos + collision_normal * 0.01
	wall_nail.global_rotation = nail_rotation

	print("=== WALL NAIL CREATED SUCCESSFULLY ===")
	print("  Wall nail pos: ", wall_nail.global_position)
	print("  Wall nail rotation: ", wall_nail.global_rotation)
	print("  Surface normal: ", collision_normal)

	# Despawn projectile (completes the illusion)
	print("  Despawning projectile nail...")
	queue_free()

func _stick_to_npc(npc: Node3D) -> void:
	"""Attach a nail mesh as a child of the NPC so it follows their movement"""
	var npc_nail_scene: PackedScene = load("res://scenes/objects/NPCNail.tscn")
	if not npc_nail_scene:
		push_warning("ProjectileNail: Could not load NPCNail.tscn")
		return

	# Use fire_direction — linear_velocity is unreliable at collision time
	# because the physics engine modifies it during collision resolution
	var travel_dir := fire_direction.normalized()

	# Push the nail center into the NPC mesh (capsule collider edge is ~0.2 outside the mesh)
	var hit_pos := global_position + travel_dir * 0.4

	# Nail head points back toward the shooter (opposite of travel direction)
	var surface_normal := -travel_dir

	var nail := npc_nail_scene.instantiate() as Node3D
	npc.add_child(nail)
	nail.global_position = hit_pos
	nail.global_transform.basis = _calculate_nail_basis(surface_normal)

	print("  NPCNail attached at local pos: ", nail.position)


func _calculate_nail_basis(surface_normal: Vector3) -> Basis:
	"""Build a Basis to orient the nail perpendicular to the surface.
	Nail X axis = surface_normal (head points out), point embeds inward."""
	var up := Vector3.UP
	if abs(surface_normal.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var right := surface_normal.cross(up).normalized()
	up = right.cross(surface_normal).normalized()
	return Basis(surface_normal, up, right)


func _calculate_nail_rotation(surface_normal: Vector3) -> Vector3:
	return _calculate_nail_basis(surface_normal).get_euler()

func _try_apply_damage(body: Node) -> void:
	"""Attempt to apply damage to the hit object"""
	# Check if body has a damage method (common patterns)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_method("damage"):
		body.damage(damage)

	# Check for BreakableComponent
	var breakable = _find_breakable_component(body)
	if breakable and breakable.has_method("take_damage"):
		breakable.take_damage(damage)
		if SteamManager:
			SteamManager.unlock_achievement("ACH_NAILGUN")

func _find_breakable_component(node: Node) -> Node:
	"""Search for BreakableComponent in node hierarchy"""
	# Check children
	for child in node.get_children():
		if child.get_class() == "BreakableComponent" or child.name.contains("Breakable"):
			return child

	return null
