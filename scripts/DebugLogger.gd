extends Node

## Debug logging singleton for exported builds
## Outputs to console only (no file writing to avoid polluting Steam Cloud sync)

var debug_enabled: bool = false

func _ready():
	# Enable logging in non-editor builds
	if not OS.has_feature("editor"):
		debug_enabled = true
		write_log("=== Debug Log Started ===")
		write_log("Platform: %s" % OS.get_name())
		write_log("Godot Version: %s" % Engine.get_version_info()["string"])
		write_log("User data path: %s" % OS.get_user_data_dir())
		write_log("Executable path: %s" % OS.get_executable_path())
		write_log("Screen size: %s" % DisplayServer.screen_get_size())
		write_log("Window size: %s" % DisplayServer.window_get_size())

func write_log(message: String) -> void:
	if not debug_enabled:
		return
	var timestamp = Time.get_datetime_string_from_system()
	print("[%s] %s" % [timestamp, message])

func log_input_event(event: InputEvent) -> void:
	"""Log input event details for debugging"""
	if not debug_enabled:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		write_log("MouseMotion: relative=%s, velocity=%s, mouse_mode=%s" % [
			motion.relative,
			motion.velocity,
			_mouse_mode_to_string(Input.mouse_mode)
		])
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		write_log("MouseButton: index=%s, pressed=%s, position=%s" % [
			button.button_index,
			button.pressed,
			button.position
		])
	elif event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		write_log("JoypadButton: device=%s, button=%s, pressed=%s" % [
			joy_button.device,
			joy_button.button_index,
			joy_button.pressed
		])
	elif event is InputEventJoypadMotion:
		var joy_motion := event as InputEventJoypadMotion
		# Only log if value is significant (not noise)
		if abs(joy_motion.axis_value) > 0.1:
			write_log("JoypadMotion: device=%s, axis=%s, value=%.3f" % [
				joy_motion.device,
				joy_motion.axis,
				joy_motion.axis_value
			])

func log_controller_info() -> void:
	"""Log all connected controllers"""
	if not debug_enabled:
		return

	var joypads = Input.get_connected_joypads()
	write_log("Connected controllers: %d" % joypads.size())

	for device_id in joypads:
		var joy_name = Input.get_joy_name(device_id)
		var joy_guid = Input.get_joy_guid(device_id)
		write_log("  Device %d: %s (GUID: %s)" % [device_id, joy_name, joy_guid])

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
			return "UNKNOWN(%d)" % mode

func _exit_tree():
	write_log("=== Debug Log Ended ===")
