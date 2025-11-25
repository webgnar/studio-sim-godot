extends Node
## Singleton to manage camera transitions between player camera and cinematic cameras
## Handles smooth blending and zone-based camera switching

signal camera_switched(from_camera: Camera3D, to_camera: Camera3D)

@export var default_blend_time: float = 0.6

var player_camera: Camera3D = null
var current_camera: Camera3D = null
var active_zones: Array[Node] = []
var is_blending: bool = false
var player_input_enabled: bool = true

# Internal blending state
var _blend_timer: float = 0.0
var _blend_duration: float = 0.0
var _start_transform: Transform3D
var _end_transform: Transform3D
var _start_fov: float = 75.0
var _end_fov: float = 75.0
var _target_camera: Camera3D = null
var _transition_camera: Camera3D = null

func _ready():
	# Create a dedicated transition camera for smooth interpolation
	_transition_camera = Camera3D.new()
	_transition_camera.name = "TransitionCamera"
	add_child(_transition_camera)

func register_player_camera(cam: Camera3D):
	"""Call this from the player script to register the player's main camera"""
	player_camera = cam
	current_camera = cam
	print("CameraManager: Registered player camera")

func enter_camera_zone(zone: Node, blend_time: float = -1.0):
	"""Called when player enters a camera zone"""
	if blend_time < 0:
		blend_time = default_blend_time
	
	# Add to active zones (support overlapping zones)
	if not zone in active_zones:
		active_zones.append(zone)
	
	# Get the highest priority zone
	var target_zone = _get_highest_priority_zone()
	if target_zone and target_zone.has_method("get_active_camera"):
		var new_camera = target_zone.get_active_camera()
		if new_camera and new_camera != current_camera:
			switch_to_camera(new_camera, blend_time)

func exit_camera_zone(zone: Node, blend_time: float = -1.0):
	"""Called when player exits a camera zone"""
	if blend_time < 0:
		blend_time = default_blend_time
	
	# Remove from active zones
	active_zones.erase(zone)
	
	# If no zones active, return to player camera
	if active_zones.is_empty():
		if player_camera and current_camera != player_camera:
			switch_to_camera(player_camera, blend_time)
	else:
		# Switch to next highest priority zone
		var target_zone = _get_highest_priority_zone()
		if target_zone and target_zone.has_method("get_active_camera"):
			var new_camera = target_zone.get_active_camera()
			if new_camera and new_camera != current_camera:
				switch_to_camera(new_camera, blend_time)

func switch_to_camera(new_cam: Camera3D, blend_time: float = 0.6):
	"""Switch to a specific camera with smooth blending"""
	if new_cam == current_camera or new_cam == null:
		return
	
	if is_blending:
		# Cancel current blend
		_finish_blend(false)
	
	var from_camera = current_camera
	_target_camera = new_cam
	_blend_duration = max(0.01, blend_time)
	_blend_timer = 0.0
	
	# Store start and end transforms
	if current_camera:
		_start_transform = current_camera.global_transform
		_start_fov = current_camera.fov
	else:
		_start_transform = new_cam.global_transform
		_start_fov = new_cam.fov

	_end_transform = new_cam.global_transform
	_end_fov = new_cam.fov
	
	is_blending = true
	set_process(true)
	
	emit_signal("camera_switched", from_camera, new_cam)
	print("CameraManager: Switching from %s to %s over %.2fs" % [
		from_camera.name if from_camera else "none",
		new_cam.name,
		blend_time
	])

func force_camera_immediate(cam: Camera3D):
	"""Instantly switch to a camera without blending (for cutscenes)"""
	if is_blending:
		_finish_blend(false)
	current_camera = cam
	cam.make_current()

func _process(delta):
	if not is_blending:
		set_process(false)
		return
	
	_blend_timer += delta
	var t = clamp(_blend_timer / _blend_duration, 0.0, 1.0)
	
	# Smooth interpolation using ease-in-out
	var smooth_t = _smooth_step(t)

	# Interpolate transform
	var interp_transform = _start_transform.interpolate_with(_end_transform, smooth_t)
	_transition_camera.global_transform = interp_transform

	# Interpolate FOV
	_transition_camera.fov = lerp(_start_fov, _end_fov, smooth_t)
	
	# Make transition camera active
	if not _transition_camera.is_current():
		_transition_camera.make_current()
	
	# Finish blend when complete
	if t >= 1.0:
		_finish_blend(true)

func _finish_blend(success: bool):
	"""Complete the camera blend"""
	is_blending = false
	
	if success and _target_camera:
		_target_camera.make_current()
		current_camera = _target_camera
		print("CameraManager: Blend complete, now using %s" % current_camera.name)
	
	_target_camera = null
	set_process(false)

func _get_highest_priority_zone() -> Node:
	"""Returns the zone with highest priority from active zones"""
	if active_zones.is_empty():
		return null
	
	var highest_zone = active_zones[0]
	var highest_priority = highest_zone.zone_priority if "zone_priority" in highest_zone else 0
	
	for zone in active_zones:
		var zone_priority_val = zone.zone_priority if "zone_priority" in zone else 0
		if zone_priority_val > highest_priority:
			highest_priority = zone_priority_val
			highest_zone = zone
	
	return highest_zone

func _smooth_step(t: float) -> float:
	"""Smooth ease-in-out interpolation"""
	return t * t * (3.0 - 2.0 * t)

func set_player_input(enabled: bool):
	"""Enable or disable player input (used during cutscenes/camera transitions)"""
	player_input_enabled = enabled
	# The player script should check CameraManager.player_input_enabled
	print("CameraManager: Player input %s" % ("enabled" if enabled else "disabled"))
