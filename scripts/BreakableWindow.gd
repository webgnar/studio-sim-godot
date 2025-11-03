extends StaticBody3D

## Breakable window that cracks and breaks when hit by objects
## Health: 3 = intact, 2 = cracked, 1 = very cracked, 0 = destroyed
## NOTE: Add an Area3D child node named "DetectionArea" with its own CollisionShape3D

@export var is_breakable: bool = true
@export var health: int = 3
@export var damage_velocity_threshold: float = 2.0  # Minimum velocity to cause damage
@export var damage_cooldown: float = 0.5  # Seconds between damage instances (prevents multiple hits from one throw)

# Particle settings
@export_group("Particle Effects")
@export var enable_particles: bool = true
@export var shard_particle_count: int = 50
@export var dust_particle_count: int = 20
@export var use_custom_shard_texture: bool = false  # Toggle to use custom texture
@export var custom_shard_texture: Texture2D = null  # Drag your texture here in inspector!
@export var use_custom_shard_mesh: bool = false  # Toggle to use custom 3D model
@export var custom_shard_mesh: Mesh = null  # Drag your .glb here!
@export var use_custom_dust_texture: bool = false
@export var custom_dust_texture: Texture2D = null
@export var use_particle_scene: bool = false  # Toggle to use pre-made particle scene
@export var custom_particle_scene: PackedScene = null  # Drag particle_test.tscn here!

# Texture paths for different damage states
const TEXTURE_INTACT = "res://models/props/window_0.png"
const TEXTURE_CRACKED = "res://models/props/window_2.png"
const TEXTURE_VERY_CRACKED = "res://models/props/window_3.png"

var glass_material: StandardMaterial3D
var detection_area: Area3D
var mesh_instance: MeshInstance3D
var last_damage_time: float = 0.0  # Track last damage to enforce cooldown

func _ready():
	print("BreakableWindow: Initializing...")
	
	# Find the MeshInstance3D
	mesh_instance = _find_mesh_instance(self)
	if not mesh_instance:
		push_error("BreakableWindow: No MeshInstance3D found!")
		return
	print("  -> Found MeshInstance3D: ", mesh_instance.name)
	
	# Load the windowglass material and make a unique copy
	var original_material = load("res://materials/windowglass.tres")
	if not original_material:
		push_error("BreakableWindow: Could not load windowglass.tres material!")
		return
	
	# Create a unique duplicate for this window instance
	glass_material = original_material.duplicate()
	print("  -> Created unique copy of windowglass.tres material")
	
	# Apply the unique material to the mesh
	# First check how many surfaces the mesh has
	print("  -> Mesh has ", mesh_instance.mesh.get_surface_count(), " surfaces")
	
	var material_applied = false
	for i in range(mesh_instance.mesh.get_surface_count()):
		var surface_mat = mesh_instance.mesh.surface_get_material(i)
		print("    Surface ", i, " material: ", surface_mat)
		
		# Check if this surface uses the windowglass material
		if surface_mat and surface_mat.resource_path == "res://materials/windowglass.tres":
			mesh_instance.set_surface_override_material(i, glass_material)
			print("  -> ✅ Applied unique material to surface ", i)
			material_applied = true
			break
	
	if not material_applied:
		push_warning("BreakableWindow: Could not find windowglass.tres on any surface!")
	
	# Set initial texture
	update_texture()
	
	# Find the Area3D for collision detection
	if has_node("Area3D"):
		detection_area = $Area3D
	elif has_node("DetectionArea"):
		detection_area = $DetectionArea
	else:
		# Try to find any Area3D child
		for child in get_children():
			if child is Area3D:
				detection_area = child
				break
	
	if detection_area:
		print("  -> Found DetectionArea: ", detection_area.name)
		print("  -> DetectionArea monitoring: ", detection_area.monitoring)
		print("  -> DetectionArea monitorable: ", detection_area.monitorable)
		print("  -> DetectionArea collision layer: ", detection_area.collision_layer)
		print("  -> DetectionArea collision mask: ", detection_area.collision_mask)
		detection_area.body_entered.connect(_on_body_entered)
		print("  -> Connected body_entered signal")
	else:
		push_warning("BreakableWindow: No Area3D found! Add an Area3D child for collision detection")
		print("  -> Available children:")
		for child in get_children():
			print("    - ", child.name, " (", child.get_class(), ")")
	
	print("BreakableWindow: Ready! Health: ", health)

