extends Node

## Makes a commission painted by the autoplay bot's painter, with its
## sticker-by-sticker recording, so the Commissions screen can replay it.
##
## Paints the bot's studio style with every pick any sticker (zack's
## favourite, the "all-any-sticker" paintings: up to 8 squint-and-define
## rounds), the same strokes in the same order the bot would make on a real
## canvas, mistakes and undos included, then writes
##   res://resources/missions/<id>.tres            the commission
##   res://resources/missions/<id>_ref.png         its reference image
##   res://resources/missions/<id>_recording.json  the recording
## Add <id>.tres to missions_manifest.json by hand to put it in the game.
##
## Run it as the main scene (needs a real renderer for the reference image, and
## the StickerLibrary autoload). Remove the StickerMarketplaceManager autoload
## first, or running the game claims pending sticker-sale credits:
##   godot --path . res://tools/bot_commission/MakeBotCommission.tscn -- --id=bot1 --seed=7 --title="..."
## Options: --id, --seed (first seed tried; seeds that don't come out as an
## any-sticker studio painting are skipped), --title, --description, --reward,
## --out (folder, default res://resources/missions/).

const CANVAS := Vector2(1024, 1024)   ## commission canvases (PaintingRoot2D.tscn)
const STICKER_SCALE := 0.5            ## PaintingRoot2D.tscn's sticker_scale
const MIN_SCALE := 0.2                ## PaintingSystem2D min_scale / max_scale
const MAX_SCALE := 3.0
const SEED_TRIES := 200

var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	await get_tree().process_frame
	await _make()
	get_tree().quit()


func _make() -> void:
	var id: String = args.get("id", "bot_commission")
	var out: String = args.get("out", "res://resources/missions/")
	if not out.ends_with("/"):
		out += "/"
	var first_seed := int(args.get("seed", "1"))

	var painter: AutoplayPainter
	var plan_seed := first_seed
	for k in SEED_TRIES:
		plan_seed = first_seed + k
		seed(plan_seed)
		painter = AutoplayPainter.new()
		painter._min_size = MIN_SCALE * STICKER_SCALE   # smallest sticker the canvas allows, in canvas widths
		painter.plan_painting(CANVAS.y / CANVAS.x)
		if painter.last_style.begins_with("studio") and painter.last_style.contains("any sticker"):
			break
		painter = null
	if not painter:
		push_error("MakeBotCommission: no any-sticker studio painting in %d seeds" % SEED_TRIES)
		return
	print("MakeBotCommission: seed %d, %s" % [plan_seed, painter.last_style])

	var rec := _paint(painter)
	var kept := PaintingRecording.surviving(rec)
	print("MakeBotCommission: %d events, %d stickers on the finished painting, %.0f s of painting" % [rec.events.size(), kept.size(), rec.seconds])

	var mission := PaintingMission.new()
	mission.mission_id = id
	mission.title = args.get("title", "bot painting")
	mission.description = args.get("description", "")
	mission.reward = int(args.get("reward", "100"))
	for e in kept:
		var placed := PlacedStickerData.new()
		placed.sticker_id = e.id
		placed.position = Vector2(e.x, e.y)
		placed.rotation_deg = e.r
		placed.scale = e.s
		mission.target_stickers.append(placed)

	# Reference image: the replay's last frame is the canvas turned the way
	# the player sees it, which is what reference images are
	var replay := PaintingReplay.new()
	add_child(replay)
	replay.start(rec)
	replay.skip_to_end()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := replay.texture.get_image()
	var mission_path := out + id + ".tres"
	var ref_path := out + id + "_ref.png"
	image.save_png(ProjectSettings.globalize_path(ref_path))
	mission.reference_image_path = ref_path
	rec.erase("_last_ms")
	rec["painter"] = {"seed": plan_seed, "style": painter.last_style}
	PaintingRecording.save(rec, ProjectSettings.globalize_path(PaintingRecording.path_for_mission(mission_path)))
	var err := ResourceSaver.save(mission, mission_path)
	print("MakeBotCommission: saved %s (%s)" % [mission_path, error_string(err)])


func _paint(painter: AutoplayPainter) -> Dictionary:
	"""Walk the plan the way AutoplayBot does (issue each stroke, react after
	it), turning each stroke into a recording event on a commission canvas.
	Times are what the bot would take: dragging the ghost, mulling it over,
	settling, the pause after."""
	var rec := PaintingRecording.create(CANVAS)
	var t := 0.0
	var aim := Vector2(0.5, 0.5)
	var on_canvas: Array[int] = []   # event indexes still on the canvas
	var library := StickerLibrary.sticker_library
	var i := 0
	while i < painter.stroke_count():
		var s := painter.issue(i)
		if s.has("action"):
			# Notices, stares at it, takes the last sticker back off
			t += float(s.get("stare", 1.0)) + randf_range(AutoplayPainter.PAUSE_AFTER_MIN, AutoplayPainter.PAUSE_AFTER_MAX)
			if not on_canvas.is_empty():
				PaintingRecording.record_remove(rec, on_canvas.pop_back(), snappedf(t, 0.01))
		else:
			var pos: Vector2 = s.pos
			var stops := randi_range(AutoplayPainter.CONSIDER_POINTS_MIN, AutoplayPainter.CONSIDER_POINTS_MAX) if s.ponder else 0
			t += maxf(aim.distance_to(pos) / AutoplayPainter.DRAG_SPEED, AutoplayPainter.DRAG_TIME_MIN)
			for k in stops:
				t += AutoplayPainter.DRAG_TIME_MIN + randf_range(AutoplayPainter.HOVER_MIN, AutoplayPainter.HOVER_MAX)
			if s.precise:
				t += randi_range(AutoplayPainter.NUDGES_MIN, AutoplayPainter.NUDGES_MAX) * AutoplayPainter.DRAG_TIME_MIN
				t += randf_range(AutoplayPainter.PRECISE_SETTLE_MIN, AutoplayPainter.PRECISE_SETTLE_MAX)
			elif s.ponder:
				t += randf_range(AutoplayPainter.SETTLE_MIN, AutoplayPainter.SETTLE_MAX)
			else:
				t += AutoplayPainter.QUICK_SETTLE
			if s.has("look_away"):
				t += float(s.look_away)
			aim = pos
			var sticker: int = s.sticker
			if sticker >= 0 and sticker < library.size() and library[sticker].texture:
				var tex := library[sticker].texture.get_size()
				var mult := clampf(float(s.size) / STICKER_SCALE, MIN_SCALE, MAX_SCALE)
				var node_scale := STICKER_SCALE * CANVAS.x / maxf(tex.x, tex.y) * mult
				# Viewer space (x right, y down, as the player sees the canvas)
				# to canvas pixels: the canvas is turned 90 degrees from the view
				var px := Vector2(pos.y * CANVAS.x, (1.0 - pos.x) * CANVAS.y)
				on_canvas.append(PaintingRecording.record_place(rec, library[sticker].id, px, float(s.rot) - 90.0, mult, node_scale, snappedf(t, 0.01)))
			t += randf_range(AutoplayPainter.PAUSE_AFTER_MIN, AutoplayPainter.PAUSE_AFTER_MAX) if (s.ponder or s.precise) else AutoplayPainter.QUICK_PAUSE_AFTER
		painter.after_stroke(i)
		i += 1
	rec.seconds = snappedf(t, 0.01)
	return rec
