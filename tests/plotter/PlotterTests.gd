extends Node

## Unit tests for the plotter's pure classes (Polargraph, PathPlanner).
##
## Don't run this scene from the editor (F6): the game's autoloads would start
## too, including the sticker marketplace, which claims pending sale credits.
## Use tools/plotter/run_tests.sh, which runs it in a bare throwaway project.
##
## Exits with code 0 when everything passes, 1 otherwise.

var _failures := 0
var _checks := 0
var _current := ""


func _ready() -> void:
	var tests := [
		"test_motor_positions", "test_round_trip", "test_known_lengths",
		"test_forward_unreachable", "test_cord_angle_and_quality",
		"test_default_canvas_is_usable", "test_quality_grid", "test_steps",
		"test_clip_segment", "test_clip_polyline", "test_outside_path",
		"test_merge_forward_and_reversed", "test_merge_backward",
		"test_merge_respects_distance", "test_ordering", "test_moves_format",
		"test_dot", "test_low_quality_skip", "test_low_quality_flag_and_keep",
		"test_random_stress",
		"test_vectorize_square_with_hole", "test_vectorize_two_colours",
		"test_vectorize_texture_stays_one_colour", "test_hatch_square",
		"test_paint_strokes_stay_inside", "test_transform",
		"test_smoothing_keeps_big_corners", "test_mingled_shades_merge",
	]
	for t in tests:
		_current = t
		call(t)
	print("")
	if _failures == 0:
		print("PLOTTER TESTS: all %d checks passed (%d tests)" % [_checks, tests.size()])
	else:
		print("PLOTTER TESTS: %d of %d checks FAILED" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL [%s] %s" % [_current, what])


func near(a: float, b: float, eps: float, what: String) -> void:
	check(absf(a - b) <= eps, "%s: got %s, expected %s (±%s)" % [what, a, b, eps])


func near_v(a: Vector2, b: Vector2, eps: float, what: String) -> void:
	check(a.distance_to(b) <= eps, "%s: got %s, expected %s (±%s)" % [what, a, b, eps])


# Positions are Vector2, i.e. 32-bit floats: about 0.2 µm of rounding at
# plotter scale, so kinematics are checked to 1e-3 mm / degrees.

# --- Polargraph ----------------------------------------------------------------

func test_motor_positions() -> void:
	var pg := Polargraph.new()
	near_v(pg.left_motor(), Vector2(-305, -450), 1e-9, "left motor")
	near_v(pg.right_motor(), Vector2(2135, -450), 1e-9, "right motor")


func test_round_trip() -> void:
	var pg := Polargraph.new()
	var worst := 0.0
	for gx in 21:
		for gy in 21:
			var p := Vector2(gx * 1830.0 / 20.0, gy * 1220.0 / 20.0)
			var l := pg.xy_to_lengths(p)
			worst = maxf(worst, pg.lengths_to_xy(l.x, l.y).distance_to(p))
	check(worst < 1e-3, "xy -> lengths -> xy round trip error %s mm" % worst)
	# And from lengths: pick cord pairs, go to xy and back
	for l1 in [1300.0, 1800.0, 2400.0]:
		for l2 in [1300.0, 1800.0, 2400.0]:
			var p := pg.lengths_to_xy(l1, l2)
			near_v(pg.xy_to_lengths(p), Vector2(l1, l2), 1e-6, "lengths round trip %s,%s" % [l1, l2])
			check(p.y > -pg.motor_offset, "gondola hangs below the beam for %s,%s" % [l1, l2])


func test_known_lengths() -> void:
	var pg := Polargraph.new()
	var l := pg.xy_to_lengths(Vector2(915, 0))  # top centre
	near(l.x, sqrt(1220.0 * 1220.0 + 450.0 * 450.0), 1e-3, "L1 at top centre")
	near(l.x, l.y, 1e-9, "symmetric at centre")
	l = pg.xy_to_lengths(Vector2(-305, 0))  # straight under left motor
	near(l.x, 450.0, 1e-9, "L1 straight down")
	near(l.y, sqrt(2440.0 * 2440.0 + 450.0 * 450.0), 1e-3, "L2 from far motor")


func test_forward_unreachable() -> void:
	var pg := Polargraph.new()
	check(is_nan(pg.lengths_to_xy(1000, 1000).x), "cords shorter than the spacing can't meet")
	check(is_nan(pg.lengths_to_xy(100, 3000).x), "one cord far longer than the other can't meet")
	var p := pg.lengths_to_xy(1220, 1220)  # exactly half the spacing each: on the beam
	near_v(p, Vector2(915, -450), 1e-6, "cords pulled tight meet on the beam")


func test_cord_angle_and_quality() -> void:
	var pg := Polargraph.new()
	near(pg.cord_angle(Vector2(915, 0)), 2.0 * rad_to_deg(atan(1220.0 / 450.0)), 1e-3, "angle at top centre")
	near(pg.cord_angle(Vector2(915, 770)), 90.0, 1e-3, "90° where depth below beam = half spacing")
	near(pg.quality(Vector2(915, 770)), 1.0, 1e-3, "quality 1 at 90°")
	near(pg.quality(Vector2(915, -440)), 0.0, 1e-9, "near the beam: cords almost flat, quality 0")
	near(pg.quality(Vector2(915, 20000)), 0.0, 1e-9, "far below: cords almost parallel, quality 0")
	near(pg.quality(Vector2(915, -600)), 0.0, 1e-9, "above the beam is unusable")
	# Exactly at the thresholds
	var y20 := 1220.0 / tan(deg_to_rad(10.0)) - 450.0
	near(pg.cord_angle(Vector2(915, y20)), 20.0, 1e-3, "20° point")
	near(pg.quality(Vector2(915, y20)), 0.0, 1e-3, "quality 0 at 20°")
	var y160 := 1220.0 / tan(deg_to_rad(80.0)) - 450.0
	near(pg.quality(Vector2(915, y160)), 0.0, 1e-3, "quality 0 at 160°")
	var y55 := 1220.0 / tan(deg_to_rad(27.5)) - 450.0
	near(pg.quality(Vector2(915, y55)), 0.5, 1e-3, "quality 0.5 at 55° (halfway 20..90)")
	check(not pg.is_usable(Vector2(915, y20 + 10)), "below the 20° line is not usable")


func test_default_canvas_is_usable() -> void:
	var pg := Polargraph.new()
	var lo := 180.0
	var hi := 0.0
	for gx in 31:
		for gy in 21:
			var a := pg.cord_angle(Vector2(gx * 1830.0 / 30.0, gy * 1220.0 / 20.0))
			lo = minf(lo, a)
			hi = maxf(hi, a)
	print("  default machine: cord angle over the canvas %.1f° .. %.1f°" % [lo, hi])
	check(lo > 20.0 and hi < 160.0, "whole default canvas is inside 20°..160°")


func test_quality_grid() -> void:
	var pg := Polargraph.new()
	var g := pg.quality_grid(100.0)
	check(g.cols == 19 and g.rows == 13, "grid size %sx%s" % [g.cols, g.rows])
	check(g.values.size() == g.cols * g.rows, "grid value count")
	near(g.values[0], pg.quality(Vector2(50, 50)), 1e-6, "first cell sampled at its centre")


func test_steps() -> void:
	var pg := Polargraph.new()
	near(pg.steps_per_mm(), 80.0, 1e-9, "GT2 20T, 200 steps, 1/16: 80 steps/mm")
	pg.set_spool_diameter(25.0)
	near(pg.steps_per_mm(), 3200.0 / (PI * 25.0), 1e-9, "25 mm spool steps/mm")
	pg.set_gt2_pulley(20)
	var s := pg.lengths_to_steps(Vector2(1300.35, 2000.0))
	check(s == Vector2i(104028, 160000), "lengths to steps %s" % s)
	near_v(pg.steps_to_lengths(s), Vector2(1300.35, 2000.0), 1.0 / 80.0, "steps back to lengths")


# --- PathPlanner ---------------------------------------------------------------

func test_clip_segment() -> void:
	var r := Rect2(0, 0, 100, 100)
	near_v(PathPlanner.clip_segment(Vector2(10, 10), Vector2(90, 90), r), Vector2(0, 1), 1e-9, "inside")
	near_v(PathPlanner.clip_segment(Vector2(-50, 50), Vector2(150, 50), r), Vector2(0.25, 0.75), 1e-9, "through")
	check(PathPlanner.clip_segment(Vector2(-50, -10), Vector2(150, -10), r).x < 0, "miss above")
	check(PathPlanner.clip_segment(Vector2(90, -20), Vector2(120, 10), r).x < 0, "miss past the corner")


func test_clip_polyline() -> void:
	var r := Rect2(0, 0, 100, 100)
	# In, out across the right edge, back in
	var line := PackedVector2Array([Vector2(50, 20), Vector2(150, 20), Vector2(150, 80), Vector2(50, 80)])
	var pieces := PathPlanner.clip_polyline(line, r)
	check(pieces.size() == 2, "out and back in makes 2 pieces (got %d)" % pieces.size())
	if pieces.size() == 2:
		near_v(pieces[0][pieces[0].size() - 1], Vector2(100, 20), 1e-9, "first piece ends on the edge")
		near_v(pieces[1][0], Vector2(100, 80), 1e-9, "second piece starts on the edge")
	# Wholly inside polyline is untouched
	var inside := PackedVector2Array([Vector2(1, 1), Vector2(50, 50), Vector2(99, 1)])
	pieces = PathPlanner.clip_polyline(inside, r)
	check(pieces.size() == 1 and pieces[0] == inside, "inside polyline unchanged")


func test_outside_path() -> void:
	var planner := PathPlanner.new()
	var moves := planner.plan([PackedVector2Array([Vector2(-100, -100), Vector2(-50, -500)])])
	check(moves.is_empty(), "nothing to draw")
	check(planner.report.outside_paths == 1, "counted as outside")


func test_merge_forward_and_reversed() -> void:
	var a := PackedVector2Array([Vector2(0, 0), Vector2(10, 0)])
	var b := PackedVector2Array([Vector2(10.5, 0), Vector2(20, 0)])
	var c := PackedVector2Array([Vector2(30, 0), Vector2(20.3, 0)])  # reversed, start-end touch
	var typed: Array[PackedVector2Array] = [a, b, c]
	var out := PathPlanner.merge_paths(typed, 1.0)
	check(out.size() == 1, "three touching pieces merge into one (got %d)" % out.size())
	if out.size() == 1:
		near_v(out[0][0], Vector2(0, 0), 1e-9, "merged start")
		near_v(out[0][out[0].size() - 1], Vector2(30, 0), 1e-9, "merged end (c reversed)")
		check(out[0].size() == 6, "all points kept, gaps bridged (got %d)" % out[0].size())


func test_merge_backward() -> void:
	# First path's START touches the second path's END: second must come first
	var a := PackedVector2Array([Vector2(10, 0), Vector2(20, 0)])
	var b := PackedVector2Array([Vector2(0, 0), Vector2(10, 0)])
	var typed: Array[PackedVector2Array] = [a, b]
	var out := PathPlanner.merge_paths(typed, 1.0)
	check(out.size() == 1, "merges backwards")
	if out.size() == 1:
		check(out[0] == PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(20, 0)]), "backward merge order %s" % out[0])


