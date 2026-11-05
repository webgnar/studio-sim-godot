class_name MotionEstimator
extends RefCounted

## How long the machine takes to run a list of PathPlanner moves.
##
## Each move is a straight line at its feed, with trapezoidal speed (constant
## acceleration up to the feed, cruise, slow down). The machine slows for
## corners: it passes a corner at feed × cos(turn), so a straight-through
## joint keeps full speed and a 90° (or sharper) turn stops. Every pen lift
## and every pen drop costs pen_time. Travel moves start and end at rest.

var accel: float = 500.0       ## mm/s²
var pen_time: float = 0.3      ## s per pen lift or drop


## Seconds to cover `length` mm starting at v_in, cruising at most v_max,
## ending at v_out (mm/s).
func segment_time(length: float, v_in: float, v_max: float, v_out: float) -> float:
	if length <= 0.0:
		return 0.0
	v_in = minf(v_in, v_max)
	v_out = minf(v_out, v_max)
	var up := (v_max * v_max - v_in * v_in) / (2.0 * accel)
	var down := (v_max * v_max - v_out * v_out) / (2.0 * accel)
	if up + down <= length:
		return (v_max - v_in) / accel + (v_max - v_out) / accel + (length - up - down) / v_max
	# Never reaches v_max: peak where the two ramps meet
	var peak := sqrt(maxf((2.0 * accel * length + v_in * v_in + v_out * v_out) * 0.5, 0.0))
	if peak < maxf(v_in, v_out):
		return 2.0 * length / maxf(v_in + v_out, 1e-6)
	return (peak - v_in) / accel + (peak - v_out) / accel


## Total time and a breakdown for a move list (see PathPlanner.plan) starting
## at `start`. Returns {total, draw, travel, pen, pen_changes}.
func estimate(moves: Array, start: Vector2) -> Dictionary:
	var out := {"total": 0.0, "draw": 0.0, "travel": 0.0, "pen": 0.0, "pen_changes": 0}
	var pos := start
	var down := false
	var n := moves.size()
	var v_in := 0.0
	for i in n:
		var m: Dictionary = moves[i]
		var p := Vector2(m.x, m.y)
		var tool_down: bool = m.tool_down
		if tool_down != down:
			out.pen += pen_time
			out.pen_changes += 1
			down = tool_down
			v_in = 0.0
		var d := p - pos
		var length := d.length()
		var feed: float = m.feed
		var v_out := 0.0
		if tool_down and i + 1 < n and moves[i + 1].tool_down:
			var nd := Vector2(moves[i + 1].x, moves[i + 1].y) - p
			if length > 1e-6 and nd.length() > 1e-6:
				v_out = minf(feed, moves[i + 1].feed) * maxf(d.normalized().dot(nd.normalized()), 0.0)
		var t := segment_time(length, v_in if tool_down else 0.0, feed, v_out)
		if tool_down:
			out.draw += t
		else:
			out.travel += t
		v_in = v_out
		pos = p
	if down:
		out.pen += pen_time
		out.pen_changes += 1
	out.total = out.draw + out.travel + out.pen
	return out
