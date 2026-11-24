class_name PaintingRecording

## A sticker-by-sticker recording of how a canvas was painted, so a painting
## can be played back as a time-lapse (the Commissions screen's Watch Replay).
##
## PaintingSystem2D records every canvas as it's painted (placements, undos and
## deletes, with timing) and saves the recording with the canvas. Saving a
## commission with F6 (MissionAuthoringTool) writes it next to the mission as
## <mission>_recording.json. Bot-painted commissions are recorded the same way
## by tools/bot_commission/make_bot_commission.gd.
##
## Format (JSON):
##   {"version": 1, "canvas": [w, h], "seconds": active painting seconds,
##    "events": [...]}
## Each event is one of
##   {"t": s, "id": "14", "x": px, "y": px, "r": deg, "m": mult, "s": node scale}
##       a sticker placed (canvas viewport pixels, rotation as on the canvas,
##       the player's scale multiplier, and the Sprite2D's final scale)
##   {"t": s, "remove": i}
##       the sticker placed by event i was taken off again (undo / delete)
## "t" is seconds of painting time since the first sticker; gaps longer than
## IDLE_GAP_CAP count as IDLE_GAP_CAP, so walking away doesn't stall a replay.

const VERSION := 1
const IDLE_GAP_CAP := 10.0


static func create(canvas_size: Vector2) -> Dictionary:
	return {"version": VERSION, "canvas": [canvas_size.x, canvas_size.y], "seconds": 0.0, "events": [], "_last_ms": -1}


## Restores a recording from save data, tolerating saves that have none.
static func from_save(data, canvas_size: Vector2) -> Dictionary:
	var rec := create(canvas_size)
	if typeof(data) == TYPE_DICTIONARY and data.has("events"):
		rec.events = data.events
		rec.seconds = float(data.get("seconds", 0.0))
		if data.has("canvas"):
			rec.canvas = data.canvas
	return rec


static func _tick(rec: Dictionary) -> float:
	var now := Time.get_ticks_msec()
	var last := int(rec.get("_last_ms", -1))
	if not rec.events.is_empty():
		# Right after a load there's no last time: count it as one capped gap
		var gap := IDLE_GAP_CAP if last < 0 else (now - last) / 1000.0
		rec.seconds = float(rec.seconds) + clampf(gap, 0.0, IDLE_GAP_CAP)
	rec["_last_ms"] = now
	return snappedf(float(rec.seconds), 0.01)


## Records a placed sticker; returns its event index (keep it on the layer so
## a later undo/delete can point back at it).
static func record_place(rec: Dictionary, sticker_id: String, pos: Vector2, rotation_deg: float, scale_mult: float, node_scale: float, t := -1.0) -> int:
	var at := _tick(rec) if t < 0.0 else t
	rec.events.append({
		"t": at, "id": sticker_id,
		"x": snappedf(pos.x, 0.01), "y": snappedf(pos.y, 0.01),
		"r": snappedf(rotation_deg, 0.01),
		"m": snappedf(scale_mult, 0.0001), "s": snappedf(node_scale, 0.000001),
	})
	return rec.events.size() - 1


static func record_remove(rec: Dictionary, place_index: int, t := -1.0) -> void:
	if place_index < 0:
		return
	var at := _tick(rec) if t < 0.0 else t
	rec.events.append({"t": at, "remove": place_index})


static func is_empty(rec: Dictionary) -> bool:
	return rec.is_empty() or (rec.get("events", []) as Array).is_empty()


static func canvas_size(rec: Dictionary) -> Vector2:
	var c: Array = rec.get("canvas", [1024, 1024])
	return Vector2(float(c[0]), float(c[1]))


## The placements still on the canvas at the end, in the order they went down.
static func surviving(rec: Dictionary) -> Array:
	var events: Array = rec.get("events", [])
	var removed := {}
	for e in events:
		if e.has("remove"):
			removed[int(e.remove)] = true
	var out: Array = []
	for i in events.size():
		if not events[i].has("remove") and not removed.has(i):
			out.append(events[i])
	return out


static func save(rec: Dictionary, path: String) -> Error:
	var out := rec.duplicate()
	out.erase("_last_ms")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(out))
	file.close()
	return OK


static func to_save(rec: Dictionary) -> Dictionary:
	var out := rec.duplicate()
	out.erase("_last_ms")
	return out


static func load_file(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("events"):
		return {}
	return data


## Where a mission's recording lives: next to its .tres.
static func path_for_mission(mission_path: String) -> String:
	return mission_path.get_basename() + "_recording.json"