func test_merge_respects_distance() -> void:
	var typed: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]),
		PackedVector2Array([Vector2(12, 0), Vector2(20, 0)]),
	]
	check(PathPlanner.merge_paths(typed, 1.0).size() == 2, "2 mm gap stays apart at 1 mm merge")
	check(PathPlanner.merge_paths(typed, 2.5).size() == 1, "2 mm gap merges at 2.5 mm")
	check(PathPlanner.merge_paths(typed, 0.0).size() == 2, "merge off")


func test_ordering() -> void:
	# Three horizontal strokes on one row, given out of order and one reversed.
	var planner := PathPlanner.new()
	planner.merge_distance = 0.0
	planner.home = Vector2(0, 100)
	planner.return_home = false
	var moves := planner.plan([
		PackedVector2Array([Vector2(500, 100), Vector2(600, 100)]),
		PackedVector2Array([Vector2(100, 100), Vector2(200, 100)]),
		PackedVector2Array([Vector2(400, 100), Vector2(300, 100)]),
	])
	# Best order: 100->200, 300->400, 500->600: travel 100 + 100 + 100
	near(planner.report.travel_length, 300.0, 1e-6, "travel after ordering")
	near(planner.report.draw_length, 300.0, 1e-6, "draw length")
	check(planner.report.pen_lifts == 3, "3 strokes, 3 lifts (got %d)" % planner.report.pen_lifts)
	var xs: Array = []
	for m in moves:
		xs.append(m.x)
	check(xs == [100.0, 200.0, 300.0, 400.0, 500.0, 600.0], "visit order %s" % [xs])


