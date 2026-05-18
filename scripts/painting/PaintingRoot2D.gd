extends Node3D
class_name PaintingRoot2D

## Root node for 2D painting system
## Wrapper for PaintingSystem2D inside SubViewport
## Input routing now handled by PaintingModeManager

# Inspector variables for tweaking sticker appearance
@export_group("Sticker Settings")
@export_range(0.1, 2.0, 0.05) var sticker_scale: float = 0.5
@export_range(0.0, 1.0, 0.05) var preview_opacity: float = 0.5
@export_range(0.5, 5.0, 0.1) var preview_fade_delay: float = 2.0
@export_range(1.0, 10.0, 0.5) var preview_fade_speed: float = 3.0
@export_range(-180.0, 180.0, 1.0) var preview_rotation: float = -90.0

@export_group("Canvas Dimensions")
@export var plane_width: float = 3.0
@export var plane_height: float = 3.0

@onready var painting_system: PaintingSystem2D = $CanvasViewport/CanvasRoot
var _pulse_hint: CanvasPulseHint

const IDLE_TIMEOUT := 10.0

var _idle_timer: float = 0.0
var _idle_running: bool = true

func _process(delta: float) -> void:
	if not _idle_running or not _pulse_hint:
		return
	_idle_timer += delta
	if _idle_timer >= IDLE_TIMEOUT:
		_idle_running = false
		_pulse_hint.show_hint()

func _on_sticker_placed() -> void:
	_idle_timer = 0.0
	_idle_running = true
	if _pulse_hint:
		_pulse_hint.hide_hint()

func _ready():
	if not painting_system:
		push_error("PaintingSystem2D not found!")
		return

	_pulse_hint = get_node_or_null("CanvasPulseHint") as CanvasPulseHint

	painting_system.sticker_placed.connect(_on_sticker_placed)

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

	# Set initial preview rotation (varies per canvas orientation in world space)
	painting_system.preview_rotation = preview_rotation
	if painting_system.preview_sprite:
		painting_system.preview_sprite.rotation_degrees = preview_rotation

	# Refresh preview texture/scale after all settings are applied
	painting_system._update_preview_texture()

# Note: Input forwarding removed - PaintingModeManager now routes input directly
