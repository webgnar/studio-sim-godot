extends Node3D
class_name PowerCord
## Visual power cord that draws between a plug and a connected device
## 
## SETUP:
## 1. Add this component to your plug's RigidBody3D node
## 2. Set "Connected Device" to the device this cord connects to (e.g., Boombox)
## 3. Optionally set "Device Attachment Point" to a Marker3D on the device for exact positioning
## 4. The cord will automatically draw between the plug and device

# --- EXPORTED VARIABLES ---
@export_group("Cord Connection")
@export var connected_device: Node3D ## The device this cord connects to (e.g., Boombox, Fan, Lamp)
@export var device_attachment_point: Marker3D ## Optional: specific point on device where cord attaches (if null, uses device center)
@export var plug_attachment_point: Marker3D ## Optional: specific point on plug where cord attaches (if null, uses plug center)

@export_group("Visual Settings")
@export var cord_thickness: float = 0.01 ## Thickness of the cord in meters
@export var cord_color: Color = Color.BLACK ## Color of the cord
@export var sag_amount: float = 0.3 ## How much the cord droops (0 = straight, 1 = very saggy)
@export var curve_segments: int = 12 ## Number of segments (more = smoother, 8-16 is good)

# --- PRIVATE VARIABLES ---
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D

# --- GODOT METHODS ---

func _ready() -> void:
	_setup_visual_cord()
	print("✅ PowerCord ready on: " + get_parent().name if get_parent() else "no parent")
	if connected_device:
		print("   Connected to device: " + connected_device.name)

func _process(_delta: float) -> void:
	if connected_device:
		_update_cord_visual()

# --- VISUAL CORD ---

func _setup_visual_cord() -> void:
	"""Create the 3D mesh for visual rope"""
	
	mesh_instance = MeshInstance3D.new()
	
	# Create simple material
	material = StandardMaterial3D.new()
	material.albedo_color = cord_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Faster, flat color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
	mesh_instance.material_override = material
	
	add_child(mesh_instance)

func _update_cord_visual() -> void:
	"""Update the cord mesh between plug and connected device"""
	
	if not is_instance_valid(connected_device):
		return
	
	# Start from this plug's position
	var start_pos: Vector3
	if plug_attachment_point and is_instance_valid(plug_attachment_point):
		start_pos = plug_attachment_point.global_position
	else:
		# Use the plug body (parent of this component)
		var plug_body = get_parent()
		if plug_body and plug_body is Node3D:
			start_pos = plug_body.global_position
		else:
			return
	
	# End at the connected device's position
	var end_pos: Vector3
	if device_attachment_point and is_instance_valid(device_attachment_point):
		end_pos = device_attachment_point.global_position
	else:
		end_pos = connected_device.global_position
	
	# Calculate curve points with sag
	var points = PackedVector3Array()
	var distance = start_pos.distance_to(end_pos)
	
	for i in range(curve_segments + 1):
		var t = float(i) / curve_segments
		
		# Linear interpolation
		var point = start_pos.lerp(end_pos, t)
		
		# Add sag (parabolic curve downward)
		var sag = sin(t * PI) * sag_amount * distance * 0.5
		point.y -= sag
		
		points.append(point)
	
	# Generate ribbon mesh
	_generate_ribbon_mesh(points)

func _generate_ribbon_mesh(points: PackedVector3Array) -> void:
	"""Generate a simple ribbon/strip mesh along the curve"""
	
	if points.size() < 2:
		return
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Get camera right vector for consistent orientation
	var camera = get_viewport().get_camera_3d()
	var cam_right = Vector3.RIGHT
	if camera:
		cam_right = camera.global_transform.basis.x
	
	# Generate simple flat ribbon
	for i in range(points.size()):
		var point = points[i]
		
		# Convert global point to local space of this PowerCord node
		var local_point = to_local(point)
		
		# Create perpendicular offset based on camera orientation
		var offset = cam_right * cord_thickness
		
		# Two vertices per point (left and right of ribbon)
		vertices.append(local_point - offset)
		vertices.append(local_point + offset)
		
		# Create triangle strip
		if i < points.size() - 1:
			var base = i * 2
			# Two triangles per segment
			indices.append(base)
			indices.append(base + 1)
			indices.append(base + 2)
			
			indices.append(base + 1)
			indices.append(base + 3)
			indices.append(base + 2)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	# Create mesh
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	mesh_instance.mesh = array_mesh

# --- PUBLIC METHODS ---

func get_cord_length() -> float:
	"""Get current cord distance between plug and device"""
	if not is_instance_valid(connected_device):
		return 0.0
	
	var plug_body = get_parent()
	if plug_body and plug_body is Node3D:
		return plug_body.global_position.distance_to(connected_device.global_position)
	return 0.0
