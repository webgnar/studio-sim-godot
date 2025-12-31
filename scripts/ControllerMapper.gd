extends Node

## Platform-specific controller mapping singleton
## Detects Steam Deck and other platforms, provides correct axis mappings

enum ControllerType {
	XBOX,           ## Standard Xbox controller mapping
	STEAM_DECK,     ## Steam Deck internal controller
	PLAYSTATION,    ## PlayStation controllers
	GENERIC         ## Generic/unknown controller
}

var controller_type: ControllerType = ControllerType.GENERIC
var is_steam_deck: bool = false

# Axis mappings for different controllers
var axis_mappings: Dictionary = {
	ControllerType.XBOX: {
		"right_stick_x": JOY_AXIS_RIGHT_X,  # Axis 2
		"right_stick_y": JOY_AXIS_RIGHT_Y,  # Axis 3
	},
	ControllerType.STEAM_DECK: {
		"right_stick_x": JOY_AXIS_RIGHT_X,  # Axis 2 (usually same as Xbox)
		"right_stick_y": JOY_AXIS_RIGHT_Y,  # Axis 3 (usually same as Xbox)
	},
	ControllerType.PLAYSTATION: {
		"right_stick_x": JOY_AXIS_RIGHT_X,  # Axis 2
		"right_stick_y": JOY_AXIS_RIGHT_Y,  # Axis 3
	},
	ControllerType.GENERIC: {
		"right_stick_x": JOY_AXIS_RIGHT_X,  # Axis 2 (standard)
		"right_stick_y": JOY_AXIS_RIGHT_Y,  # Axis 3 (standard)
	}
}

# Calibration mode
var calibration_mode: bool = false
var axis_movement_history: Dictionary = {}

func _ready():
	detect_controller_type()

func detect_controller_type():
	"""Detect what controller/platform we're on"""
	# Check if running on Steam Deck
	is_steam_deck = _check_steam_deck()

	if is_steam_deck:
		controller_type = ControllerType.STEAM_DECK
		print("[ControllerMapper] Steam Deck detected")
		if DebugLogger:
			DebugLogger.write_log("[ControllerMapper] Steam Deck detected")
	else:
		# Default to Xbox mapping for PC
		controller_type = ControllerType.XBOX
		print("[ControllerMapper] Using Xbox controller mapping")
		if DebugLogger:
			DebugLogger.write_log("[ControllerMapper] Using Xbox controller mapping")

	# Log connected controllers
	_log_connected_controllers()

func _check_steam_deck() -> bool:
	"""Multiple methods to detect Steam Deck"""
	var os_name = OS.get_name()

	# Method 1: Check if SteamOS/Linux with specific environment
	if os_name == "Linux":
		# Steam Deck runs SteamOS 3.0 (Arch-based)
		# Check for Steam Deck-specific file
		if FileAccess.file_exists("/sys/devices/virtual/dmi/id/product_name"):
			var file = FileAccess.open("/sys/devices/virtual/dmi/id/product_name", FileAccess.READ)
			if file:
				var product = file.get_as_text().strip_edges()
				file.close()
				if "Jupiter" in product:  # Steam Deck codename
					print("[ControllerMapper] Steam Deck detected via product name: %s" % product)
					return true

	# Method 2: Use GodotSteam if available
	if Engine.has_singleton("Steam"):
		if Steam.isSteamRunningOnSteamDeck():
			print("[ControllerMapper] Steam Deck detected via GodotSteam")
			return true

	# Method 3: Check for specific gamepad name patterns
	for i in range(Input.get_connected_joypads().size()):
		var joy_name = Input.get_joy_name(i).to_lower()
		if "valve" in joy_name or "jupiter" in joy_name:
			print("[ControllerMapper] Steam Deck detected via controller name: %s" % Input.get_joy_name(i))
			return true

	return false

func _log_connected_controllers():
	"""Log all connected controllers for debugging"""
	var joypads = Input.get_connected_joypads()
	print("[ControllerMapper] Connected controllers: %d" % joypads.size())

	for device_id in joypads:
		var joy_name = Input.get_joy_name(device_id)
		var joy_guid = Input.get_joy_guid(device_id)
		print("  [%d] %s (GUID: %s)" % [device_id, joy_name, joy_guid])

		if DebugLogger:
			DebugLogger.write_log("Controller %d: %s (GUID: %s)" % [device_id, joy_name, joy_guid])

func get_axis(device: int, axis_name: String) -> float:
	"""Get axis value with platform-specific mapping"""
	var mapping = axis_mappings.get(controller_type, axis_mappings[ControllerType.GENERIC])
	var axis_index = mapping.get(axis_name, -1)

	if axis_index == -1:
		push_warning("[ControllerMapper] Unknown axis: %s" % axis_name)
		return 0.0

	return Input.get_joy_axis(device, axis_index)

func get_axis_raw(device: int, axis_name: String, deadzone: float = 0.15) -> float:
	"""Get axis value with deadzone applied"""
	var value = get_axis(device, axis_name)

	if abs(value) < deadzone:
		return 0.0

	return value

func auto_calibrate_axes(_device: int) -> void:
	"""Automatically detect right stick axes by monitoring movement"""
	print("[ControllerMapper] Starting auto-calibration...")
	print("  Move the RIGHT STICK in circles for 3 seconds...")

	if DebugLogger:
		DebugLogger.write_log("[ControllerMapper] Auto-calibration started")

	calibration_mode = true
	axis_movement_history.clear()

	# Monitor for 3 seconds
	await get_tree().create_timer(3.0).timeout

	# Analyze which axes had most movement
	var sorted_axes = []
	for axis_id in axis_movement_history.keys():
		var total_movement = axis_movement_history[axis_id]
		sorted_axes.append({"id": axis_id, "movement": total_movement})

	sorted_axes.sort_custom(func(a, b): return a.movement > b.movement)

	# Top 2 axes should be right stick
	if sorted_axes.size() >= 2:
		var x_axis = sorted_axes[0].id
		var y_axis = sorted_axes[1].id

		print("[ControllerMapper] Detected right stick: X=%d, Y=%d" % [x_axis, y_axis])

		if DebugLogger:
			DebugLogger.write_log("[ControllerMapper] Calibrated right stick: X=%d, Y=%d" % [x_axis, y_axis])

		# Update mapping
		axis_mappings[controller_type]["right_stick_x"] = x_axis
		axis_mappings[controller_type]["right_stick_y"] = y_axis
	else:
		push_warning("[ControllerMapper] Calibration failed - not enough axis movement detected")
		if DebugLogger:
			DebugLogger.write_log("[ControllerMapper] Calibration FAILED - insufficient movement")

	calibration_mode = false
	print("[ControllerMapper] Calibration complete")

func _process(_delta):
	if not calibration_mode:
		return

	# Track axis movement during calibration
	for axis in range(10):  # Check first 10 axes
		var value = abs(Input.get_joy_axis(0, axis))
		if value > 0.1:  # Movement threshold
			if not axis_movement_history.has(axis):
				axis_movement_history[axis] = 0.0
			axis_movement_history[axis] += value
