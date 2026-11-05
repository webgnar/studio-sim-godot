class_name PathPlanner
extends RefCounted

## Turns vector art (polylines in canvas mm) into an ordered list of plotter
## moves.
##
##   plan(polylines) -> Array of {x, y, tool_down, feed, flagged}
##
## Each move is a straight line from the previous position to (x, y), with the
## tool down or up for the whole move, at `feed` mm/s. The machine starts at
## `home` with the tool up. A pen lift is every down -> up change.
##
## Steps, in order:
##   1. clean the input (drop repeated points)
##   2. clip every polyline to the canvas (a line leaving and re-entering
##      becomes two pieces)
##   3. split pieces where they cross into the low-quality region (see
##      Polargraph.quality) and skip, flag or keep those parts
##   4. merge pieces whose endpoints are within merge_distance, so the pen
##      doesn't lift between them
##   5. order the pieces greedily (nearest neighbour, either direction) to
##      cut travel
##
## Pure math, no nodes, so the G-code exporter can reuse it.

enum LowQuality {
	SKIP,  ## drop the low-quality parts of a path
	FLAG,  ## keep them, with flagged = true on their moves
	KEEP,  ## ignore quality entirely
}

var polargraph: Polargraph

## Endpoints closer than this (mm) are joined into one stroke.
var merge_distance: float = 1.0
## Tool-down speed, mm/s.
var draw_feed: float = 100.0
## Tool-up speed, mm/s.
var travel_feed: float = 150.0

var low_quality: LowQuality = LowQuality.SKIP
## A point is low quality when Polargraph.quality(point) <= this.
## 0.0 means only points outside the cord-angle band (min/max_cord_angle).
var min_quality: float = 0.0
## Segments are checked for quality every this many mm, so a long straight
## line that dips into the bad region between its endpoints is still caught.
var quality_sample_mm: float = 10.0
## Pieces shorter than this (mm) after clipping/splitting are dropped.
## Single-point paths (dots) are always kept.
var min_path_length: float = 0.0

## Where the machine starts and parks. Defaults to the canvas's top centre.
var home: Vector2 = Vector2(NAN, NAN)
## Travel back to home after the last stroke.
var return_home: bool = true

## Filled by plan(): counts and lengths describing what happened.
var report: Dictionary = {}


func _init(p_polargraph: Polargraph = null) -> void:
	polargraph = p_polargraph if p_polargraph else Polargraph.new()


func home_position() -> Vector2:
	if is_nan(home.x) or is_nan(home.y):
		return Vector2(polargraph.canvas_size.x * 0.5, 0.0)
	return home


