extends Node

## Plans a bot painting the way the idle autoplay bot does
## (AutoplayPainter.plan_painting), plays out its mistakes and fixes like the
## bot does stroke by stroke, and saves what ends up on the canvas, in order,
## as a plotter job: canvas millimetres, back to front.
##
## Env: STICKER_REPO, JOB_OUT (path), JOB_SEED (int), JOB_STYLE (prefix the
## plan's style must start with, e.g. "studio"; empty = any),
## JOB_CANVAS_MM ("1830x1220").

func _ready() -> void:
	var canvas := Vector2(1830, 1220)
	var c := OS.get_environment("JOB_CANVAS_MM")
	if c != "":
		canvas = Vector2(float(c.get_slice("x", 0)), float(c.get_slice("x", 1)))
	var want := OS.get_environment("JOB_STYLE")
	var seed_value := int(OS.get_environment("JOB_SEED")) if OS.get_environment("JOB_SEED") != "" else 1
	var painter := AutoplayPainter.new()
	var tries := 0
	while true:
		seed(seed_value)
		painter = AutoplayPainter.new()
		painter.plan_painting(canvas.y / canvas.x)
		if want == "" or painter.last_style.begins_with(want) or tries > 200:
			break
		seed_value += 1
		tries += 1
	# Issue every stroke like the bot does: mistakes, fixes, impulses and the
	# final looks are added as it goes
	var i := 0
	while i < painter.stroke_count():
		painter.issue(i)
		painter.after_stroke(i)
		i += 1
	var on_canvas: Array = []
	for k in painter.stroke_count():
		var s: Dictionary = painter._plan[k]
		if s.has("action"):
			if not on_canvas.is_empty():
				on_canvas.pop_back()
		else:
			on_canvas.append(s)
	var lib := StickerLibrary.sticker_library
	var stamps := []
	for s in on_canvas:
		stamps.append({
			"sticker": lib[s.sticker].id,
			"x": snappedf(s.pos.x * canvas.x, 0.01),
			"y": snappedf(s.pos.y * canvas.y, 0.01),
			"rot": snappedf(s.rot, 0.01),
			"size": snappedf(s.size * canvas.x, 0.01),   # longest side, mm
		})
	var job := {"canvas_mm": [canvas.x, canvas.y], "style": painter.last_style, "seed": seed_value,
		"planned_strokes": painter.stroke_count(), "stamps": stamps}
	var f := FileAccess.open(OS.get_environment("JOB_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(job, "\t"))
	f.close()
	print("job: %s, seed %d, %d stamps (%d strokes planned)" % [painter.last_style, seed_value, stamps.size(), painter.stroke_count()])
	get_tree().quit()
