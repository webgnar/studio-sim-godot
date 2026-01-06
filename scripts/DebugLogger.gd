extends Node

## Debug logging singleton for exported builds
## Writes logs to user://debug.log for post-export diagnostics

const LOG_PATH = "user://debug.log"
var log_file: FileAccess = null
var debug_enabled: bool = false

func _ready():
	# Enable logging in non-editor builds
	if not OS.has_feature("editor"):
		debug_enabled = true
		log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)

		if log_file:
			var log_full_path = OS.get_user_data_dir() + "/debug.log"
			write_log("=== Debug Log Started ===")
			write_log("LOG FILE LOCATION: %s" % log_full_path)
			write_log("Platform: %s" % OS.get_name())
			write_log("Godot Version: %s" % Engine.get_version_info()["string"])
			write_log("User data path: %s" % OS.get_user_data_dir())
			write_log("Executable path: %s" % OS.get_executable_path())

			# Log display info
			write_log("Screen size: %s" % DisplayServer.screen_get_size())
			write_log("Window size: %s" % DisplayServer.window_get_size())

			# Print to console prominently
			print("\n" + "=".repeat(80))
			print("DEBUG LOG FILE LOCATION:")
			print(log_full_path)
			print("=".repeat(80) + "\n")
		else:
			push_error("DebugLogger: Failed to open log file at %s" % LOG_PATH)

func write_log(message: String) -> void:
	"""Log a message to both console and file"""
	if not debug_enabled:
		return

	var timestamp = Time.get_datetime_string_from_system()
	var log_line = "[%s] %s" % [timestamp, message]

	# Always print to console (shows in export console wrapper)
	print(log_line)

	# Write to file if available
	if log_file:
		log_file.store_line(log_line)
		log_file.flush()  # Ensure written immediately

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
	if log_file:
		write_log("=== Debug Log Ended ===")
		log_file.close()
