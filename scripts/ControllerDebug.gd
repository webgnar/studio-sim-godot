extends Node

## Controller input debug tool
## Attach this to any node to see what controller inputs are being detected

func _ready():
	print("=== Controller Debug Active ===")
	print("Press any button or move any stick to see input details")

	# Check for connected joypads
	var joypads = Input.get_connected_joypads()
	if joypads.is_empty():
		print("WARNING: No controllers detected!")
	else:
		for joypad_id in joypads:
			var name = Input.get_joy_name(joypad_id)
			print("Controller %d detected: %s" % [joypad_id, name])

func _input(event):
	# Log all joypad button presses
	if event is InputEventJoypadButton:
		print("Button %d - Pressed: %s - Pressure: %.2f" % [
			event.button_index,
			event.pressed,
			event.pressure
		])

	# Log all joypad axis movements (filter out tiny values to reduce noise)
	if event is InputEventJoypadMotion:
		if abs(event.axis_value) > 0.1:  # Deadzone to avoid drift spam
			print("Axis %d - Value: %.2f" % [
				event.axis,
				event.axis_value
			])
