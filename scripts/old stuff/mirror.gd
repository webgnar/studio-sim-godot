extends MeshInstance3D

@onready var mirror_camera = $SubViewport/Camera3D
@onready var player_camera = get_node("../Player/Head/Camera3D")  # Direct path to player camera

@export var show_debug_logs: bool = false  # Toggle debug console output
var debug_timer: float = 0.0  # Print debug every second, not every frame

func _ready():
	# Ensure the viewport is set up
	var viewport = $SubViewport
	viewport.size = Vector2(512, 512)  # Adjust resolution as needed
	viewport.own_world_3d = false  # Use the same world as the main scene
	# Note: Setting world_3d to null can cause warnings, but it's needed for mirror functionality
	if viewport.world_3d:
		viewport.world_3d = null  # Clear the custom world to use the main scene's world
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Prevent the mirror camera from seeing the mirror itself (avoid infinite loop)
	# Put the mirror on layer 2, keep everything else on layer 1
	set_layer_mask_value(1, false)  # Remove from layer 1
	set_layer_mask_value(2, true)   # Put mirror on layer 2
	mirror_camera.cull_mask = 1     # Camera only sees layer 1 (not layer 2 = not the mirror)

	# Prevent environment doubling - mirror uses same environment from world
	# Setting these can prevent light/reflection doubling issues
	# mirror_camera.environment = null  # Uncomment if lights still double

	# Set near plane to prevent rendering walls directly behind mirror
	mirror_camera.near = 0.1  # Don't render anything closer than 0.1 units

	# Debug: Print mirror camera settings
	if show_debug_logs:
		print("Mirror Camera Setup:")
		print("  Cull Mask: ", mirror_camera.cull_mask)
		print("  Near Plane: ", mirror_camera.near)
		print("  Environment: ", mirror_camera.environment)
		print("  Attributes: ", mirror_camera.attributes)
	
	# Ensure the material is using the viewport texture
	var material = get_surface_override_material(0)
	if material:
		material.albedo_texture = viewport.get_texture()

func _process(_delta):
	if player_camera:
		# Get the mirror's plane (assuming the mirror faces along its local Z-axis)
		var mirror_normal = global_transform.basis.y.normalized()
		var mirror_position = global_transform.origin
		
		# Calculate the reflected camera position
		var player_cam_pos = player_camera.global_transform.origin
		var distance_to_mirror = mirror_normal.dot(player_cam_pos - mirror_position)
		var reflected_pos = player_cam_pos - 2.0 * distance_to_mirror * mirror_normal
		
		# Clamp the mirror camera to NEVER go behind the mirror surface
		# This prevents the camera from clipping through walls behind the mirror
		# which causes the sun (DirectionalLight) to render from the wrong side
		var distance_behind_mirror = mirror_normal.dot(mirror_position - reflected_pos)
		if distance_behind_mirror > 0:
			# Keep camera exactly at the mirror surface, don't go behind at all
			reflected_pos = mirror_position
		
		# Set the mirror camera's position
		mirror_camera.global_transform.origin = reflected_pos
		
		# Calculate the reflected camera orientation using quaternion-based basis reflection
		# This avoids gimbal lock by reflecting all three basis vectors across the mirror plane
		var player_basis = player_camera.global_transform.basis

		# Reflect ALL three basis vectors across the mirror plane
		var reflected_basis = Basis(
			player_basis.x.reflect(mirror_normal),   # Right vector
			player_basis.y.reflect(mirror_normal),   # Up vector
			-player_basis.z.reflect(mirror_normal)   # Forward vector (negated to face mirror)
		)

		# Normalize to prevent floating point drift
		reflected_basis = reflected_basis.orthonormalized()

		# Create the complete reflected transform (absolute rotation, no gimbal lock)
		var reflected_transform = Transform3D(reflected_basis, reflected_pos)
		mirror_camera.global_transform = reflected_transform

		# Mirror camera properties for accurate reflection
		mirror_camera.fov = player_camera.fov

		# Debug logging (prints once per second)
		if show_debug_logs:
			debug_timer += _delta
			if debug_timer >= 1.0:
				debug_timer = 0.0
				_print_debug_info()

func _print_debug_info():
	print("\n=== MIRROR DEBUG ===")

	var mirror_normal = global_transform.basis.y.normalized()
	print("Mirror Normal (YELLOW): ", mirror_normal)

	var player_basis = player_camera.global_transform.basis
	print("\nPlayer Camera Basis:")
	print("  Right (X/RED):    ", player_basis.x)
	print("  Up (Y/GREEN):     ", player_basis.y)
	print("  Forward (Z/BLUE): ", player_basis.z)

	var mirror_basis = mirror_camera.global_transform.basis
	print("\nMirror Camera Basis:")
	print("  Right (X):   ", mirror_basis.x)
	print("  Up (Y):      ", mirror_basis.y)
	print("  Forward (Z): ", mirror_basis.z)

	# Show what the reflection SHOULD be
	print("\nExpected Reflections:")
	print("  Right should be:   ", player_basis.x.reflect(mirror_normal))
	print("  Up should be:      ", player_basis.y.reflect(mirror_normal))
	print("  Forward should be: ", -player_basis.z.reflect(mirror_normal))
	print("==================\n")