## polylines: Array of PackedVector2Array (or Array of Vector2), canvas mm.
func plan(polylines: Array) -> Array[Dictionary]:
	report = {
		"input_paths": polylines.size(),
		"clipped_paths": 0,          # input paths that lost some length to the canvas edge
		"outside_paths": 0,          # input paths entirely off the canvas
		"low_quality_pieces": 0,     # pieces that fall in the low-quality region
		"low_quality_length": 0.0,   # their length, mm (skipped or flagged)
		"short_pieces_dropped": 0,
		"merges": 0,                 # endpoint joins
		"output_paths": 0,           # strokes after merging
		"draw_length": 0.0,          # tool-down distance, mm
		"travel_length": 0.0,        # tool-up distance, mm
		"pen_lifts": 0,
		"moves": 0,
	}
	var rect := polargraph.canvas_rect()

	# 1-3: clean, clip, quality split. Each piece: {points, flagged}
	var good: Array[PackedVector2Array] = []
	var flagged: Array[PackedVector2Array] = []
	for raw in polylines:
		var line := clean_polyline(raw)
		if line.is_empty():
			continue
		var pieces := clip_polyline(line, rect)
		if pieces.is_empty():
			report.outside_paths += 1
			continue
		var kept := 0.0
		for piece in pieces:
			kept += polyline_length(piece)
		if kept < polyline_length(line) - 1e-6:
			report.clipped_paths += 1
		for piece in pieces:
			var runs: Array[Dictionary] = []
			if low_quality == LowQuality.KEEP:
				runs.append({"points": piece, "ok": true})
			else:
				runs = split_by_quality(piece)
			for run in runs:
				var pts: PackedVector2Array = run.points
				if pts.size() > 1 and polyline_length(pts) < min_path_length:
					report.short_pieces_dropped += 1
					continue
				if run.ok:
					good.append(pts)
				else:
					report.low_quality_pieces += 1
					report.low_quality_length += polyline_length(pts)
					if low_quality == LowQuality.FLAG:
						flagged.append(pts)

	# 4: merge within each group, so a flagged stroke never swallows a good one
	var paths: Array[Dictionary] = []
	for pts in merge_paths(good, merge_distance):
		paths.append({"points": pts, "flagged": false})
	for pts in merge_paths(flagged, merge_distance):
		paths.append({"points": pts, "flagged": true})
	report.merges = good.size() + flagged.size() - paths.size()
	report.output_paths = paths.size()

	# 5: order
	var start := home_position()
	var ordered := order_paths(paths, start)

	# Emit moves
	var moves: Array[Dictionary] = []
	var pos := start
	var down := false
	for path in ordered:
		var pts: PackedVector2Array = path.points
		if pos.distance_squared_to(pts[0]) > 1e-12 or moves.is_empty():
			if down:
				report.pen_lifts += 1
			report.travel_length += pos.distance_to(pts[0])
			moves.append(_move(pts[0], false, travel_feed, false))
			down = false
		if pts.size() == 1:
			# A dot: put the tool down in place
			moves.append(_move(pts[0], true, draw_feed, path.flagged))
		for k in range(1, pts.size()):
			report.draw_length += pts[k - 1].distance_to(pts[k])
			moves.append(_move(pts[k], true, draw_feed, path.flagged))
		down = true
		pos = pts[pts.size() - 1]
	if down:
		report.pen_lifts += 1
	if return_home and not moves.is_empty() and pos.distance_squared_to(start) > 1e-12:
		report.travel_length += pos.distance_to(start)
		moves.append(_move(start, false, travel_feed, false))
	report.moves = moves.size()
	return moves


static func _move(p: Vector2, tool_down: bool, feed: float, flagged: bool) -> Dictionary:
	return {"x": p.x, "y": p.y, "tool_down": tool_down, "feed": feed, "flagged": flagged}


# --- Step 1: clean -----------------------------------------------------------

## Accepts a PackedVector2Array or an Array of Vector2; drops repeated points.
static func clean_polyline(raw) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not (raw is PackedVector2Array or raw is Array):
		return out
	for p in raw:
		if not (p is Vector2) or not p.is_finite():
			continue
		if out.is_empty() or out[out.size() - 1].distance_squared_to(p) > 1e-12:
			out.append(p)
	return out


static func polyline_length(line: PackedVector2Array) -> float:
	var total := 0.0
	for k in range(1, line.size()):
		total += line[k - 1].distance_to(line[k])
	return total


# --- Step 2: clip -------------------------------------------------------------

## Clips a polyline to a rectangle. Returns the inside pieces in order.
static func clip_polyline(line: PackedVector2Array, rect: Rect2) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	if line.size() == 1:
		if _rect_contains(rect, line[0]):
			pieces.append(line)
		return pieces
	var run := PackedVector2Array()
	for k in range(1, line.size()):
		var a := line[k - 1]
		var b := line[k]
		var t := clip_segment(a, b, rect)
		if t.x < 0.0:
			if run.size() > 1:
				pieces.append(run)
			run = PackedVector2Array()
			continue
		var d := b - a
		var pa := a + d * t.x
		var pb := a + d * t.y
		if t.x > 0.0 and run.size() > 0:
			# Re-entering after leaving: new piece
			if run.size() > 1:
				pieces.append(run)
			run = PackedVector2Array()
		if run.is_empty():
			run.append(pa)
		if run[run.size() - 1].distance_squared_to(pb) > 1e-12:
			run.append(pb)
		if t.y < 1.0:
			if run.size() > 1:
				pieces.append(run)
			run = PackedVector2Array()
	if run.size() > 1:
		pieces.append(run)
	return pieces


