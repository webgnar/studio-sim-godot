extends Control
class_name CircularProgressBar

## Circular arc progress bar drawn entirely in code via draw_arc().
## Set `value` (0-100) to update the arc.

@export var value: float = 0.0 : set = _set_value
@export var radius: float = 80.0
@export var ring_width: float = 14.0
@export var background_color: Color = Color(0.15, 0.15, 0.15, 0.85)
@export var fill_color: Color = Color(1.0, 0.85, 0.2, 1.0)
@export var show_percentage: bool = false

const TAU_DEG = 360.0
const START_ANGLE_DEG = -90.0

func _set_value(v: float) -> void:
	value = clampf(v, 0.0, 100.0)
	queue_redraw()

func _draw() -> void:
	var center = size / 2.0
	var point_count = 64

	# Background ring
	draw_arc(center, radius, deg_to_rad(START_ANGLE_DEG), deg_to_rad(START_ANGLE_DEG + TAU_DEG), point_count, background_color, ring_width, true)

	# Progress arc
	if value > 0.0:
		var end_angle = START_ANGLE_DEG + (TAU_DEG * value / 100.0)
		draw_arc(center, radius, deg_to_rad(START_ANGLE_DEG), deg_to_rad(end_angle), point_count, fill_color, ring_width, true)

	# Center percentage text
	if show_percentage:
		var pct_text = "%d%%" % int(value)
		var font = ThemeDB.fallback_font
		var font_size = 28
		var text_size = font.get_string_size(pct_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = center - text_size / 2.0
		draw_string(font, text_pos, pct_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
