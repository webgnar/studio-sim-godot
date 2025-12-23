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
	# Icon paths for gamepad glyphs
	var icon_path = "res://sprites/ui/"

	glyph_map = {
		# Primary interaction key
		"interact": {
			"keyboard": "E",
			"gamepad": "X",
			"gamepad_icon": icon_path + "x.png"
		},

		# Primary action (shoot/throw/pick up)
		"action_primary": {
			"keyboard": "Left Click",
			"gamepad": "RT",
			"gamepad_icon": icon_path + "rt.png"
		},

		# Secondary action (drop)
		"action_secondary": {
			"keyboard": "Right Click",
			"gamepad": "LT",
			"gamepad_icon": icon_path + "lt.png"
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

		# Rotation controls (used for both 2D painting and 3D carryable rotation)
		"rotate_clockwise": {
			"keyboard": "T",
			"gamepad": "D-Pad Right",
			"gamepad_icon": icon_path + "leftright.png"
		},
		"rotate_counter": {
			"keyboard": "R",
			"gamepad": "D-Pad Left",
			"gamepad_icon": icon_path + "leftright.png"
		},

		# Scale controls (2D painting size, also used for X-axis rotation on carryables)
		"scale_sticker_up": {
			"keyboard": "Z",
			"gamepad": "D-Pad Up",
			"gamepad_icon": icon_path + "updown.png"
		},
		"scale_sticker_down": {
			"keyboard": "X",
			"gamepad": "D-Pad Down",
			"gamepad_icon": icon_path + "updown.png"
		},

		# Sticker cycling
		"cycle_sticker_next": {
			"keyboard": "2",
			"gamepad": "RB",
			"gamepad_icon": icon_path + "rb.png"
		},
		"cycle_sticker_prev": {
			"keyboard": "1",
			"gamepad": "LB",
			"gamepad_icon": icon_path + "lb.png"
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

func get_bbcode_glyph(action_name: String) -> String:
	"""
	Get a BBCode-formatted glyph for RichTextLabel
	For keyboard: returns text in brackets like "[T]"
	For gamepad: returns inline image like "[img=20]res://sprites/ui/leftright.png[/img]"
	"""
	if not glyph_map.has(action_name):
		push_warning("InputDeviceManager: Unknown action '%s'" % action_name)
		return "[?]"

	var action_glyphs = glyph_map[action_name]

	match current_device:
		DeviceType.KEYBOARD_MOUSE:
			var text = action_glyphs.get("keyboard", "?")
			return "[%s]" % text
		DeviceType.GAMEPAD:
			var icon_path = action_glyphs.get("gamepad_icon", "")
			if icon_path != "":
				return "[img=20]%s[/img]" % icon_path
			else:
				# Fallback to text if no icon
				var text = action_glyphs.get("gamepad", "?")
				return "[%s]" % text
		_:
			return "[?]"
