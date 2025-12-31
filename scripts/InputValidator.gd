extends Node

## Input system validator for exported builds
## Runs validation on startup to diagnose input issues

func _ready():
	# Run validation in exported builds after a short delay
	if not OS.has_feature("editor"):
		# Wait for other systems to initialize
		await get_tree().create_timer(1.0).timeout
		validate_input_system()

func validate_input_system():
	"""Validate input system configuration and log results"""
	print("========================================")
	print("=== Input System Validation ===")
	print("========================================")

	# Check 1: Platform information
	_validate_platform()

	# Check 2: Mouse mode
	_validate_mouse_mode()

	# Check 3: Input actions
	_validate_input_actions()

	# Check 4: Controller detection
	_validate_controllers()

	# Check 5: Display information
	_validate_display()

	print("========================================")
	print("=== Validation Complete ===")
	print("========================================")

	# Log to DebugLogger if available
	if DebugLogger:
		DebugLogger.write_log("Input validation completed")
		DebugLogger.log_controller_info()

func _validate_platform():
	"""Validate platform information"""
	print("\n[Platform]")
	print("  OS: %s" % OS.get_name())
	print("  Processor: %s" % OS.get_processor_name())
	print("  Model: %s" % OS.get_model_name())
	print("  Locale: %s" % OS.get_locale())

	if DebugLogger:
		DebugLogger.write_log("Platform: %s" % OS.get_name())

func _validate_mouse_mode():
	"""Validate mouse mode configuration"""
	print("\n[Mouse]")
	var mouse_mode = Input.mouse_mode
	var mode_str = _mouse_mode_to_string(mouse_mode)
	print("  Mouse mode: %s (%d)" % [mode_str, mouse_mode])

	if mouse_mode != Input.MOUSE_MODE_CAPTURED:
		push_warning("  ⚠ Mouse not captured! Expected CAPTURED for gameplay")
	else:
		print("  ✓ Mouse captured correctly")

	if DebugLogger:
		DebugLogger.write_log("Mouse mode: %s" % mode_str)

func _validate_input_actions():
	"""Validate required input actions exist"""
	print("\n[Input Actions]")

	var required_actions = [
		"move_forward", "move_back", "move_left", "move_right",
		"jump", "run",
		"interact", "action_primary", "action_secondary", "go_back",
		"ui_up", "ui_down", "ui_left", "ui_right",
		"rotate_clockwise", "rotate_counter",
		"scale_sticker_up", "scale_sticker_down",
		"cycle_sticker_next", "cycle_sticker_prev"
	]

	var missing_actions = []
	for action in required_actions:
		if InputMap.has_action(action):
			print("  ✓ '%s'" % action)
		else:
			print("  ✗ '%s' MISSING!" % action)
			missing_actions.append(action)
			push_error("Input action '%s' is missing from InputMap!" % action)

	if missing_actions.is_empty():
		print("  All %d required actions present" % required_actions.size())
	else:
		print("  ⚠ %d actions missing: %s" % [missing_actions.size(), missing_actions])

func _validate_controllers():
	"""Validate controller detection and configuration"""
	print("\n[Controllers]")

	var joypads = Input.get_connected_joypads()
	print("  Connected: %d" % joypads.size())

	if joypads.is_empty():
		print("  ⚠ No controllers detected")
		print("    - Game will work with keyboard/mouse only")
		print("    - Connect a controller and restart to test gamepad")
	else:
		for device_id in joypads:
			var joy_name = Input.get_joy_name(device_id)
			var joy_guid = Input.get_joy_guid(device_id)
			print("  Device %d:" % device_id)
			print("    Name: %s" % joy_name)
			print("    GUID: %s" % joy_guid)

			# Check right stick rest position
			var rx = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
			var ry = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
			print("    Right stick rest: X=%.3f, Y=%.3f" % [rx, ry])

			if abs(rx) > 0.2 or abs(ry) > 0.2:
				push_warning("    ⚠ Right stick not centered - may have drift or calibration issue")
			else:
				print("    ✓ Right stick centered")

func _validate_display():
	"""Validate display configuration"""
	print("\n[Display]")
	print("  Screen size: %s" % DisplayServer.screen_get_size())
	print("  Window size: %s" % DisplayServer.window_get_size())
	print("  Window mode: %s" % _window_mode_to_string(DisplayServer.window_get_mode()))
	print("  VSync: %s" % DisplayServer.window_get_vsync_mode())

func _mouse_mode_to_string(mode: int) -> String:
	match mode:
		Input.MOUSE_MODE_VISIBLE:
			return "VISIBLE"
		Input.MOUSE_MODE_HIDDEN:
			return "HIDDEN"
		Input.MOUSE_MODE_CAPTURED:
			return "CAPTURED"
		Input.MOUSE_MODE_CONFINED:
			return "CONFINED"
		_:
			return "UNKNOWN"

func _window_mode_to_string(mode: int) -> String:
	match mode:
		DisplayServer.WINDOW_MODE_WINDOWED:
			return "WINDOWED"
		DisplayServer.WINDOW_MODE_MINIMIZED:
			return "MINIMIZED"
		DisplayServer.WINDOW_MODE_MAXIMIZED:
			return "MAXIMIZED"
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return "FULLSCREEN"
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return "EXCLUSIVE_FULLSCREEN"
		_:
			return "UNKNOWN"
