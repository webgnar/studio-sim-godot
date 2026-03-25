extends RigidBody3D

func _ready():
	mass = 0.005
	add_to_group("balls")
	continuous_cd = true

	var phys = PhysicsMaterial.new()
	phys.friction = 0.5
	phys.bounce = 0.3
	physics_material_override = phys

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.06
	col.shape = shape
	add_child(col)

	var mi = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.1, 0.1)
	mat.metallic = 0.5
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.05, 0.05)
	mat.emission_energy_multiplier = 0.5
	mi.material_override = mat
	add_child(mi)

func _physics_process(_delta):
	if global_position.y < -5:
		queue_free()
