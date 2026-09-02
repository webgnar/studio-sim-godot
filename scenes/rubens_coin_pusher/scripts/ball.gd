extends RigidBody3D

const EARTH_SHADER: Shader = preload("res://shaders/earth_globe.gdshader")

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
	# earth_globe normalizes object-space position before sampling, so the
	# pattern looks the same regardless of the sphere's actual radius here.
	var mat = ShaderMaterial.new()
	mat.shader = EARTH_SHADER
	mi.material_override = mat
	add_child(mi)

func _physics_process(_delta):
	# Relative to the machine's own position, not a hardcoded world Y — see the
	# same fix in coin.gd for why (the machine isn't guaranteed to sit near
	# world Y 0).
	if GameManager.main_scene and global_position.y < GameManager.main_scene.global_position.y - 5:
		queue_free()
