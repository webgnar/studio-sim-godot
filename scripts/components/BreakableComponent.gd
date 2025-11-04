extends Node
class_name BreakableComponent

## Modular component that makes any object breakable with damage states
## Add this as a child of any StaticBody3D or RigidBody3D
## Requires: MeshInstance3D with a material, Area3D for detection

signal damaged(new_health: float)
signal broken()

@export_group("Breakable Settings")
@export var is_breakable: bool = true
@export var max_health: float = 3.0
@export var current_health: float = 3.0
@export var damage_velocity_threshold: float = 2.0
@export var damage_cooldown: float = 0.5
@export var use_velocity_based_damage: bool = false  # Enable to calculate damage from impact force
@export var velocity_damage_multiplier: float = 0.5  # Damage = velocity * multiplier

@export_group("Visual Feedback")
@export var material_name: String = ""  # e.g., "windowglass", leave empty to use first material
@export var damage_textures: Array[Texture2D] = []  # Assign textures in order: intact, cracked, very cracked, etc.

@export_group("Particle Effects")
@export var enable_particles: bool = true
@export var break_particle_scene: PackedScene = null  # Glass shatter particles
@export var damage_particle_scene: PackedScene = null  # Dust puff particles

var parent_object: Node3D
var detection_area: Area3D
var mesh_instance: MeshInstance3D
var target_material: StandardMaterial3D
var last_damage_time: float = 0.0

func _ready():
	# Wait for parent to be ready
	await get_tree().process_frame
	
	parent_object = get_parent()
	if not parent_object:
		push_error("BreakableComponent: No parent object!")
		return
	
	print("BreakableComponent: Initializing on ", parent_object.name)
	
	# Find mesh
	mesh_instance = _find_mesh_instance(parent_object)
	if not mesh_instance:
		push_error("BreakableComponent: No MeshInstance3D found in parent!")
		return
	
	# Setup material
	_setup_material()
	
	# Find detection area
	detection_area = _find_area3d(parent_object)
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		print("  -> Connected to Area3D: ", detection_area.name)
	else:
		push_warning("BreakableComponent: No Area3D found! Add an Area3D child for collision detection")
	
	# Set initial visual state
	update_visual_state()
	print("BreakableComponent: Ready! Health: ", current_health, "/", max_health)

func _setup_material():
	"""Find and create unique material instance"""
	var surface_count = mesh_instance.mesh.get_surface_count()
	
	for i in range(surface_count):
		var surface_mat = mesh_instance.mesh.surface_get_material(i)
		
		# If material_name specified, look for matching material
		if material_name != "":
			if surface_mat and material_name in surface_mat.resource_path:
				target_material = surface_mat.duplicate()
				mesh_instance.set_surface_override_material(i, target_material)
				print("  -> Found material: ", surface_mat.resource_path)
				return
		else:
			# Use first material found
			if surface_mat:
				target_material = surface_mat.duplicate()
				mesh_instance.set_surface_override_material(i, target_material)
				print("  -> Using first material: ", surface_mat.resource_path)
				return
	
	push_warning("BreakableComponent: No suitable material found!")

func _on_body_entered(body: Node):
	if not is_breakable:
		return
	
	# Check if being carried
	var carryable = _find_carryable_component(body)
	if carryable and carryable.is_being_carried():
		return
	
	# Check velocity
	if body is RigidBody3D:
		var velocity = body.linear_velocity.length()
		if velocity >= damage_velocity_threshold:
			# Check cooldown
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_damage_time < damage_cooldown:
				return
			
			last_damage_time = current_time
			
			# Calculate damage based on velocity or object's impact_damage property
			var damage_amount = 1.0
			
			# Check if object has custom impact damage
			if carryable and "impact_damage" in carryable:
				damage_amount = carryable.impact_damage
				print("  -> Object impact damage: ", damage_amount)
			elif use_velocity_based_damage:
				# Fallback to velocity-based damage
				damage_amount = velocity * velocity_damage_multiplier
				damage_amount = max(0.1, damage_amount)  # At least 0.1 damage
				print("  -> Velocity-based damage: ", velocity, " -> ", damage_amount)
			
			print("  -> Applying ", damage_amount, " damage to ", parent_object.name)
			take_damage(damage_amount)

func take_damage(amount: float = 1.0):
	"""Apply damage to the object"""
	current_health -= amount
	current_health = max(0.0, current_health)
	
	damaged.emit(current_health)
	
	if current_health <= 0:
		break_object()
	else:
		update_visual_state()
		spawn_damage_particles()

func break_object():
	"""Destroy the object"""
	print("BreakableComponent: Object broken!")
	broken.emit()
	
	spawn_break_particles()
	
	# Wait for particles to spawn
	await get_tree().create_timer(0.1).timeout
	parent_object.queue_free()

func update_visual_state():
	"""Update texture based on health"""
	if not target_material or damage_textures.is_empty():
		return
	
	# Calculate which texture to use based on health percentage
	var health_percent = float(current_health) / float(max_health)
	var texture_index = damage_textures.size() - 1 - int(health_percent * damage_textures.size())
	texture_index = clamp(texture_index, 0, damage_textures.size() - 1)
	
	target_material.albedo_texture = damage_textures[texture_index]
	print("  -> Updated texture to index ", texture_index, " (health: ", current_health, "/", max_health, ")")

func spawn_damage_particles():
	"""Spawn particles when damaged but not broken"""
	if not enable_particles or not damage_particle_scene:
		return
	
	var particles_root = damage_particle_scene.instantiate()
	parent_object.get_parent().add_child(particles_root)
	particles_root.global_position = parent_object.global_position
	
	var particles = _find_gpu_particles(particles_root)
	if particles:
		particles.emitting = true
		particles.one_shot = true
		particles.restart()
		await get_tree().create_timer(particles.lifetime + 1.0).timeout
		particles_root.queue_free()

func spawn_break_particles():
	"""Spawn particles when object breaks"""
	if not enable_particles or not break_particle_scene:
		return
	
	var particles_root = break_particle_scene.instantiate()
	parent_object.get_parent().add_child(particles_root)
	particles_root.global_position = parent_object.global_position
	
	var particles = _find_gpu_particles(particles_root)
	if particles:
		particles.emitting = true
		particles.one_shot = true
		particles.restart()
		await get_tree().create_timer(particles.lifetime + 1.0).timeout
		particles_root.queue_free()

# Helper functions
func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null

func _find_area3d(node: Node) -> Area3D:
	if node is Area3D:
		return node
	for child in node.get_children():
		if child is Area3D:
			return child
	return null

func _find_carryable_component(node: Node) -> CarryableComponent:
	if node is CarryableComponent:
		return node
	for child in node.get_children():
		if child is CarryableComponent:
			return child
	return null

func _find_gpu_particles(node: Node) -> GPUParticles3D:
	if node is GPUParticles3D:
		return node
	for child in node.get_children():
		var result = _find_gpu_particles(child)
		if result:
			return result
	return null