func test_moves_format() -> void:
	var planner := PathPlanner.new()
	planner.draw_feed = 80.0
	planner.travel_feed = 150.0
	var moves := planner.plan([PackedVector2Array([Vector2(100, 100), Vector2(200, 100), Vector2(200, 200)])])
	check(moves.size() == 4, "travel, 2 draws, travel home (got %d)" % moves.size())
	if moves.size() != 4:
		return
	for key in ["x", "y", "tool_down", "feed", "flagged"]:
		check(moves[0].has(key), "move has %s" % key)
	check(not moves[0].tool_down and moves[0].feed == 150.0, "first move is a tool-up travel")
	check(moves[1].tool_down and moves[1].feed == 80.0, "draw at draw feed")
	check(not moves[3].tool_down, "home travel is tool-up")
	near_v(Vector2(moves[3].x, moves[3].y), Vector2(915, 0), 1e-9, "returns home (top centre)")


func test_dot() -> void:
	var planner := PathPlanner.new()
	planner.return_home = false
	var moves := planner.plan([PackedVector2Array([Vector2(300, 300)])])
	check(moves.size() == 2 and not moves[0].tool_down and moves[1].tool_down, "dot: travel then tool down in place")
	check(planner.report.pen_lifts == 1, "dot counts one lift")