## Liang-Barsky. Returns Vector2(t_enter, t_exit) along a->b, or (-1, -1) if
## the segment misses the rectangle.
static func clip_segment(a: Vector2, b: Vector2, rect: Rect2) -> Vector2:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var ps := [-d.x, d.x, -d.y, d.y]
	var qs := [a.x - rect.position.x, rect.end.x - a.x, a.y - rect.position.y, rect.end.y - a.y]
	for i in 4:
		var p: float = ps[i]
		var q: float = qs[i]
		if absf(p) < 1e-12:
			if q < 0.0:
				return Vector2(-1.0, -1.0)
			continue
		var r := q / p
		if p < 0.0:
			if r > t1:
				return Vector2(-1.0, -1.0)
			t0 = maxf(t0, r)
		else:
			if r < t0:
				return Vector2(-1.0, -1.0)
			t1 = minf(t1, r)
	return Vector2(t0, t1)


static func _rect_contains(rect: Rect2, p: Vector2) -> bool:
	# Rect2.has_point excludes the far edges; plotting on the edge is fine.
	return p.x >= rect.position.x and p.y >= rect.position.y and p.x <= rect.end.x and p.y <= rect.end.y


# --- Step 3: quality ----------------------------------------------------------

func _point_ok(p: Vector2) -> bool:
	return polargraph.quality(p) > min_quality


## Splits a polyline into runs that are all usable or all low quality.
## Returns Array of {points: PackedVector2Array, ok: bool}. Crossing points are
## found by bisection, so runs meet exactly at the region boundary.
func split_by_quality(line: PackedVector2Array) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	if line.is_empty():
		return runs
	var ok := _point_ok(line[0])
	var run := PackedVector2Array([line[0]])
	for k in range(1, line.size()):
		var a := line[k - 1]
		var b := line[k]
		var n := maxi(1, ceili(a.distance_to(b) / maxf(quality_sample_mm, 0.1)))
		var prev_t := 0.0
		for s in range(1, n + 1):
			var t := float(s) / n
			var p := a.lerp(b, t)
			var p_ok := _point_ok(p)
			if p_ok != ok:
				var edge := _bisect(a, b, prev_t, t, ok)
				if run[run.size() - 1].distance_squared_to(edge) > 1e-12:
					run.append(edge)
				runs.append({"points": run, "ok": ok})
				run = PackedVector2Array([edge])
				ok = p_ok
			prev_t = t
		if run[run.size() - 1].distance_squared_to(b) > 1e-12:
			run.append(b)
	runs.append({"points": run, "ok": ok})
	# A run that's only its boundary point carries no stroke
	var out: Array[Dictionary] = []
	for r in runs:
		if r.points.size() > 1 or line.size() == 1:
			out.append(r)
	return out


func _bisect(a: Vector2, b: Vector2, t_in: float, t_out: float, ok_at_in: bool) -> Vector2:
	for _i in 24:
		var mid := (t_in + t_out) * 0.5
		if _point_ok(a.lerp(b, mid)) == ok_at_in:
			t_in = mid
		else:
			t_out = mid
	return a.lerp(b, (t_in + t_out) * 0.5)


# --- Step 4: merge ------------------------------------------------------------

