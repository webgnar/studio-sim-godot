class_name LouGnarLocalLeaderboard
extends LouGnarLeaderboard
## Default provider: top-10 stored in user://lou_gnar_scores.json.
## Used until a Steam leaderboard provider is plugged in.

const SAVE_PATH := "user://lou_gnar_scores.json"

var _last_name: String = ""
var _last_score: int = -1


func request_entries() -> void:
	var rows := _load()
	var entries: Array = []
	var marked := false
	for i in rows.size():
		var row: Dictionary = rows[i]
		var is_player: bool = not marked and row["name"] == _last_name and int(row["score"]) == _last_score
		marked = marked or is_player
		entries.append({"rank": i + 1, "name": row["name"], "score": int(row["score"]), "is_player": is_player})
	entries_loaded.emit(entries)


func submit_score(player_name: String, score: int) -> void:
	var rows := _load()
	rows.append({"name": player_name, "score": score})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	rows = rows.slice(0, MAX_ENTRIES)
	_last_name = player_name
	_last_score = score
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		score_submitted.emit(false)
		return
	file.store_string(JSON.stringify(rows))
	file.close()
	score_submitted.emit(true)


func _load() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var rows: Array = []
	if parsed is Array:
		for row: Variant in parsed:
			if row is Dictionary and row.has("name") and row.has("score"):
				rows.append({"name": str(row["name"]), "score": int(row["score"])}) # JSON numbers load as float
	return rows
