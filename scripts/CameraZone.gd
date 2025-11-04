extends Area3D
## Camera Zone - triggers cinematic camera when player enters
## Supports multiple cameras with optional cycling, priority-based zone stacking

@export_group("Zone Settings")
@export var zone_priority: int = 0 ## Higher priority zones override lower ones when overlapping
@export var blend_time: float = 0.6 ## Time to blend between cameras
@export var auto_disable_player_input: bool = false ## Disable player movement in this zone

@export_group("Camera Cycling")
@export var cycle_enabled: bool = false ## Cycle between multiple cameras
@export var cycle_interval: float = 4.0 ## Seconds between camera switches
@export var cycle_cameras: Array[NodePath] = [] ## Paths to Camera3D nodes to cycle through

signal zone_entered(zone)
signal zone_exited(zone)

var _cameras: Array[Camera3D] = []
var _player_inside: bool = false
var _cycle_timer: float = 0.0
var _current_camera_index: int = 0

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Resolve camera paths
	_resolve_cameras()
	
	# Disable processing initially
	set_process(false)

func _resolve_cameras():
	"""Resolve camera node paths to actual Camera3D references"""
	_cameras.clear()
	
	# First check for direct Camera3D children
	for child in get_children():
		if child is Camera3D:
			_cameras.append(child)
			# Disable cameras initially (CameraManager will enable them)
			child.current = false
	
	# Then check exported paths
	for cam_path in cycle_cameras:
		var cam = get_node_or_null(cam_path)
		if cam and cam is Camera3D and not cam in _cameras:
			_cameras.append(cam)
			cam.current = false
	
	if _cameras.is_empty():
		push_warning("CameraZone '%s' has no cameras configured!" % name)
	else:
		print("CameraZone '%s': Found %d camera(s)" % [name, _cameras.size()])

func _on_body_entered(body):
	"""Player entered the zone"""
	# Check if it's the player (adjust this check based on your player setup)
	if _is_player(body):
		_player_inside = true
		
		# Notify CameraManager
		if CameraManager:
			CameraManager.enter_camera_zone(self, blend_time)
		
		# Start cycling if enabled
		if cycle_enabled and _cameras.size() > 1:
			_start_cycling()
		
		# Disable player input if configured
		if auto_disable_player_input and CameraManager:
			CameraManager.set_player_input(false)
		
		emit_signal("zone_entered", self)

func _on_body_exited(body):
	"""Player exited the zone"""
	if _is_player(body):
		_player_inside = false
		
		# Notify CameraManager
		if CameraManager:
			CameraManager.exit_camera_zone(self, blend_time)
		
		# Stop cycling
		_stop_cycling()
		
		# Re-enable player input if it was disabled
		if auto_disable_player_input and CameraManager:
			CameraManager.set_player_input(true)
		
		emit_signal("zone_exited", self)

func _is_player(body) -> bool:
	"""Check if the body is the player - adjust based on your player setup"""
	# Option 1: Check by name
	if body.name == "Player":
		return true
	# Option 2: Check by group
	if body.is_in_group("player"):
		return true
	# Option 3: Check by class/script
	# if body.has_method("is_player"):
	#     return true
	return false

func get_active_camera() -> Camera3D:
	"""Returns the currently active camera for this zone"""
	if _cameras.is_empty():
		return null
	return _cameras[_current_camera_index]

func _start_cycling():
	"""Start cycling through cameras"""
	_cycle_timer = 0.0
	_current_camera_index = 0
	set_process(true)

func _stop_cycling():
	"""Stop cycling"""
	set_process(false)
	_current_camera_index = 0

func _process(delta):
	"""Handle camera cycling"""
	if not cycle_enabled or not _player_inside or _cameras.size() <= 1:
		return
	
	_cycle_timer += delta
	if _cycle_timer >= cycle_interval:
		_cycle_timer = 0.0
		_current_camera_index = (_current_camera_index + 1) % _cameras.size()
		
		# Tell CameraManager to switch to next camera
		if CameraManager:
			var next_cam = _cameras[_current_camera_index]
			CameraManager.switch_to_camera(next_cam, blend_time)

func set_camera_index(index: int):
	"""Manually set which camera to use (for scripted sequences)"""
	if index >= 0 and index < _cameras.size():
		_current_camera_index = index
		if _player_inside and CameraManager:
			CameraManager.switch_to_camera(_cameras[_current_camera_index], blend_time)
