class_name LouGnarSteamLeaderboard
extends LouGnarLeaderboard
## Steam leaderboard provider (GodotSteam).
##
## Talks to the "Steam" singleton dynamically, so this script also compiles in
## builds/editors without GodotSteam. The leaderboard is created on first use
## (findOrCreateLeaderboard), sorted high-to-low, scores are keep-best per player.
## If Steam is unavailable, offline, or doesn't answer within TIMEOUT seconds, it
## falls back to the local JSON board for the rest of the session.

# Valve enums (steam_api): ELeaderboardSortMethod / DisplayType / DataRequest.
const SORT_DESCENDING := 2
const DISPLAY_NUMERIC := 1
const REQUEST_GLOBAL := 0
const TIMEOUT := 8.0

@export var leaderboard_name: String = "LouGnar_HighScores"

var _steam: Object
var _handle: int = 0
var _finding: bool = false
var _waiting: Array[Callable] = []
var _use_fallback: bool = false
var _fallback: LouGnarLocalLeaderboard
var _timer: Timer

var _entries_pending: int = 0
var _submits_pending: Array[Dictionary] = []
var _last_result: Array = []
var _unresolved_names: Dictionary = {}


func _ready() -> void:
	_fallback = LouGnarLocalLeaderboard.new()
	add_child(_fallback)
	_fallback.entries_loaded.connect(func(entries: Array) -> void: entries_loaded.emit(entries))
	_fallback.score_submitted.connect(func(ok: bool) -> void: score_submitted.emit(ok))

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = TIMEOUT
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		_steam.connect("leaderboard_find_result", _on_find_result)
		_steam.connect("leaderboard_score_uploaded", _on_score_uploaded)
		_steam.connect("leaderboard_scores_downloaded", _on_scores_downloaded)
		_steam.connect("persona_state_change", _on_persona_state_change)


func request_entries() -> void:
	if not _steam_usable():
		_fallback.request_entries()
		return
	_entries_pending += 1
	_timer.start()
	_with_handle(func() -> void:
		_steam.downloadLeaderboardEntries(1, MAX_ENTRIES, REQUEST_GLOBAL, _handle))


func submit_score(player_name: String, score: int) -> void:
	if not _steam_usable():
		_fallback.submit_score(player_name, score)
		return
	_submits_pending.append({"name": player_name, "score": score})
	_timer.start()
	_with_handle(func() -> void:
		_steam.uploadLeaderboardScore(score, true, PackedInt32Array(), _handle))


# ---------------------------------------------------------------- internals

func _steam_usable() -> bool:
	if _use_fallback or _steam == null:
		return false
	var tree := get_tree()
	var manager := tree.root.get_node_or_null("SteamManager") if tree else null
	return manager != null and bool(manager.get("is_steam_available"))


func _with_handle(action: Callable) -> void:
	if _handle != 0:
		action.call()
		return
	_waiting.append(action)
	if not _finding:
		_finding = true
		_steam.findOrCreateLeaderboard(leaderboard_name, SORT_DESCENDING, DISPLAY_NUMERIC)


func _on_find_result(...args: Array) -> void:
	_finding = false
	var handle := int(args[0])
	var found := int(args[1])
	if found == 0 or handle == 0:
		push_warning("LouGnarSteamLeaderboard: could not find/create '%s', using local board" % leaderboard_name)
		_fail_over()
		return
	_handle = handle
	var queued := _waiting.duplicate()
	_waiting.clear()
	for action: Callable in queued:
		action.call()


func _on_scores_downloaded(...args: Array) -> void:
	if int(args[1]) != _handle or _entries_pending <= 0:
		return
	_entries_pending -= 1
	_settle_timer()
	_last_result = args[2]
	_emit_entries()


func _on_score_uploaded(...args: Array) -> void:
	if int(args[1]) != _handle or _submits_pending.is_empty():
		return
	_submits_pending.pop_front()
	_settle_timer()
	score_submitted.emit(int(args[0]) == 1)


func _on_persona_state_change(...args: Array) -> void:
	var steam_id := int(args[0])
	if _unresolved_names.has(steam_id) and not _last_result.is_empty():
		_emit_entries()


func _emit_entries() -> void:
	var me := int(_steam.getSteamID())
	var entries: Array = []
	_unresolved_names.clear()
	for row: Dictionary in _last_result:
		var steam_id := int(row["steam_id"])
		entries.append({
			"rank": int(row["global_rank"]),
			"name": _name_for(steam_id),
			"score": int(row["score"]),
			"is_player": steam_id == me,
		})
	entries_loaded.emit(entries)


func _name_for(steam_id: int) -> String:
	var persona := str(_steam.getFriendPersonaName(steam_id))
	if persona == "" or persona == "[unknown]":
		# Not cached yet: ask Steam; persona_state_change re-emits the list.
		_unresolved_names[steam_id] = true
		_steam.requestUserInformation(steam_id, true)
		return "..."
	return persona


func _settle_timer() -> void:
	if _entries_pending <= 0 and _submits_pending.is_empty():
		_timer.stop()
	else:
		_timer.start()


func _on_timeout() -> void:
	push_warning("LouGnarSteamLeaderboard: Steam did not answer in %.0fs, using local board" % TIMEOUT)
	_fail_over()


## Give up on Steam for this session and replay anything still in flight locally.
func _fail_over() -> void:
	_use_fallback = true
	_timer.stop()
	_finding = false
	_waiting.clear()
	var entries_missing := _entries_pending
	var submits := _submits_pending.duplicate()
	_entries_pending = 0
	_submits_pending.clear()
	for submit: Dictionary in submits:
		_fallback.submit_score(submit["name"], submit["score"])
	for i in entries_missing:
		_fallback.request_entries()
