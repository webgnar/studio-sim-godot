extends MeshInstance3D

@onready var mirror_camera = $SubViewport/Camera3D
@onready var player_camera = get_node("../Player/Head/Camera3D")  # Direct path to player camera

func _ready():
	# Ensure the viewport is set up
	var viewport = $SubViewport
	viewport.size = Vector2(256, 256)  # Adjust resolution as needed
	viewport.own_world_3d = false  # Use the same world as the main scene
	viewport.world_3d = null  # Clear the custom world to use the main scene's world
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Prevent the mirror camera from seeing the mirror itself (avoid infinite loop)
	# Put the mirror on layer 2, keep everything else on layer 1
	set_layer_mask_value(1, false)  # Remove from layer 1 
	set_layer_mask_value(2, true)   # Put mirror on layer 2
	mirror_camera.cull_mask = 1     # Camera only sees layer 1 (not layer 2 = not the mirror)
	
	# Debug: Print if components are found
	print("Mirror camera found: ", mirror_camera != null)
	print("Player camera found: ", player_camera != null)
	print("Viewport found: ", viewport != null)
	
	# Ensure the material is using the viewport texture
	var material = get_surface_override_material(0)
	if material:
		material.albedo_texture = viewport.get_texture()
		print("Material updated with viewport texture")

func _process(delta):
	if player_camera:
		# Get the mirror's plane (assuming the mirror faces along its local Z-axis)
		var mirror_normal = global_transform.basis.z.normalized()
		var mirror_position = global_transform.origin
		
		# Calculate the reflected camera position
		var player_cam_pos = player_camera.global_transform.origin
		var distance_to_mirror = mirror_normal.dot(player_cam_pos - mirror_position)
		var reflected_pos = player_cam_pos - 2.0 * distance_to_mirror * mirror_normal
		
		# Set the mirror camera's position
		mirror_camera.global_transform.origin = reflected_pos
		
		# Calculate the reflected camera orientation
		var player_forward = -player_camera.global_transform.basis.z.normalized()
		var reflected_forward = player_forward - 2.0 * (player_forward.dot(mirror_normal)) * mirror_normal
		var reflected_up = player_camera.global_transform.basis.y.normalized()
		
		# Set the mirror camera to look at the reflected target
		var look_target = reflected_pos + reflected_forward
		mirror_camera.global_transform = mirror_camera.global_transform.looking_at(look_target, reflected_up)
		
		# Debug output (remove after testing)
		if Input.is_action_just_pressed("ui_accept"):  # Press Enter/Space for debug
			print("Mirror X-axis: ", global_transform.basis.x.normalized())
			print("Mirror Y-axis: ", global_transform.basis.y.normalized())
			print("Mirror Z-axis: ", global_transform.basis.z.normalized())
			print("Current Normal: ", mirror_normal)
			print("Player Pos: ", player_cam_pos)
			print("Reflected Pos: ", reflected_pos)
