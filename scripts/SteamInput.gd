extends Node

## Steam Input API wrapper with Godot Input fallback
## Provides unified input interface that automatically uses Steam Input when available
## This is the "InputState" layer that all game code should use

# Action sets
enum ActionSet {
	GAMEPLAY,
	MENU,
	PAINTING
}

var current_action_set: ActionSet = ActionSet.GAMEPLAY

# Action handle mappings (populated when Steam Input initialized)
var action_handles: Dictionary = {}
var analog_action_handles: Dictionary = {}
var action_set_handles: Dictionary = {}

# Input handles for all connected controllers
var input_handles: Array = []

# Current active input handle (primary controller)
var active_input_handle: int = 0

# State tracking for just_pressed/just_released detection
var _previous_states: Dictionary = {}
var _current_states: Dictionary = {}

# Controller polling optimization
var _controller_check_timer: float = 0.0
const CONTROLLER_CHECK_INTERVAL: float = 1.0  # Check for new controllers once per second instead of every frame

func _ready():
	# Wait for SteamManager to initialize
	if SteamManager:
		SteamManager.steam_initialized.connect(_on_steam_initialized)
	else:
		push_warning("[SteamInput] SteamManager not available - using Godot Input fallback")

func _on_steam_initialized(success: bool):
	"""Called when Steam initializes"""
	if success and SteamManager.steam_input_enabled:
		_setup_action_handles()
		print("[SteamInput] Steam Input active - using Steam Input API")
		if DebugLogger:
			DebugLogger.write_log("[SteamInput] Steam Input API enabled")
	else:
		print("[SteamInput] Steam Input not available - using Godot Input fallback")
		if DebugLogger:
			DebugLogger.write_log("[SteamInput] Using Godot Input fallback")

func _setup_action_handles():
	"""Setup action handles for Steam Input"""
	if not SteamManager or not SteamManager.steam_input_enabled:
		return

	# Get input handles for all controllers
	input_handles = Steam.getConnectedControllers()
	if input_handles.size() == 0:
		push_warning("[SteamInput] No controllers connected at startup - handles will be 0")
		if DebugLogger:
			DebugLogger.write_log("[SteamInput] WARNING: No controllers connected")
		# Still set up handles, they'll work when controller connects
	else:
		active_input_handle = input_handles[0]
		print("[SteamInput] Found %d controller(s), using handle: %d" % [input_handles.size(), active_input_handle])

	# Get action set handles
	action_set_handles[ActionSet.GAMEPLAY] = Steam.getActionSetHandle("gameplay")
	action_set_handles[ActionSet.MENU] = Steam.getActionSetHandle("menu")
	action_set_handles[ActionSet.PAINTING] = Steam.getActionSetHandle("painting")

	# Validate action set handles
	for action_set in action_set_handles.keys():
		if action_set_handles[action_set] == 0:
			push_warning("[SteamInput] Failed to get action set handle: %s" % ActionSet.keys()[action_set])

	# Get digital action handles
	action_handles["jump"] = Steam.getDigitalActionHandle("jump")
	action_handles["sprint"] = Steam.getDigitalActionHandle("sprint")
	action_handles["interact"] = Steam.getDigitalActionHandle("interact")
	action_handles["action_primary"] = Steam.getDigitalActionHandle("action_primary")
	action_handles["action_secondary"] = Steam.getDigitalActionHandle("action_secondary")
	action_handles["go_back"] = Steam.getDigitalActionHandle("go_back")

	# Painting actions
	action_handles["rotate_clockwise"] = Steam.getDigitalActionHandle("rotate_clockwise")
	action_handles["rotate_counter"] = Steam.getDigitalActionHandle("rotate_counter")
	action_handles["scale_up"] = Steam.getDigitalActionHandle("scale_up")
	action_handles["scale_down"] = Steam.getDigitalActionHandle("scale_down")
	action_handles["cycle_next"] = Steam.getDigitalActionHandle("cycle_next")
	action_handles["cycle_prev"] = Steam.getDigitalActionHandle("cycle_prev")

	# UI actions
	action_handles["menu_select"] = Steam.getDigitalActionHandle("menu_select")
	action_handles["menu_back"] = Steam.getDigitalActionHandle("menu_back")

	# Validate digital action handles
	var invalid_count = 0
	for action_name in action_handles.keys():
		if action_handles[action_name] == 0:
			push_warning("[SteamInput] Failed to get digital action handle: %s" % action_name)
			invalid_count += 1

	# Get analog action handles
	analog_action_handles["move"] = Steam.getAnalogActionHandle("move")
	analog_action_handles["camera"] = Steam.getAnalogActionHandle("camera")
	analog_action_handles["menu_navigate"] = Steam.getAnalogActionHandle("menu_navigate")

	# Validate analog action handles
	for action_name in analog_action_handles.keys():
		if analog_action_handles[action_name] == 0:
			push_warning("[SteamInput] Failed to get analog action handle: %s" % action_name)
			invalid_count += 1

	if invalid_count > 0:
		push_warning("[SteamInput] %d action handles failed - check steam_input_manifest.vdf" % invalid_count)
		if DebugLogger:
			DebugLogger.write_log("[SteamInput] %d invalid handles - VDF may be incorrect" % invalid_count)
	else:
		print("[SteamInput] All action handles validated successfully")

	# Activate default action set
	activate_action_set(ActionSet.GAMEPLAY)