func _tight_top_machine() -> Polargraph:
	# Same machine, but cords wider than 120° count as bad: the top centre
	# (139.5°) falls outside, the top corners (112°) stay inside.
	var pg := Polargraph.new()
	pg.max_cord_angle = 120.0
	return pg


func test_low_quality_skip() -> void:
	var pg := _tight_top_machine()
	var planner := PathPlanner.new(pg)
	planner.return_home = false
	var moves := planner.plan([PackedVector2Array([Vector2(50, 50), Vector2(1780, 50)])])
	check(planner.report.low_quality_pieces == 1, "one bad piece in the middle")
	check(planner.report.output_paths == 2, "two good pieces either side (got %d)" % planner.report.output_paths)
	for m in moves:
		if m.tool_down:
			check(pg.cord_angle(Vector2(m.x, m.y)) <= 120.0 + 1e-3, "drawn point inside the band (%s, %s)" % [m.x, m.y])
	# The cuts land on the 120° boundary
	var cut_angles: Array = []
	for m in moves:
		if absf(m.x - 50) > 1e-6 and absf(m.x - 1780) > 1e-6:
			cut_angles.append(pg.cord_angle(Vector2(m.x, m.y)))
	check(cut_angles.size() == 2, "two cut points")
	for a in cut_angles:
		near(a, 120.0, 0.01, "cut on the boundary")
	near(planner.report.draw_length + planner.report.low_quality_length, 1730.0, 1e-3, "drawn + skipped = whole line")


func test_low_quality_flag_and_keep() -> void:
	var line := PackedVector2Array([Vector2(50, 50), Vector2(1780, 50)])
	var planner := PathPlanner.new(_tight_top_machine())
	planner.low_quality = PathPlanner.LowQuality.FLAG
	var moves := planner.plan([line])
	var flagged := 0
	for m in moves:
		if m.flagged:
			flagged += 1
			check(m.tool_down, "only draw moves are flagged")
	check(flagged == 1, "the middle piece's draw move is flagged (got %d)" % flagged)
	near(planner.report.draw_length, 1730.0, 1e-3, "flag mode still draws everything")
	planner.low_quality = PathPlanner.LowQuality.KEEP
	moves = planner.plan([line])
	check(planner.report.output_paths == 1 and planner.report.low_quality_pieces == 0, "keep mode ignores quality")


