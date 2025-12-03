extends Node3D

## Root node for 2D painting system
## Wrapper for PaintingSystem2D inside SubViewport
## Input routing now handled by PaintingModeManager

# Inspector variables for tweaking sticker appearance
@export_group("Sticker Settings")
@export_range(0.1, 2.0, 0.05) var sticker_scale: float = 0.5
@export_range(0.0, 1.0, 0.05) var preview_opacity: float = 0.5
@export_range(0.5, 5.0, 0.1) var preview_fade_delay: float = 2.0
@export_range(1.0, 10.0, 0.5) var preview_fade_speed: float = 3.0

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
	painting_system.preview_fade_delay = preview_fade_delay
	painting_system.preview_fade_speed = preview_fade_speed

	# Update preview opacity settings
	painting_system.preview_base_opacity = preview_opacity
	painting_system.preview_target_opacity = preview_opacity
	if painting_system.preview_sprite:
		painting_system.preview_sprite.modulate.a = preview_opacity

	# Refresh preview texture/scale after all settings are applied
	painting_system._update_preview_texture()

# Note: Input forwarding removed - PaintingModeManager now routes input directly
