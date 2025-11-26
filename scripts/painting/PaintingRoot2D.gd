extends Node3D

## Root node for 2D painting system
## Wrapper for PaintingSystem2D inside SubViewport
## Input routing now handled by PaintingModeManager

@onready var painting_system: PaintingSystem2D = $CanvasViewport/CanvasRoot

func _ready():
	if not painting_system:
		push_error("PaintingSystem2D not found!")

# Note: Input forwarding removed - PaintingModeManager now routes input directly
