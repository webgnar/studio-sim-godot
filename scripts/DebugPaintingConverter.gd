extends Node

## Debug script to test painting conversion with a key press
## Press P to convert the painting

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		print("🟣 DEBUG: P key pressed - converting painting!")
		PaintingSpawner.replace_painting_with_carryable(get_tree().current_scene)
