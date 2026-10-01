class_name LouGnarJumpMeter
extends Control
## Circular "POP" gauge showing remaining jumps (of 3).

const SIZE := Vector2(80, 80)
const RADIUS := 30.0
const MAX_JUMPS := 3.0

var _percentage: float = 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func snap(jumps: float) -> void:
	_percentage = jumps / MAX_JUMPS
	queue_redraw()


func update(dt: float, jumps: float) -> void:
	var target := jumps / MAX_JUMPS
	# Original lerps 0.2 per frame at 60fps; keep that feel at any frame rate.
	_percentage += (target - _percentage) * (1.0 - pow(0.8, dt * 60.0))
	if absf(target - _percentage) < 0.01:
		_percentage = target
	queue_redraw()


func _draw() -> void:
	var c := SIZE / 2.0
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color("#666666"), 4.0, true)

	if _percentage > 0.0:
		var start := -PI / 2.0
		var end := start + TAU * _percentage
		var points := PackedVector2Array([c])
		var steps := maxi(2, int(48.0 * _percentage))
		for i in steps + 1:
			var a := lerpf(start, end, float(i) / steps)
			points.append(c + Vector2(cos(a), sin(a)) * RADIUS)
		draw_colored_polygon(points, LouGnarUI.LIME)
		draw_arc(c, RADIUS, start, end, 48, Color.WHITE, 4.0, true)

	var font := LouGnarAssets.FONT
	var text_size := font.get_string_size("POP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	var baseline := c.y + 5.0 + (font.get_ascent(24) - font.get_descent(24)) / 2.0
	var origin := Vector2(c.x - text_size.x / 2.0, baseline)
	draw_string_outline(font, origin, "POP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 4, Color.BLACK)
	draw_string(font, origin, "POP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
