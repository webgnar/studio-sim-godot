class_name LouGnarSteamLeaderboard
extends LouGnarLeaderboard
## Steam leaderboard provider (GodotSteam).
##
## Talks to the "Steam" singleton dynamically, so this script also compiles in
## builds/editors without GodotSteam. The leaderboard is created on first use
## (findOrCreateLeaderboard), sorted high-to-low, and Steam keeps one best score
## per player.
##
## Every run is also recorded on the device (LouGnarLocalLeaderboard). Uploads
## send the player's best device score, so runs that never reached Steam (offline,
## slow network) still land on the global board the next time an upload works.
## If Steam is offline or a request doesn't answer within TIMEOUT seconds, that
## request is served from the device board instead; Steam is tried again on the
## next one, and a late answer from Steam still counts.

# Valve enums (steam_api): ELeaderboardSortMethod / DisplayType / DataRequest.
const SORT_DESCENDING := 2
const DISPLAY_NUMERIC := 1
const REQUEST_GLOBAL := 0
const TIMEOUT := 15.0

@export var leaderboard_name: String = "LouGnar_HighScores"

var _steam: Object
var _handle: int = 0
var _finding: bool = false
var _waiting: Array[Callable] = []
var _fallback: LouGnarLocalLeaderboard
var _timer: Timer
var _showing_local: bool = false

var _entries_pending: int = 0
var _submits_pending: int = 0
var _last_result: Array = []
var _unresolved_names: Dictionary = {}
var _emit_queued: bool = false


func _ready() -> void:
	_fallback = LouGnarLocalLeaderboard.new()
	add_child(_fallback)
	_fallback.entries_loaded.connect(func(entries: Array) -> void:
		_showing_local = true
		entries_loaded.emit(entries))

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


func is_offline() -> bool:
	return _showing_local


func request_entries() -> void:
	if not _steam_usable():
		_fallback.request_entries()
		return
	_entries_pending += 1
	_timer.start()
	_with_handle(func() -> void:
		_steam.downloadLeaderboardEntries(1, MAX_ENTRIES, REQUEST_GLOBAL, _handle))


func submit_score(player_name: String, score: int) -> void:
	var saved := _fallback.record_score(player_name, score)
	if not _steam_usable():
		_showing_local = true
		score_submitted.emit(saved)
		return
	# Steam keeps the higher score, so sending the device best syncs earlier offline runs.
	var best := maxi(score, _fallback.best_score(player_name))
	_submits_pending += 1
	_timer.start()
	_with_handle(func() -> void:
		_steam.uploadLeaderboardScore(best, true, PackedInt32Array(), _handle))


# ---------------------------------------------------------------- internals

func _steam_usable() -> bool:
	if _steam == null:
		return false
	var tree := get_tree()
	var manager := tree.root.get_node_or_null("SteamManager") if tree else null
	return manager != null and bool(manager.get("is_steam_available")) and bool(_steam.loggedOn())


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
		push_warning("LouGnarSteamLeaderboard: could not find/create '%s', using the device board" % leaderboard_name)
		_serve_locally()
		return
	_handle = handle
	var queued := _waiting.duplicate()
	_waiting.clear()
	for action: Callable in queued:
		action.call()


## Results are used even if they arrive after the timeout: Steam's board then
## replaces the device board on screen.
func _on_scores_downloaded(...args: Array) -> void:
	if _handle == 0 or int(args[1]) != _handle:
		return
	_entries_pending = maxi(_entries_pending - 1, 0)
	_settle_timer()
	_last_result = args[2]
	_emit_entries()


func _on_score_uploaded(...args: Array) -> void:
	if _handle == 0 or int(args[1]) != _handle:
		return
	_submits_pending = maxi(_submits_pending - 1, 0)
	_settle_timer()
	# A failed upload is still saved on the device and retried with the next run.
	_showing_local = int(args[0]) != 1
	score_submitted.emit(true)


func _on_persona_state_change(...args: Array) -> void:
	var steam_id := int(args[0])
	if _unresolved_names.has(steam_id) and not _last_result.is_empty() and not _emit_queued:
		# Up to 50 names can resolve in a burst; redraw the board once for the lot.
		_emit_queued = true
		_emit_entries.call_deferred()


func _emit_entries() -> void:
	_emit_queued = false
	_showing_local = false
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
	if _entries_pending <= 0 and _submits_pending <= 0:
		_timer.stop()
	else:
		_timer.start()


func _on_timeout() -> void:
	push_warning("LouGnarSteamLeaderboard: Steam did not answer in %.0fs, showing the device board" % TIMEOUT)
	_serve_locally()


## Answer whatever is in flight from the device board. Nothing is switched off:
## the next request tries Steam again.
func _serve_locally() -> void:
	_timer.stop()
	if _handle == 0:
		_finding = false # retry the lookup next time
		_waiting.clear()
	var entries_missing := _entries_pending > 0
	var submits_missing := _submits_pending > 0
	_entries_pending = 0
	_submits_pending = 0
	if submits_missing:
		_showing_local = true
		score_submitted.emit(true) # already recorded on the device
	if entries_missing:
		_fallback.request_entries()
