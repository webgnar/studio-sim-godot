extends Node

## Global Input Device Manager
## Tracks which input device the player is currently using (keyboard/mouse vs gamepad)
## and provides appropriate button glyphs for UI prompts

# Device types
enum DeviceType {
	KEYBOARD_MOUSE,  # Keyboard + Mouse input
	GAMEPAD          # Xbox-style gamepad
}

# Current active device (defaults to keyboard/mouse)
var current_device: DeviceType = DeviceType.KEYBOARD_MOUSE

# Signal emitted when device type changes
signal device_changed(new_device: DeviceType)

# Internal: track last device to prevent signal spam
var _last_device: DeviceType = DeviceType.KEYBOARD_MOUSE

# Glyph mappings: action_name -> {keyboard: "text", gamepad: "text"}
var glyph_map: Dictionary = {}


func _ready() -> void:
	_initialize_glyph_map()
	print("InputDeviceManager initialized - default device: KEYBOARD_MOUSE")


func _input(event: InputEvent) -> void:
	# Detect input device type from event
	var detected_device: DeviceType = current_device

	if event is InputEventKey or event is InputEventMouseButton:
		# Keyboard or mouse button (not motion to avoid false positives)
		detected_device = DeviceType.KEYBOARD_MOUSE
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Gamepad button or stick/trigger motion
		detected_device = DeviceType.GAMEPAD

	# Only emit signal if device actually changed
	if detected_device != _last_device:
		_last_device = detected_device
		current_device = detected_device
		device_changed.emit(current_device)


func _initialize_glyph_map() -> void:
	"""Initialize the mapping of input actions to display glyphs"""
	glyph_map = {
		# Primary interaction key
		"interact": {
			"keyboard": "E",
			"gamepad": "X"  # Button 2 on Xbox = X
		},

		# Primary action (shoot/throw/pick up)
		"action_primary": {
			"keyboard": "Left Click",
			"gamepad": "RT"  # Right Trigger (axis 5)
		},

		# Secondary action (drop)
		"action_secondary": {
			"keyboard": "Right Click",
			"gamepad": "LT"  # Left Trigger (axis 4)
		},

		# Jump
		"jump": {
			"keyboard": "Space",
			"gamepad": "A"  # Button 0 on Xbox = A
		},

		# Run/sprint
		"run": {
			"keyboard": "Shift",
			"gamepad": "LS"  # Left Stick Click (button 7)
		},

		# Back/cancel
		"go_back": {
			"keyboard": "B",
			"gamepad": "B"  # Button 1 on Xbox = B
		},

		# Sticker cycling
		"cycle_sticker_next": {
			"keyboard": "Mouse Wheel Down",
			"gamepad": "RB"  # Right Bumper (button 10)
		},
		"cycle_sticker_prev": {
			"keyboard": "Mouse Wheel Up",
			"gamepad": "LB"  # Left Bumper (button 9)
		},

		# Pause/start
		"start": {
			"keyboard": "`",
			"gamepad": "Start"  # Button 6
		}
	}


func get_action_glyph(action_name: String) -> String:
	"""
	Get the display glyph for an action based on current device
	Returns the button/key text without brackets (e.g., "E" or "X")
	"""
	if not glyph_map.has(action_name):
		push_warning("InputDeviceManager: Unknown action '%s'" % action_name)
		return "?"

	var action_glyphs = glyph_map[action_name]

	match current_device:
		DeviceType.KEYBOARD_MOUSE:
			return action_glyphs.get("keyboard", "?")
		DeviceType.GAMEPAD:
			return action_glyphs.get("gamepad", "?")
		_:
			return "?"


func get_formatted_prompt(action_name: String, label: String = "") -> String:
	"""
	Get a formatted prompt string with brackets (e.g., "[E]" or "[X] Interact")
	If label is provided, returns "[E] Label", otherwise just "[E]"
	"""
	var glyph = get_action_glyph(action_name)

	if label.is_empty():
		return "[%s]" % glyph
	else:
		return "[%s] %s" % [glyph, label]
