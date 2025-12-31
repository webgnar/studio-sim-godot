extends Node3D
## Laser beam visualization for player raycast
## Only visible when player is in a camera zone (cinematic view)

@export var beam_color: Color = Color.RED
@export var beam_width: float = 0.02
@export var max_beam_length: float = 100.0
@export var raycast_path: NodePath = NodePath("../Head/Camera3D/RayCast3D")

var _raycast: RayCast3D
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D

func _ready():
	# Try to find the raycast
	if has_node(raycast_path):
		_raycast = get_node(raycast_path)
	else:
		# Try to find any RayCast3D in the player
		_raycast = _find_raycast_in_tree(get_parent())
	
	if not _raycast:
		# Auto-create RayCast3D if none found
		_create_default_raycast()
	
	# Create the visual beam
	_create_beam_mesh()
	
	# Start hidden (only show in camera zones)
	visible = false

func _find_raycast_in_tree(node: Node) -> RayCast3D:
	"""Recursively search for a RayCast3D"""
	if node is RayCast3D:
		return node
	for child in node.get_children():
		var result = _find_raycast_in_tree(child)
		if result:
			return result
	return null

func _create_default_raycast():
	"""Create a default raycast at the camera"""
	var camera = get_viewport().get_camera_3d()
	if camera:
		_raycast = RayCast3D.new()
		_raycast.name = "InteractionRaycast"
		_raycast.target_position = Vector3(0, 0, -max_beam_length)
		_raycast.enabled = true
		_raycast.collide_with_areas = true
		_raycast.collide_with_bodies = true
		camera.add_child(_raycast)

func _create_beam_mesh():
	"""Create a cylindrical mesh for the laser beam"""
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "LaserBeamMesh"
	add_child(_mesh_instance)
	
	# Create material
	_material = StandardMaterial3D.new()
	_material.albedo_color = beam_color
	_material.emission_enabled = true
	_material.emission = beam_color
	_material.emission_energy_multiplier = 2.0
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color.a = 0.6
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Create cylinder mesh
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = beam_width
	cylinder.bottom_radius = beam_width
	cylinder.height = 1.0  # Will scale this dynamically
	cylinder.radial_segments = 8
	cylinder.rings = 1
	
	_mesh_instance.mesh = cylinder
	_mesh_instance.material_override = _material

func _process(_delta):
	if not _raycast or not _mesh_instance:
		return
	
	# Only show beam when NOT in first-person view
	var in_cinematic = CameraManager.current_camera != CameraManager.player_camera
	visible = in_cinematic
	
	if not visible:
		return
	
	# Update raycast
	_raycast.force_raycast_update()

	var beam_length = max_beam_length
	var _hit_point = _raycast.target_position

	if _raycast.is_colliding():
		var collision_point = _raycast.get_collision_point()
		var raycast_global_pos = _raycast.global_position
		beam_length = raycast_global_pos.distance_to(collision_point)
		_hit_point = _raycast.to_local(collision_point)
	
	# Position beam at raycast origin
	_mesh_instance.global_position = _raycast.global_position
	
	# Point beam toward target
	var direction = _raycast.global_transform.basis * Vector3(0, 0, -1)
	var end_position = _raycast.global_position + direction * beam_length
	var mid_point = (_raycast.global_position + end_position) / 2.0
	
	_mesh_instance.global_position = mid_point
	_mesh_instance.look_at(_raycast.global_position, Vector3.UP)
	_mesh_instance.rotate_object_local(Vector3.RIGHT, PI / 2)  # Align cylinder along beam
	
	# Scale to match beam length
	_mesh_instance.scale = Vector3(1, beam_length, 1)

func set_beam_color(color: Color):
	"""Change the beam color at runtime"""
	beam_color = color
	if _material:
		_material.albedo_color = color
		_material.emission = color
