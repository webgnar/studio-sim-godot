extends Node

## Plans a bot painting the way the idle autoplay bot does
## (AutoplayPainter.plan_painting), plays out its mistakes and fixes like the
## bot does stroke by stroke, and saves what ends up on the canvas, in order,
## as a plotter job: canvas millimetres, back to front.
##
## Env: STICKER_REPO, JOB_OUT (path), JOB_SEED (int), JOB_STYLE (prefix the
## plan's style must start with, e.g. "studio"; empty = any),
## JOB_CANVAS_MM ("1830x1220").
## JOB_ROUNDS (int > 0): paint like the studio assistant instead, round after
## round. Each round is planned only when the one before it is finished,
## from the stickers actually on the canvas then (the machine's own record
## of what it painted), so every round reacts to what came before.
## JOB_ASSISTANT_STYLE: "studio" (default), "hall_of_fame" or "aerial_map".

func _ready() -> void:
	if int(OS.get_environment("JOB_ROUNDS")) > 0:
		_rounds()
		return
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
	var stamps := []
	for s in on_canvas:
		stamps.append(_stamp(s, canvas, 0))
	_save({"canvas_mm": [canvas.x, canvas.y], "style": painter.last_style, "seed": seed_value,
		"planned_strokes": painter.stroke_count(), "rounds": 1, "stamps": stamps})


func _canvas() -> Vector2:
	var c := OS.get_environment("JOB_CANVAS_MM")
	return Vector2(float(c.get_slice("x", 0)), float(c.get_slice("x", 1))) if c != "" else Vector2(1830, 1220)


func _stamp(s: Dictionary, canvas: Vector2, round_i: int) -> Dictionary:
	return {
		"sticker": StickerLibrary.sticker_library[s.sticker].id,
		"x": snappedf(s.pos.x * canvas.x, 0.01),
		"y": snappedf(s.pos.y * canvas.y, 0.01),
		"rot": snappedf(s.rot, 0.01),
		"size": snappedf(s.size * canvas.x, 0.01),   # longest side, mm
		"round": round_i,
	}


func _save(job: Dictionary) -> void:
	var f := FileAccess.open(OS.get_environment("JOB_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(job, "\t"))
	f.close()
	print("job: %s, seed %d, %d rounds, %d stamps" % [job.style, job.seed, job.rounds, job.stamps.size()])
	get_tree().quit()


## Studio-assistant painting: rounds of making shapes, then squinting at the
## canvas and defining the forms that came out. Stamps carry their round.
## An undo takes the newest stamp back off, even one from an earlier round.
func _rounds() -> void:
	var canvas := _canvas()
	var rounds := int(OS.get_environment("JOB_ROUNDS"))
	var style := OS.get_environment("JOB_ASSISTANT_STYLE")
	if style == "":
		style = "studio"
	var seed_value := int(OS.get_environment("JOB_SEED")) if OS.get_environment("JOB_SEED") != "" else 1
	seed(seed_value)
	var painter := AutoplayPainter.new()
	for k in StickerLibrary.sticker_library.size():
		painter.warm_up(k)
	painter.begin_assistant(canvas.y / canvas.x, [], style)
	var stamps := []
	var round_i := 0
	var per_round := []
	while true:
		if painter.needs_round():
			if round_i == rounds:
				break
			round_i += 1
			per_round.append(0)
		var s := painter.assistant_stroke()
		if s.has("action"):
			if not stamps.is_empty():
				stamps.pop_back()
			continue
		stamps.append(_stamp(s, canvas, round_i))
		per_round[round_i - 1] += 1
	print("stamps per round: ", per_round)
	_save({"canvas_mm": [canvas.x, canvas.y], "style": "assistant %s, %d rounds" % [style, rounds], "seed": seed_value,
		"rounds": rounds, "stamps": stamps})