## Joins polylines end to end wherever two endpoints are within `distance`,
## reversing pieces as needed. Greedy: each chain grows forwards, then
## backwards, always taking the nearest free endpoint.
static func merge_paths(paths: Array[PackedVector2Array], distance: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if paths.is_empty():
		return out
	if distance <= 0.0:
		out.assign(paths)
		return out
	var grid := EndpointGrid.new(distance)
	for i in paths.size():
		grid.add(i * 2, paths[i][0])
		grid.add(i * 2 + 1, paths[i][paths[i].size() - 1])
	for i in paths.size():
		if not grid.is_alive(i * 2):
			continue
		grid.remove(i * 2)
		grid.remove(i * 2 + 1)
		var chain := paths[i].duplicate()
		# Forwards from the chain's end
		while true:
			var id := grid.nearest(chain[chain.size() - 1], distance)
			if id < 0:
				break
			var j := id / 2
			grid.remove(j * 2)
			grid.remove(j * 2 + 1)
			var next := paths[j] if id % 2 == 0 else _reversed(paths[j])
			chain = _joined(chain, next)
		# Backwards from the chain's start
		while true:
			var id := grid.nearest(chain[0], distance)
			if id < 0:
				break
			var j := id / 2
			grid.remove(j * 2)
			grid.remove(j * 2 + 1)
			# An end that meets our start: that path comes first, as-is
			var prev := paths[j] if id % 2 == 1 else _reversed(paths[j])
			chain = _joined(prev, chain)
		out.append(chain)
	return out


## first + second, dropping second's first point if it repeats first's last.
static func _joined(first: PackedVector2Array, second: PackedVector2Array) -> PackedVector2Array:
	var out := first.duplicate()
	var start := 0
	if out[out.size() - 1].distance_squared_to(second[0]) <= 1e-12:
		start = 1
	for k in range(start, second.size()):
		out.append(second[k])
	return out


static func _reversed(line: PackedVector2Array) -> PackedVector2Array:
	var r := line.duplicate()
	r.reverse()
	return r


# --- Step 5: order -------------------------------------------------------------

## Greedy nearest-neighbour ordering. paths: Array of {points, flagged}.
## Returns the same dictionaries in drawing order, with points reversed where
## entering from the far end is closer.
func order_paths(paths: Array[Dictionary], start: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if paths.is_empty():
		return out
	var cell := maxf(polargraph.canvas_size.x, polargraph.canvas_size.y) / 64.0
	var grid := EndpointGrid.new(cell)
	for i in paths.size():
		var pts: PackedVector2Array = paths[i].points
		grid.add(i * 2, pts[0])
		grid.add(i * 2 + 1, pts[pts.size() - 1])
	var pos := start
	for _n in paths.size():
		var id := grid.nearest(pos, INF)
		if id < 0:
			break
		var i := id / 2
		grid.remove(i * 2)
		grid.remove(i * 2 + 1)
		var path: Dictionary = paths[i].duplicate()
		if id % 2 == 1:
			path.points = _reversed(path.points)
		out.append(path)
		pos = path.points[path.points.size() - 1]
	return out


## Uniform grid over endpoint positions for fast nearest-free-endpoint lookups.
class EndpointGrid:
	var cell: float
	var cells: Dictionary = {}  # Vector2i -> PackedInt32Array of ids
	var positions: Dictionary = {}  # id -> Vector2
	var alive: Dictionary = {}  # id -> true
	var min_key := Vector2i(1 << 30, 1 << 30)
	var max_key := Vector2i(-(1 << 30), -(1 << 30))

	func _init(cell_size: float) -> void:
		cell = maxf(cell_size, 1e-3)

	func _key(p: Vector2) -> Vector2i:
		return Vector2i(floori(p.x / cell), floori(p.y / cell))

	func add(id: int, p: Vector2) -> void:
		var k := _key(p)
		if not cells.has(k):
			cells[k] = PackedInt32Array()
		var ids: PackedInt32Array = cells[k]
		ids.append(id)
		cells[k] = ids
		positions[id] = p
		alive[id] = true
		min_key = Vector2i(mini(min_key.x, k.x), mini(min_key.y, k.y))
		max_key = Vector2i(maxi(max_key.x, k.x), maxi(max_key.y, k.y))

	func remove(id: int) -> void:
		alive.erase(id)

	func is_alive(id: int) -> bool:
		return alive.has(id)

	## Nearest live id within max_dist of p, or -1.
	func nearest(p: Vector2, max_dist: float) -> int:
		if alive.is_empty():
			return -1
		var c := _key(p)
		# Rings needed to cover every occupied cell from here
		var reach := maxi(maxi(absi(c.x - min_key.x), absi(c.x - max_key.x)), maxi(absi(c.y - min_key.y), absi(c.y - max_key.y)))
		if max_dist < INF:
			reach = mini(reach, ceili(max_dist / cell) + 1)
		var best := -1
		var best_d2 := max_dist * max_dist if max_dist < INF else INF
		for r in reach + 1:
			# Anything in ring r is at least (r - 1) * cell away
			if best >= 0 and float(r - 1) * cell > sqrt(best_d2):
				break
			for y in range(c.y - r, c.y + r + 1):
				var on_edge_row := y == c.y - r or y == c.y + r
				var step := 1 if on_edge_row else 2 * r
				var x := c.x - r
				while x <= c.x + r:
					var k := Vector2i(x, y)
					if cells.has(k):
						for id in cells[k]:
							if alive.has(id):
								var d2: float = p.distance_squared_to(positions[id])
								if d2 <= best_d2 and (best < 0 or d2 < best_d2):
									best = id
									best_d2 = d2
					if step == 0:
						break
					x += step
		return best
