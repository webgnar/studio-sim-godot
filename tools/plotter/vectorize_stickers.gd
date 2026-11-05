extends SceneTree

## Tuning harness: vectorizes some stickers and writes a JSON that
## tools/plotter/sticker_preview.py turns into an original | traced | painted
## contact sheet. Run it through tools/plotter/preview_stickers.sh, which uses
## a bare project so no game autoloads start.
##
## Args (after --): out.json ids marker_mm [setting=value ...]
##   ids: comma list of sticker numbers, e.g. 1,2,3
##   settings: any StickerVectorizer var, e.g. detail=600 merge_tolerance=0.07
##   (applied on top of resources/plotter/sticker_vector_settings.json)

const STICKER_DIR := "sprites/painting layers/"
const WIDTH_MM := 500.0  ## stickers are previewed this wide (longest side)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var repo := OS.get_environment("STICKER_REPO")
	var overrides := {}
	for a in args.slice(3):
		var kv: PackedStringArray = a.split("=")
		overrides[kv[0]] = float(kv[1])
	var data := StickerVectorizer.load_settings_file(repo.path_join("resources/plotter/sticker_vector_settings.json"))
	var marker := float(args[2])
	var out := {}
	for id in args[1].split(","):
		# Defaults, then the sticker's entry in the settings file, then the
		# command line
		var v := StickerVectorizer.new()
		v.apply_settings(StickerVectorizer.settings_for(id, data))
		v.apply_settings(overrides)
		var img := Image.load_from_file(repo.path_join(STICKER_DIR + id + ".png"))
		var t := Time.get_ticks_msec()
		var r := v.vectorize(img)
		var ms := Time.get_ticks_msec() - t
		var mm := WIDTH_MM / maxf(r.size.x, r.size.y)
		var centre := Vector2(300, 300)
		var layers := []
		var strokes: Array = []
		for L in r.layers:
			var placed := StickerVectorizer.transform_polylines(L.polygons, r.size, centre, 0.0, mm)
			var paint := StickerVectorizer.paint_strokes(placed, marker)
			strokes.append_array(paint)
			layers.append({"color": L.color.to_html(false), "coverage": L.coverage,
				"polygons": L.polygons.map(_flat), "hatch": paint.map(_flat), "outlines": []})
		var planner := PathPlanner.new()
		planner.merge_distance = 0.5
		planner.home = centre
		planner.return_home = false
		planner.plan(strokes)
		out[id] = {"size": [r.size.x, r.size.y], "ms": ms, "layers": layers, "plan": planner.report}
		print("%s: %d colours, %d ms" % [id, r.layers.size(), ms])
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	quit()


func _flat(p: PackedVector2Array) -> Array:
	var a := []
	for q in p:
		a.append_array([snappedf(q.x, 0.01), snappedf(q.y, 0.01)])
	return a
