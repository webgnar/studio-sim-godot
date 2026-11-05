class_name StrokeRenderer
extends SubViewport

## The painted canvas: a texture that ink accumulates on, stroke by stroke.
##
## Never cleared between frames, so each frame only draws the ink laid since
## the last one (PlotPlayer.advance_to); cost per frame stays small however
## much of the painting is done. Strokes are drawn at the tool's width with
## round ends, in canvas mm scaled by px_per_mm.

var canvas_mm := Vector2(1830, 1220)
var px_per_mm := 2.0
var tool_width_mm := 2.0
var paper := Color.WHITE

var _ink: Node2D
var _pending: Array = []
var _blank_frames := 3   ## frames that paint bare paper first (the very first ones can be skipped)


func _init(p_canvas_mm := Vector2(1830, 1220), p_px_per_mm := 2.0, p_tool_width_mm := 2.0) -> void:
	canvas_mm = p_canvas_mm
	px_per_mm = p_px_per_mm
	tool_width_mm = p_tool_width_mm
	size = Vector2i(ceili(canvas_mm.x * px_per_mm), ceili(canvas_mm.y * px_per_mm))
	disable_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_ink = Node2D.new()
	_ink.draw.connect(_draw_ink)
	add_child(_ink)


## Wipes the canvas back to bare paper.
func clear() -> void:
	_pending.clear()
	_blank_frames = 3
	_ink.queue_redraw()


## False while the canvas is still being wiped: hold ink back until then.
func is_ready() -> bool:
	return _blank_frames <= 0


func _process(_delta: float) -> void:
	if _blank_frames > 0:
		_ink.queue_redraw()


## Queues ink for the next frame: Array of {color, points (canvas mm)}.
func paint(chunks: Array) -> void:
	if chunks.is_empty():
		return
	_pending.append_array(chunks)
	_ink.queue_redraw()


func _draw_ink() -> void:
	if _blank_frames > 0:
		_ink.draw_rect(Rect2(Vector2.ZERO, Vector2(size)), paper)
		_blank_frames -= 1
		return
	var w := maxf(tool_width_mm * px_per_mm, 1.0)
	var r := w * 0.5
	for c in _pending:
		var pts: PackedVector2Array = c.points
		var scaled := PackedVector2Array()
		scaled.resize(pts.size())
		for i in pts.size():
			scaled[i] = pts[i] * px_per_mm
		if scaled.size() >= 2:
			_ink.draw_polyline(scaled, c.color, w)
		if w >= 2.5:
			# Round ends and joints, like a marker tip
			for p in scaled:
				_ink.draw_circle(p, r, c.color)
	_pending.clear()
