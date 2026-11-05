extends SceneTree

## Plots a job (see tools/plotter/bot/plan_job.gd): vectorizes each sticker,
## places it on the canvas, paints its colours light to dark, plans every
## colour with PathPlanner and times it with MotionEstimator. Writes what the
## machine draws (for tools/plotter/render_job.py) and the job's numbers.
##
## Args (after --): job.json out.json marker_mm [colour_change_s] [painting.svg]
## The SVG holds the painting as filled colour shapes, back to front, with
## a second file (<name>_toolpaths.svg) adding the tool paths as a hidden
## layer (see SvgExporter).

const STICKER_DIR := "sprites/painting layers/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var repo := OS.get_environment("STICKER_REPO")
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var marker := float(args[2])
	var change_s := float(args[3]) if args.size() > 3 else 60.0
	var settings := StickerVectorizer.load_settings_file(repo.path_join("resources/plotter/sticker_vector_settings.json"))
	var canvas := Vector2(job.canvas_mm[0], job.canvas_mm[1])
	var machine := Polargraph.new(2440.0, 450.0, canvas)
	var planner := PathPlanner.new(machine)
	planner.merge_distance = marker * 0.25
	planner.low_quality = PathPlanner.LowQuality.KEEP
	planner.return_home = false
	var timer := MotionEstimator.new()
	var cache := {}
	var pos := planner.home_position()
	var out_layers := []
	var svg_shapes := []
	var svg_paths := []
	var stats := {"stamps": job.stamps.size(), "colour_layers": 0, "colour_changes": 0,
		"draw_s": 0.0, "travel_s": 0.0, "pen_s": 0.0, "pen_changes": 0,
		"draw_mm": 0.0, "travel_mm": 0.0, "strokes": 0, "off_canvas_paths": 0, "vectorize_ms": 0}
	var last_colour := ""
	var colours := {}
	var t0 := Time.get_ticks_msec()
	var n := 0
	for st in job.stamps:
		n += 1
		var id: String = st.sticker
		if not cache.has(id):
			var v := StickerVectorizer.new()
			v.apply_settings(StickerVectorizer.settings_for(id, settings))
			var tv := Time.get_ticks_msec()
			cache[id] = v.vectorize(Image.load_from_file(repo.path_join(STICKER_DIR + id + ".png")))
			stats.vectorize_ms += Time.get_ticks_msec() - tv
		var r: Dictionary = cache[id]
		var mm: float = st.size / maxf(r.size.x, r.size.y)
		for L in r.layers:
			var placed := StickerVectorizer.transform_polylines(L.polygons, r.size, Vector2(st.x, st.y), st.rot, mm)
			svg_shapes.append({"stamp": n - 1, "sticker": id, "color": L.color, "polygons": placed})
			var strokes := StickerVectorizer.paint_strokes(placed, marker)
			if strokes.is_empty():
				continue
			planner.home = pos
			var moves := planner.plan(strokes)
			if moves.is_empty():
				stats.off_canvas_paths += planner.report.outside_paths
				continue
			var colour: String = L.color.to_html(false)
			stats.colour_layers += 1
			colours[colour] = true
			if colour != last_colour:
				stats.colour_changes += 1
				last_colour = colour
			var t := timer.estimate(moves, pos)
			stats.draw_s += t.draw
			stats.travel_s += t.travel
			stats.pen_s += t.pen
			stats.pen_changes += t.pen_changes
			stats.draw_mm += planner.report.draw_length
			stats.travel_mm += planner.report.travel_length
			stats.strokes += planner.report.output_paths
			stats.off_canvas_paths += planner.report.outside_paths
			out_layers.append({"stamp": n - 1, "sticker": id, "color": colour, "lines": _lines(moves)})
			svg_paths.append({"color": colour, "lines": _down_runs(moves)})
			pos = Vector2(moves[-1].x, moves[-1].y)
		if n % 25 == 0:
			print("  %d / %d stamps, %d s" % [n, job.stamps.size(), (Time.get_ticks_msec() - t0) / 1000])
	stats.distinct_colours = colours.size()
	stats.colour_change_s = change_s
	stats.machine_s = stats.draw_s + stats.travel_s + stats.pen_s
	stats.total_s = stats.machine_s + stats.colour_changes * change_s
	stats.marker_mm = marker
	stats.style = job.style
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify({"canvas_mm": job.canvas_mm, "marker_mm": marker, "style": job.style, "stamp_count": job.stamps.size(), "stats": stats, "layers": out_layers}))
	f.close()
	if args.size() > 4:
		var title := "Studio Sim bot painting: %s (seed %d)" % [job.style, job.seed]
		var svg := FileAccess.open(args[4], FileAccess.WRITE)
		svg.store_string(SvgExporter.painting_svg(canvas, svg_shapes, title))
		svg.close()
		# The machine's strokes on top of the shapes, toolpaths layer hidden
		svg = FileAccess.open(args[4].get_basename() + "_toolpaths.svg", FileAccess.WRITE)
		svg.store_string(SvgExporter.painting_svg(canvas, svg_shapes, title + ", tool paths", svg_paths, marker))
		svg.close()
	print(JSON.stringify(stats, "  "))
	quit()


## The tool-down runs of a move list as flat [x0, y0, x1, y1, ...] arrays.
func _lines(moves: Array) -> Array:
	var lines := []
	var cur := []
	var prev := Vector2.ZERO
	for m in moves:
		if m.tool_down:
			if cur.is_empty():
				cur = [snappedf(prev.x, 0.1), snappedf(prev.y, 0.1)]
			cur.append_array([snappedf(m.x, 0.1), snappedf(m.y, 0.1)])
		elif not cur.is_empty():
			lines.append(cur)
			cur = []
		prev = Vector2(m.x, m.y)
	if not cur.is_empty():
		lines.append(cur)
	return lines


## The tool-down runs of a move list as polylines.
func _down_runs(moves: Array) -> Array:
	var runs := []
	var cur := PackedVector2Array()
	var prev := Vector2.ZERO
	for m in moves:
		if m.tool_down:
			if cur.is_empty():
				cur.append(prev)
			cur.append(Vector2(m.x, m.y))
		elif not cur.is_empty():
			runs.append(cur)
			cur = PackedVector2Array()
		prev = Vector2(m.x, m.y)
	if not cur.is_empty():
		runs.append(cur)
	return runs
