class_name LouGnarLocalLeaderboard
extends LouGnarLeaderboard
## Device board: the top MAX_ENTRIES runs stored in user://lou_gnar_scores.json.
## Used on its own without GodotSteam, and by the Steam provider as the offline
## board and a record of every run.

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


func is_offline() -> bool:
	return true


func submit_score(player_name: String, score: int) -> void:
	score_submitted.emit(record_score(player_name, score))


## Save a run without signalling. Returns false if the file couldn't be written.
func record_score(player_name: String, score: int) -> bool:
	var rows := _load()
	rows.append({"name": player_name, "score": score})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	rows = rows.slice(0, MAX_ENTRIES)
	_last_name = player_name
	_last_score = score
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(rows))
	file.close()
	return true


## Highest saved score for this name (0 if none).
func best_score(player_name: String) -> int:
	var best := 0
	for row: Dictionary in _load():
		if row["name"] == player_name:
			best = maxi(best, int(row["score"]))
	return best


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