func test_random_stress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var lines: Array = []
	var input_length := 0.0
	for i in 3000:
		var p := Vector2(rng.randf_range(0, 1830), rng.randf_range(0, 1220))
		var line := PackedVector2Array([p])
		for k in rng.randi_range(1, 6):
			p = (p + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))).clamp(Vector2.ZERO, Vector2(1830, 1220))
			line.append(p)
		input_length += PathPlanner.polyline_length(line)
		lines.append(line)
	var planner := PathPlanner.new()
	planner.merge_distance = 0.0
	var t0 := Time.get_ticks_msec()
	var moves := planner.plan(lines)
	var ms := Time.get_ticks_msec() - t0
	print("  3000 polylines planned in %d ms: %d moves, draw %.0f mm, travel %.0f mm" % [ms, moves.size(), planner.report.draw_length, planner.report.travel_length])
	near(planner.report.draw_length, input_length, 1e-2, "every input mm is drawn")
	# Naive order: the input order, always entering at the start
	var naive := Vector2(915, 0).distance_to(lines[0][0])
	for i in range(1, lines.size()):
		naive += lines[i - 1][lines[i - 1].size() - 1].distance_to(lines[i][0])
	check(planner.report.travel_length < naive * 0.2, "nearest-neighbour travel %.0f vs input order %.0f" % [planner.report.travel_length, naive])
	var inside := true
	for m in moves:
		if m.x < -1e-6 or m.y < -1e-6 or m.x > 1830.0 + 1e-6 or m.y > 1220.0 + 1e-6:
			inside = false
	check(inside, "every move stays on the canvas")
	check(ms < 5000, "planning 3000 polylines took %d ms" % ms)


# --- StickerVectorizer ---------------------------------------------------------

func _img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func test_vectorize_square_with_hole() -> void:
	var img := _img(60, 60)
	img.fill_rect(Rect2i(10, 10, 40, 40), Color(0.8, 0.1, 0.1))
	img.fill_rect(Rect2i(25, 25, 10, 10), Color(0, 0, 0, 0))
	var v := StickerVectorizer.new()
	v.detail = 60
	v.smooth_outline = 0
	var r := v.vectorize(img)
	check(r.layers.size() == 1, "one colour (got %d)" % r.layers.size())
	if r.layers.is_empty():
		return
	var polys: Array = r.layers[0].polygons
	check(polys.size() == 2, "outer ring + hole ring (got %d)" % polys.size())
	var total := 0.0
	var outer := 0
	for p in polys:
		var a := StickerVectorizer._area(p)
		total += a
		if a > 0.0:
			outer += 1
	check(outer == 1, "exactly one outer ring")
	near(total, 1600.0 - 100.0, 1.0, "area = square - hole")
	check(r.layers[0].color.r > 0.7 and r.layers[0].color.g < 0.2, "colour kept %s" % r.layers[0].color)


func test_vectorize_two_colours() -> void:
	var img := _img(80, 40)
	img.fill_rect(Rect2i(0, 0, 40, 40), Color(0.1, 0.2, 0.8))
	img.fill_rect(Rect2i(40, 0, 40, 40), Color(0.95, 0.85, 0.2))
	var v := StickerVectorizer.new()
	v.detail = 80
	v.smooth_outline = 0
	var r := v.vectorize(img)
	check(r.layers.size() == 2, "two colours (got %d)" % r.layers.size())
	if r.layers.size() == 2:
		check(r.layers[0].color.get_luminance() > r.layers[1].color.get_luminance(), "light layer first")
		near(r.layers[0].coverage, 0.5, 0.02, "half each")


func test_vectorize_texture_stays_one_colour() -> void:
	var img := _img(100, 100)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for y in 100:
		for x in 100:
			var n := rng.randf_range(-0.04, 0.04)
			img.set_pixel(x, y, Color(0.85 + n, 0.82 + n, 0.45 + n))
	var v := StickerVectorizer.new()
	v.detail = 100
	var r := v.vectorize(img)
	check(r.layers.size() == 1, "brush texture merges to one colour (got %d)" % r.layers.size())


