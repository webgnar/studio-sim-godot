extends Node3D

## Root node for 2D painting system
## Wrapper for PaintingSystem2D inside SubViewport
## Input routing now handled by PaintingModeManager

# Inspector variables for tweaking sticker appearance
@export_group("Sticker Settings")
@export_range(0.1, 2.0, 0.05) var sticker_scale: float = 0.5
@export_range(0.0, 1.0, 0.05) var preview_opacity: float = 0.5

@export_group("Canvas Dimensions")
@export var plane_width: float = 3.0
@export var plane_height: float = 3.0

@onready var painting_system: PaintingSystem2D = $CanvasViewport/CanvasRoot

func _ready():
	if not painting_system:
		push_error("PaintingSystem2D not found!")
		return

	# Apply inspector values to painting system
	painting_system.sticker_scale = sticker_scale
	painting_system.plane_width = plane_width
	painting_system.plane_height = plane_height

	# Update preview opacity if preview sprite exists
	if painting_system.preview_sprite:
		painting_system.preview_sprite.modulate.a = preview_opacity

# Note: Input forwarding removed - PaintingModeManager now routes input directly
