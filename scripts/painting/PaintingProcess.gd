class_name PaintingProcess

## A small record of HOW a canvas was painted, so the AI art critic can respond
## to the way the player works and not only to the finished image.
## PaintingSystem2D keeps the raw log while the canvas is live (and saves it with
## the canvas); when the canvas becomes a CarryablePainting the log is condensed
## by summarize() into the dictionary that is stored on the painting and sent
## with the critique request as "process".

const IDLE_GAP_CAP := 60.0 # seconds; longer pauses between stickers don't count as painting time
const DEFAULT_ROTATION := -90.0 # PaintingSystem2D's preview starts here, so this means "not rotated"


static func new_log() -> Dictionary:
	return {
		"placed": 0,
		"undos": 0,
		"deletes": 0,
		"bot": 0, # placed while the idle autoplay bot was painting
		"custom": 0, # custom / bought stickers
		"tiny": 0, # scaled under half size
		"huge": 0, # scaled over double size
		"rotated": 0,
		"counts": {}, # sticker id -> times placed
		"active_seconds": 0.0,
		"first_at": 0.0, # unix time of the first sticker
		"last_at": 0.0,
	}


## Restores a log from save data, tolerating old saves that have none.
static func from_save(data) -> Dictionary:
	var rec := new_log()
	if typeof(data) == TYPE_DICTIONARY:
		for key in rec.keys():
			if data.has(key):
				rec[key] = data[key]
	return rec


static func record_place(rec: Dictionary, sticker_id: String, scale_mult: float, rotation_deg: float, by_bot: bool) -> void:
	var now := Time.get_unix_time_from_system()
	if int(rec.get("placed", 0)) == 0 or float(rec.get("first_at", 0.0)) <= 0.0:
		rec["first_at"] = now
	else:
		rec["active_seconds"] = float(rec.get("active_seconds", 0.0)) + clampf(now - float(rec.get("last_at", now)), 0.0, IDLE_GAP_CAP)
	rec["last_at"] = now
	rec["placed"] = int(rec.get("placed", 0)) + 1
	if by_bot:
		rec["bot"] = int(rec.get("bot", 0)) + 1
	if sticker_id.begins_with("custom_") or sticker_id.begins_with("bought_"):
		rec["custom"] = int(rec.get("custom", 0)) + 1
	if scale_mult < 0.5:
		rec["tiny"] = int(rec.get("tiny", 0)) + 1
	elif scale_mult > 2.0:
		rec["huge"] = int(rec.get("huge", 0)) + 1
	var off_axis := fposmod(rotation_deg - DEFAULT_ROTATION, 360.0)
	if off_axis > 5.0 and off_axis < 355.0:
		rec["rotated"] = int(rec.get("rotated", 0)) + 1
	var counts: Dictionary = rec.get("counts", {})
	counts[sticker_id] = int(counts.get(sticker_id, 0)) + 1
	rec["counts"] = counts


static func record_undo(rec: Dictionary) -> void:
	rec["undos"] = int(rec.get("undos", 0)) + 1


static func record_delete(rec: Dictionary) -> void:
	rec["deletes"] = int(rec.get("deletes", 0)) + 1


## Condenses a log into what the critic gets. Empty if nothing was placed
## (e.g. an old save made before this was tracked).
static func summarize(rec: Dictionary, by_assistant: bool = false) -> Dictionary:
	var placed := int(rec.get("placed", 0))
	if placed <= 0:
		return {"byAssistant": true} if by_assistant else {}
	var counts: Dictionary = rec.get("counts", {})
	var most := 0
	for c in counts.values():
		most = maxi(most, int(c))
	var first_at := float(rec.get("first_at", 0.0))
	var last_at := float(rec.get("last_at", 0.0))
	return {
		"stickersPlaced": placed,
		"undos": int(rec.get("undos", 0)),
		"deletes": int(rec.get("deletes", 0)),
		"distinctStickers": counts.size(),
		"mostUsedStickerShare": snappedf(float(most) / placed, 0.01),
		"customStickers": int(rec.get("custom", 0)),
		"tinyStickers": int(rec.get("tiny", 0)),
		"hugeStickers": int(rec.get("huge", 0)),
		"rotatedStickers": int(rec.get("rotated", 0)),
		"activeMinutes": snappedf(float(rec.get("active_seconds", 0.0)) / 60.0, 0.1),
		"spanHours": snappedf(maxf(0.0, last_at - first_at) / 3600.0, 0.1),
		"placedByIdleBot": int(rec.get("bot", 0)),
		"byAssistant": by_assistant,
	}
