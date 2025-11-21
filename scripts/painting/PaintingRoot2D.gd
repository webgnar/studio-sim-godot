extends Node3D

## Root node for 2D painting system
## Handles 3D input and forwards to the PaintingSystem2D inside SubViewport

@onready var painting_system: PaintingSystem2D = $CanvasViewport/CanvasRoot

func _ready():
	if not painting_system:
		push_error("PaintingSystem2D not found!")

	set_process_input(true)

func _input(event):
	if not painting_system:
		return

	# Forward input to the painting system
	painting_system._input(event)

# Note: Don't forward _process - Godot calls it automatically on the Node2D