func activate_action_set(action_set: ActionSet):
	"""Switch to a different action set"""
	current_action_set = action_set

	if not _is_steam_input_active():
		return

	var handle = action_set_handles.get(action_set, 0)
	if handle != 0:
		Steam.activateActionSet(active_input_handle, handle)
		print("[SteamInput] Activated action set: %s" % ActionSet.keys()[action_set])
		if DebugLogger:
			DebugLogger.write_log("[SteamInput] Action set: %s" % ActionSet.keys()[action_set])

func _is_steam_input_active() -> bool:
	"""Check if Steam Input is available and active"""
	return SteamManager and SteamManager.steam_input_enabled and active_input_handle != 0

# ===== PUBLIC API (compatible with Godot Input) =====

func is_action_pressed(action_name: String) -> bool:
	"""Check if action is currently pressed"""
	if _is_steam_input_active():
		return _get_steam_digital_action_state(action_name)
	else:
		# Fallback to Godot Input
		return Input.is_action_pressed(action_name)

func is_action_just_pressed(action_name: String) -> bool:
	"""Check if action was just pressed this frame"""
	if _is_steam_input_active():
		# Use state tracking for edge detection
		var current = _current_states.get(action_name, false)
		var previous = _previous_states.get(action_name, false)
		return current and not previous
	else:
		# Fallback to Godot Input
		return Input.is_action_just_pressed(action_name)

func is_action_just_released(action_name: String) -> bool:
	"""Check if action was just released this frame"""
	if _is_steam_input_active():
		# Use state tracking for edge detection
		var current = _current_states.get(action_name, false)
		var previous = _previous_states.get(action_name, false)
		return not current and previous
	else:
		# Fallback to Godot Input
		return Input.is_action_just_released(action_name)

func get_vector(negative_x: String, positive_x: String, negative_y: String, positive_y: String, deadzone: float = -1.0) -> Vector2:
	"""Get input vector (for movement)"""
	if _is_steam_input_active():
		# Use Steam Input analog action "move"
		var move_data = _get_steam_analog_action("move")
		return Vector2(move_data.x, move_data.y)
	else:
		# Fallback to Godot Input
		if ControllerMapper:
			# For controller input, use ControllerMapper
			var joypads = Input.get_connected_joypads()
			if joypads.size() > 0:
				var x = Input.get_axis(negative_x, positive_x)
				var y = Input.get_axis(negative_y, positive_y)
				return Vector2(x, y)

		return Input.get_vector(negative_x, positive_x, negative_y, positive_y, deadzone)

func get_analog_action(action_name: String) -> Vector2:
	"""Get analog action data (for camera, movement, etc.)"""
	if _is_steam_input_active():
		return _get_steam_analog_action(action_name)
	else:
		# Fallback to controller axes via ControllerMapper
		if action_name == "camera" and ControllerMapper:
			var x = ControllerMapper.get_axis_raw(0, "right_stick_x", 0.15)
			var y = ControllerMapper.get_axis_raw(0, "right_stick_y", 0.15)
			return Vector2(x, y)
		elif action_name == "move":
			return get_vector("move_left", "move_right", "move_forward", "move_back")

	return Vector2.ZERO

# ===== PRIVATE STEAM INPUT HELPERS =====

func _get_steam_digital_action_state(action_name: String) -> bool:
	"""Get digital action state from Steam Input"""
	var handle = action_handles.get(action_name, 0)
	if handle == 0:
		# Action not found, fallback to Godot Input
		return Input.is_action_pressed(action_name)

	var data = Steam.getDigitalActionData(active_input_handle, handle)
	return data.state if data else false

func _get_steam_analog_action(action_name: String) -> Vector2:
	"""Get analog action data from Steam Input"""
	var handle = analog_action_handles.get(action_name, 0)
	if handle == 0:
		return Vector2.ZERO

	var data = Steam.getAnalogActionData(active_input_handle, handle)
	if data:
		return Vector2(data.x, data.y)

	return Vector2.ZERO

func _process(_delta):
	# Update state tracking for edge detection (before any input reads)
	if _is_steam_input_active():
		# Save current states as previous (shallow copy is fine - we only store bools)
		_previous_states = _current_states
		_current_states = {}

		# Update current states for all actions
		for action_name in action_handles.keys():
			_current_states[action_name] = _get_steam_digital_action_state(action_name)

	# Update active input handle if controllers change (OPTIMIZED: only check once per second)
	if _is_steam_input_active():
		_controller_check_timer += _delta
		if _controller_check_timer >= CONTROLLER_CHECK_INTERVAL:
			_controller_check_timer = 0.0
			var connected = Steam.getConnectedControllers()
			if connected.size() > 0 and connected[0] != active_input_handle:
				active_input_handle = connected[0]
				print("[SteamInput] Active controller changed to handle: %d" % active_input_handle)
				# Reactivate current action set for new controller
				activate_action_set(current_action_set)
