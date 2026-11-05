class_name PlotPlayer
extends RefCounted

## Plays a plotted job back in machine time: where the gondola is at any
## moment, and which ink went down since the last call.
##
## A job is a list of colour layers, in painting order:
##   {stamp: int, color: Color, lines: Array of PackedVector2Array (canvas mm)}
## Each line is one tool-down stroke. Between strokes the tool lifts and
## travels. Timing comes from MotionEstimator (acceleration, corner slow-down,
## pen lift/drop time); a change of colour adds colour_change_s, spent parked.
## Pure data, no nodes: the simulator scene and the timelapse both use it.

var draw_feed := 100.0
var travel_feed := 150.0
var colour_change_s := 60.0

var total_time := 0.0
var layer_count := 0

# One entry per move
var _pts := PackedVector2Array()
var _down := PackedByteArray()
var _layer := PackedInt32Array()
var _hold := PackedFloat64Array()   ## parked before the move starts (pen, colour change)
var _t_end := PackedFloat64Array()
var _start := Vector2.ZERO
var _colors: Array[Color] = []
var _stamps := PackedInt32Array()
var _layer_t0 := PackedFloat64Array()
var _layer_new_colour := PackedByteArray()

# Playback state
var time := 0.0
var position := Vector2.ZERO
var pen_down := false
var _i := 0
var pen_changes := 0
var colour_changes := 0
var current_layer := -1
var draw_length := 0.0


func setup(layers: Array, start: Vector2, estimator: MotionEstimator = null) -> void:
	var est := estimator if estimator else MotionEstimator.new()
	_start = start
	_pts.clear(); _down.clear(); _layer.clear(); _hold.clear(); _t_end.clear()
	_colors.clear(); _stamps.clear(); _layer_t0.clear(); _layer_new_colour.clear()
	var t := 0.0
	var pos := start
	var last_colour := Color(-1, -1, -1)
	for li in layers.size():
		var L: Dictionary = layers[li]
		var colour: Color = L.color if L.color is Color else Color.html(str(L.color))
		_colors.append(colour)
		_stamps.append(int(L.get("stamp", li)))
		var new_colour := not colour.is_equal_approx(last_colour)
		_layer_new_colour.append(1 if new_colour else 0)
		_layer_t0.append(t)
		last_colour = colour
		var moves: Array = []
		for line in L.lines:
			if line.size() == 0:
				continue
			moves.append({"x": line[0].x, "y": line[0].y, "tool_down": false, "feed": travel_feed})
			if line.size() == 1:
				moves.append({"x": line[0].x, "y": line[0].y, "tool_down": true, "feed": draw_feed})
			for k in range(1, line.size()):
				moves.append({"x": line[k].x, "y": line[k].y, "tool_down": true, "feed": draw_feed})
		if moves.is_empty():
			continue
		# The pen lifts before the first travel of a layer if it was down
		var times := est.durations(moves, pos)
		for k in moves.size():
			var m: Dictionary = moves[k]
			var hold := 0.0
			var move_t: float = times[k]
			var prev_down: bool = _down[_down.size() - 1] == 1 if not _down.is_empty() else false
			if not m.tool_down and prev_down:
				hold += est.pen_time   # lift
				if k > 0:
					move_t -= est.pen_time   # durations() counted this lift in the move
			if k == 0 and new_colour and li > 0:
				hold += colour_change_s
			if m.tool_down and (k == 0 or not moves[k - 1].tool_down):
				# durations() counted the drop in the move's time: park for it instead
				hold += est.pen_time
				move_t -= est.pen_time
			_pts.append(Vector2(m.x, m.y))
			_down.append(1 if m.tool_down else 0)
			_layer.append(li)
			_hold.append(hold)
			t += hold + move_t
			_t_end.append(t)
		pos = Vector2(moves[-1].x, moves[-1].y)
	if not _down.is_empty() and _down[_down.size() - 1] == 1:
		t += est.pen_time
	total_time = t
	layer_count = layers.size()
	rewind()


func rewind() -> void:
	time = 0.0
	position = _start
	pen_down = false
	_i = 0
	pen_changes = 0
	colour_changes = 0
	current_layer = -1
	draw_length = 0.0


func move_count() -> int:
	return _pts.size()


func layer_color(li: int) -> Color:
	return _colors[li] if li >= 0 and li < _colors.size() else Color.BLACK


func layer_stamp(li: int) -> int:
	return _stamps[li] if li >= 0 and li < _stamps.size() else -1


func done() -> bool:
	return time >= total_time


## Runs the machine forward to time `t` (seconds). Returns the ink laid since
## the last call: Array of {color: Color, points: PackedVector2Array}, in order.
func advance_to(t: float) -> Array:
	var chunks: Array = []
	t = clampf(t, time, total_time)
	time = t
	var n := _pts.size()
	while _i < n:
		var t0 := _t_end[_i - 1] if _i > 0 else 0.0
		var li := _layer[_i]
		if li != current_layer:
			if current_layer >= 0 and _layer_new_colour[li] == 1:
				colour_changes += 1
			current_layer = li
		var move_start := t0 + _hold[_i]
		var down := _down[_i] == 1
		# A travel move lifts the pen as soon as it begins (its hold is the
		# lift); a draw move puts the pen down at the end of its hold
		var now_down := down and t >= move_start
		if now_down != pen_down:
			pen_down = now_down
			pen_changes += 1
		if t <= move_start:
			break
		var target := _pts[_i]
		var f := 1.0 if _t_end[_i] <= t else (t - move_start) / maxf(_t_end[_i] - move_start, 1e-9)
		var from := position
		var seg_start := _pts[_i - 1] if _i > 0 else _start
		var p := seg_start.lerp(target, clampf(f, 0.0, 1.0))
		if down and from.distance_squared_to(p) > 0.0:
			_add_ink(chunks, _colors[li], from, p)
			draw_length += from.distance_to(p)
		elif down and f >= 1.0 and seg_start == target:
			_add_ink(chunks, _colors[li], p, p)   # a dot
		position = p
		if f < 1.0:
			break
		_i += 1
	if _i >= n and pen_down and t >= total_time:
		pen_down = false
		pen_changes += 1
	return chunks


static func _add_ink(chunks: Array, colour: Color, a: Vector2, b: Vector2) -> void:
	if not chunks.is_empty():
		var last: Dictionary = chunks[-1]
		var pts: PackedVector2Array = last.points
		if last.color == colour and pts[pts.size() - 1].distance_squared_to(a) < 1e-8:
			pts.append(b)
			last.points = pts
			return
	chunks.append({"color": colour, "points": PackedVector2Array([a, b])})