func _on_body_entered(body: Node):
	# Skip if window is not breakable
	if not is_breakable:
		return
	
	print("BreakableWindow: Something hit the window! Body: ", body.name)
	
	# Check if the object is being carried (not thrown) - don't damage
	var carryable = _find_carryable_component(body)
	if carryable and carryable.is_being_carried():
		print("  -> Object is being carried by player, no damage")
		return
	
	# Check if the body has enough velocity to damage the window
	if body is RigidBody3D:
		var velocity = body.linear_velocity.length()
		print("  -> RigidBody velocity: ", velocity, " (threshold: ", damage_velocity_threshold, ")")
		if velocity >= damage_velocity_threshold:
			# Check cooldown to prevent multiple hits from one throw
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_damage_time < damage_cooldown:
				print("  -> ⏱️ Damage on cooldown")
				return
			
			print("  -> DAMAGE APPLIED! Health before: ", health)
			last_damage_time = current_time
			take_damage()
		else:
			print("  -> Too slow, no damage")
	else:
		print("  -> Not a RigidBody3D, type: ", body.get_class())

func _find_carryable_component(node: Node) -> CarryableComponent:
	"""Find CarryableComponent in node or its children"""
	if node is CarryableComponent:
		return node
	for child in node.get_children():
		if child is CarryableComponent:
			return child
	return null

func take_damage():
	health -= 1
	
	if health <= 0:
		# Window is destroyed
		break_window()
	else:
		# Update texture to show cracks
		update_texture()
		# Spawn crack dust particles
		if enable_particles:
			spawn_crack_dust()

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	# Recursively search for MeshInstance3D
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null

func update_texture():
	if not glass_material:
		push_warning("update_texture called but glass_material is null!")
		return
	
	var texture_path = ""
	match health:
		3:
			texture_path = TEXTURE_INTACT
		2:
			texture_path = TEXTURE_CRACKED
		1:
			texture_path = TEXTURE_VERY_CRACKED
	
	print("BreakableWindow: Updating texture for health ", health, " -> ", texture_path)
	
	if texture_path != "":
		var texture = load(texture_path)
		if texture:
			glass_material.albedo_texture = texture
			print("  -> ✅ Texture updated successfully")
		else:
			push_error("  -> ❌ Could not load texture: ", texture_path)

func break_window():
	print("Window broken!")
	
	# Spawn glass shatter particles before destroying
	if enable_particles:
		spawn_glass_shatter()
	
	# Wait a moment for particles to spawn, then destroy window
	await get_tree().create_timer(0.1).timeout
	queue_free()

func spawn_crack_dust():
	"""Create small dust particles when window is cracked"""
	var particles = GPUParticles3D.new()
	get_parent().add_child(particles)  # Add to parent so it persists after window is destroyed
	particles.global_position = global_position
	
	# Configure particle system
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30  # More particles
	particles.lifetime = 1.0  # Last longer
	particles.explosiveness = 0.9
	
	# Create particle material
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 2.0  # Spawn in small area at impact
	
	# Particle physics - burst outward
	particle_mat.direction = Vector3(0, 0, 1)
	particle_mat.spread = 60.0  # Wider spread
	particle_mat.initial_velocity_min = 2.0
	particle_mat.initial_velocity_max = 5.0
	particle_mat.gravity = Vector3(0, -3, 0)  # Fall slowly
	
	# Fade out over time
	particle_mat.scale_min = 0.2  # Bigger particles
	particle_mat.scale_max = 0.5
	
	# Bright white/cyan dust - more visible!
	particle_mat.color = Color(0.8, 1.0, 1.0, 1.0)  # Cyan-white, full opacity
	
	particles.process_material = particle_mat
	
	# Create sphere mesh for dust particles
	var mesh = SphereMesh.new()
	mesh.radial_segments = 4
	mesh.rings = 4
	mesh.radius = 0.15
	mesh.height = 0.3
	
	# Add emissive material
	var dust_material = StandardMaterial3D.new()
	
	# Use custom texture if provided, otherwise use solid color
	if use_custom_dust_texture and custom_dust_texture:
		print("  -> Using custom dust texture: ", custom_dust_texture.resource_path)
		dust_material.albedo_texture = custom_dust_texture
		dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		dust_material.albedo_color = Color(0.9, 1.0, 1.0)
		dust_material.emission_enabled = true
		dust_material.emission = Color(0.6, 0.8, 1.0)  # Glowing cyan
		dust_material.emission_energy_multiplier = 1.5
	
	mesh.material = dust_material
	
	particles.draw_pass_1 = mesh
	
	print("💨 Spawning crack dust particles at: ", particles.global_position)
	
	# Auto-delete after finished
	await get_tree().create_timer(particles.lifetime + 1.0).timeout
	particles.queue_free()