func test_hatch_square() -> void:
	var sq := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var lines := StickerVectorizer.hatch([sq], 1.0, 0.0)
	check(lines.size() == 10, "10 rows (got %d)" % lines.size())
	var total := 0.0
	for l in lines:
		total += PathPlanner.polyline_length(l)
	near(total, 100.0, 1e-3, "rows span the square")
	# A hole removes its share
	var hole := PackedVector2Array([Vector2(3, 3), Vector2(3, 7), Vector2(7, 7), Vector2(7, 3)])
	total = 0.0
	for l in StickerVectorizer.hatch([sq, hole], 1.0, 0.0):
		total += PathPlanner.polyline_length(l)
	near(total, 100.0 - 16.0, 1e-3, "even-odd hole")
	total = 0.0
	for l in StickerVectorizer.hatch([sq], 1.0, 45.0):
		total += PathPlanner.polyline_length(l)
	near(total, 100.0, 8.0, "45° hatch covers about the same area")


func test_paint_strokes_stay_inside() -> void:
	var sq := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 40), Vector2(0, 40)])
	var tool := 5.0
	var inside := true
	for l in StickerVectorizer.paint_strokes([sq], tool):
		for p in l:
			if p.x < tool * 0.5 - 0.01 or p.y < tool * 0.5 - 0.01 or p.x > 100 - tool * 0.5 + 0.01 or p.y > 40 - tool * 0.5 + 0.01:
				inside = false
	check(inside, "stroke centres stay half a tool width inside the edge")
	# A band thinner than the tool still gets paint
	var thin := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 3), Vector2(0, 3)])
	var strokes := StickerVectorizer.paint_strokes([thin], tool)
	check(not strokes.is_empty(), "thin band still painted")


func test_transform() -> void:
	var lines := StickerVectorizer.transform_polylines([PackedVector2Array([Vector2(0, 0), Vector2(200, 100)])], Vector2(200, 100), Vector2(500, 500), 90.0, 0.5)
	near_v(lines[0][0], Vector2(525, 450), 1e-3, "corner maps through centre, scale, rotation")
	near_v(lines[0][1], Vector2(475, 550), 1e-3, "opposite corner")


func test_smoothing_keeps_big_corners() -> void:
	# A big L-shaped sticker: smoothing must not slice its corners off
	var img := _img(300, 200)
	img.fill_rect(Rect2i(0, 0, 300, 200), Color(0.9, 0.85, 0.4))
	img.fill_rect(Rect2i(150, 100, 150, 100), Color(0, 0, 0, 0))
	var v := StickerVectorizer.new()
	v.detail = 300
	var r := v.vectorize(img)
	var ring: PackedVector2Array = r.layers[0].polygons[0]
	for corner in [Vector2(0, 0), Vector2(300, 0), Vector2(0, 200), Vector2(150, 100)]:
		var best := INF
		for p in ring:
			best = minf(best, p.distance_to(corner))
		check(best < 3.0, "corner %s kept (nearest point %.1f px away)" % [corner, best])
	near(StickerVectorizer._area(ring), 300.0 * 200.0 - 150.0 * 100.0, 60.0, "area kept")


func test_mingled_shades_merge() -> void:
	# Left: two lavender shades speckled together (texture) -> one colour.
	# Right: two equally close greens as separate solid stripes -> stay two.
	var img := _img(200, 100)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in 100:
		for x in 100:
			img.set_pixel(x, y, Color8(0xd0, 0xba, 0xd4) if rng.randf() < 0.5 else Color8(0x9a, 0x9a, 0xbc))
	img.fill_rect(Rect2i(110, 0, 30, 100), Color8(0xa1, 0xb4, 0x50))
	img.fill_rect(Rect2i(160, 0, 30, 100), Color8(0x90, 0x9e, 0x3b))
	var v := StickerVectorizer.new()
	v.detail = 200
	var r := v.vectorize(img)
	check(r.layers.size() == 3, "speckled shades merge, separate stripes don't (got %d colours)" % r.layers.size())
