extends CanvasLayer

## Visual debug overlay for controller and input debugging
## Toggle with F4 key

var panel: PanelContainer
var label: Label
var visible_in_export: bool = false  # Hidden by default, toggle with F4

# Performance optimization: update UI less frequently
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  # Update 10 times per second instead of 60 (saves ~83% of processing)

func _ready():
	_create_ui()
	visible = visible_in_export

	# In editor, mention it's available
	if OS.has_feature("editor"):
		print("[ControllerDebugOverlay] Ready - Press F4 to toggle input debug overlay")

func _create_ui():
	# Create background panel
	panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.modulate = Color(1, 1, 1, 0.85)  # Slightly transparent
	add_child(panel)

	# Create label with monospace font
	label = Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)

	# Set layer to render on top of everything
	layer = 128

func _process(_delta):
	if not visible:
		return

	# Performance optimization: only update UI every UPDATE_INTERVAL seconds
	_update_timer += _delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	var text = "╔════════════════════════════════════════╗\n"
	text += "║     INPUT DEBUG OVERLAY (F4)           ║\n"
	text += "╚════════════════════════════════════════╝\n\n"

	# Platform info
	text += "┌─ PLATFORM ────────────────────────────┐\n"
	text += "│ OS: %s\n" % OS.get_name()
	if ControllerMapper:
		text += "│ Controller Type: %s\n" % ControllerMapper.ControllerType.keys()[ControllerMapper.controller_type]
		text += "│ Steam Deck: %s\n" % ("✓ YES" if ControllerMapper.is_steam_deck else "✗ NO")
	text += "└───────────────────────────────────────┘\n\n"

	# Mouse info
	text += "┌─ MOUSE ───────────────────────────────┐\n"
	text += "│ Mode: %s\n" % _mouse_mode_to_string(Input.mouse_mode)
	var mouse_pos = get_viewport().get_mouse_position()
	text += "│ Position: (%.0f, %.0f)\n" % [mouse_pos.x, mouse_pos.y]
	text += "└───────────────────────────────────────┘\n\n"

	# Controller info
	var joypads = Input.get_connected_joypads()
	text += "┌─ CONTROLLERS (%d) ────────────────────┐\n" % joypads.size()

	if joypads.is_empty():
		text += "│ ⚠ No controllers connected\n"
		text += "│ Game will use keyboard/mouse only\n"
		text += "└───────────────────────────────────────┘\n\n"
	else:
		var device = 0
		var controller_name = Input.get_joy_name(device)
		# Truncate long names
		if controller_name.length() > 35:
			controller_name = controller_name.substr(0, 32) + "..."
		text += "│ Device 0: %s\n" % controller_name
		text += "├───────────────────────────────────────┤\n"

		# Show all non-zero axes in a compact table
		text += "│ AXES (showing active only):\n"
		var has_axis_input = false
		for axis in range(10):  # Check first 10 axes
			var value = Input.get_joy_axis(device, axis)
			if abs(value) > 0.01:  # Only show non-zero
				var bar = _create_bar(value, 15)
				text += "│  Axis %d: %s %6.3f" % [axis, bar, value]
				# Highlight special axes
				if axis == JOY_AXIS_LEFT_X:
					text += " (L-Stick X)"
				elif axis == JOY_AXIS_LEFT_Y:
					text += " (L-Stick Y)"
				elif axis == JOY_AXIS_RIGHT_X:
					text += " (R-Stick X)"
				elif axis == JOY_AXIS_RIGHT_Y:
					text += " (R-Stick Y)"
				elif axis == JOY_AXIS_TRIGGER_LEFT:
					text += " (L-Trigger)"
				elif axis == JOY_AXIS_TRIGGER_RIGHT:
					text += " (R-Trigger)"
				text += "\n"
				has_axis_input = true

		if not has_axis_input:
			text += "│  (no movement detected)\n"

		# Show ControllerMapper right stick
		text += "├───────────────────────────────────────┤\n"
		text += "│ RIGHT STICK (via ControllerMapper):\n"
		if ControllerMapper:
			var rx = ControllerMapper.get_axis(device, "right_stick_x")
			var ry = ControllerMapper.get_axis(device, "right_stick_y")
			text += "│  X: %s %.3f\n" % [_create_bar(rx, 15), rx]
			text += "│  Y: %s %.3f\n" % [_create_bar(ry, 15), ry]
		else:
			text += "│  ⚠ ControllerMapper not available\n"

		# Show pressed buttons in a compact list
		text += "├───────────────────────────────────────┤\n"
		text += "│ BUTTONS (pressed):\n"
		var pressed_buttons = []
		for button in range(20):  # Check first 20 buttons
			if Input.is_joy_button_pressed(device, button):
				pressed_buttons.append(button)

		if pressed_buttons.is_empty():
			text += "│  (none)\n"
		else:
			# Group buttons in rows of 6
			var button_text = "│  "
			for i in range(pressed_buttons.size()):
				button_text += "%2d " % pressed_buttons[i]
				if (i + 1) % 6 == 0 and i < pressed_buttons.size() - 1:
					button_text += "\n│  "
			text += button_text + "\n"

		text += "└───────────────────────────────────────┘\n\n"

	# Steam Input status
	text += "┌─ STEAM INPUT ─────────────────────────┐\n"
	if SteamManager and SteamManager.steam_input_enabled:
		text += "│ Status: ✓ ENABLED\n"
		if SteamInput:
			text += "│ Action Set: %s\n" % SteamInput.ActionSet.keys()[SteamInput.current_action_set]
			text += "│ Input Source: Steam Input API\n"
	else:
		text += "│ Status: ✗ Not available\n"
		text += "│ Input Source: Godot Input\n"
		if ControllerMapper:
			text += "│ Using: ControllerMapper fallback\n"
	text += "└───────────────────────────────────────┘\n\n"

	# Input actions (sample) - show important ones
	text += "┌─ INPUT ACTIONS ───────────────────────┐\n"
	var sample_actions = [
		["jump", "Jump"],
		["interact", "Interact"],
		["action_primary", "Primary"],
		["action_secondary", "Secondary"],
		["move_forward", "Move Fwd"],
		["run", "Sprint"]
	]
	for action_pair in sample_actions:
		var action = action_pair[0]
		var display = action_pair[1]
		if InputMap.has_action(action):
			var pressed = Input.is_action_pressed(action)
			var status = "●" if pressed else "○"
			text += "│ %s %-12s %s\n" % [status, display, "PRESSED" if pressed else ""]
	text += "└───────────────────────────────────────┘\n"

	# Add FPS counter
	text += "\n"
	text += "FPS: %.0f | Frame Time: %.1fms\n" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000]

	label.text = text

func _input(event):
	# Toggle with F4
	if event is InputEventKey:
		if event.keycode == KEY_F4 and event.pressed and not event.echo:
			visible = not visible
			visible_in_export = visible
			print("[ControllerDebugOverlay] Toggled: %s (F4)" % ("visible" if visible else "hidden"))

func _create_bar(value: float, width: int = 15) -> String:
	"""Create a visual bar representation of a value (-1 to 1)"""
	var center = int(width / 2.0)
	var bar_pos = int(center + (value * center))
	bar_pos = clamp(bar_pos, 0, width - 1)

	var bar = ""
	for i in range(width):
		if i == center:
			bar += "|"
		elif i == bar_pos:
			bar += "█"
		else:
			bar += "─"
	return bar

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
