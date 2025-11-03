extends StaticBody3D

## Breakable window that cracks and breaks when hit by objects
## Health: 3 = intact, 2 = cracked, 1 = very cracked, 0 = destroyed
## NOTE: Add an Area3D child node named "DetectionArea" with its own CollisionShape3D

@export var is_breakable: bool = true
@export var health: int = 3
@export var damage_velocity_threshold: float = 2.0  # Minimum velocity to cause damage
@export var damage_cooldown: float = 0.5  # Seconds between damage instances (prevents multiple hits from one throw)

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
	if has_node("DetectionArea"):
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
	if body.has_method("is_being_carried"):
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
	# Optional: Add breaking sound/particles here
	print("Window broken!")
	queue_free()