func spawn_glass_shatter():
	"""Create glass shard particles when window breaks"""
	
	# Option 1: Use custom particle scene if provided
	if use_particle_scene and custom_particle_scene:
		print("  -> Using custom particle scene: ", custom_particle_scene.resource_path)
		var particles = custom_particle_scene.instantiate()
		get_parent().add_child(particles)
		particles.global_position = global_position
		
		# Trigger emission if it's a GPUParticles3D
		if particles is GPUParticles3D:
			particles.emitting = true
			particles.restart()
			# Auto-cleanup
			await get_tree().create_timer(particles.lifetime + 1.0).timeout
			particles.queue_free()
		return
	
	# Option 2: Create particles procedurally (original code)
	var particles = GPUParticles3D.new()
	get_parent().add_child(particles)  # Add to parent so it persists
	particles.global_position = global_position
	
	# Configure particle system
	particles.emitting = true
	particles.one_shot = true
	particles.amount = shard_particle_count
	particles.lifetime = 1.5
	particles.explosiveness = 0.9
	
	# Create particle material
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_mat.emission_box_extents = Vector3(9, 12, 0.5)  # Window size
	
	# Particle physics - explosive outward burst
	particle_mat.direction = Vector3(0, 0, 1)
	particle_mat.spread = 180.0  # All directions
	particle_mat.initial_velocity_min = 3.0
	particle_mat.initial_velocity_max = 8.0
	particle_mat.gravity = Vector3(0, -9.8, 0)  # Realistic gravity
	
	# Add some spin to the shards
	particle_mat.angular_velocity_min = -180.0
	particle_mat.angular_velocity_max = 180.0
	
	# Particle appearance - MUCH BIGGER!
	particle_mat.scale_min = 0.5
	particle_mat.scale_max = 1.5
	
	# Glass color - cyan tint with transparency
	var glass_color = Color(0.7, 0.9, 1.0, 0.8)
	particle_mat.color = glass_color
	
	particles.process_material = particle_mat
	
	# Choose mesh type based on whether we're using custom texture
	var mesh
	var shard_material = StandardMaterial3D.new()
	
	# Priority 1: Custom 3D mesh (GLB model)
	if use_custom_shard_mesh and custom_shard_mesh:
		print("  -> Using custom 3D mesh/model: ", custom_shard_mesh.resource_path)
		mesh = custom_shard_mesh
		# The GLB already has its own material, so we don't override it
	
	# Priority 2: Custom texture on flat quad
	elif use_custom_shard_texture and custom_shard_texture:
		print("  -> Using custom glass shard texture: ", custom_shard_texture.resource_path)
		# Use a flat quad (billboard) for texture-based particles
		mesh = QuadMesh.new()
		mesh.size = Vector2(0.8, 1.2)
		
		# Apply custom texture
		shard_material.albedo_texture = custom_shard_texture
		shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shard_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED  # Always face camera
		shard_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # No lighting
	else:
		# Use 3D box mesh for default glass shards
		mesh = BoxMesh.new()
		mesh.size = Vector3(0.8, 1.2, 0.05)  # Much bigger thin shard shape
		
		# Glass-like material (reuse glass_color from above)
		shard_material.albedo_color = glass_color
		shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shard_material.metallic = 0.2
		shard_material.roughness = 0.3
	
	# Only apply material if we created one (not using custom mesh)
	if not use_custom_shard_mesh:
		mesh.material = shard_material
	
	particles.draw_pass_1 = mesh
	
	# Auto-delete after finished
	await get_tree().create_timer(particles.lifetime + 1.0).timeout
	particles.queue_free()
