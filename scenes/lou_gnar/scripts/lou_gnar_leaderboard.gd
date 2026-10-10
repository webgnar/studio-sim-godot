class_name LouGnarLeaderboard
extends Node
## Leaderboard provider interface for LouGnar.
##
## The game auto-submits the Steam persona name + score on game over and shows
## the entries from request_entries(). To use Steam leaderboards, subclass this,
## override the two methods below, and hand it to the game:
##     $LouGnar.leaderboard = MySteamLeaderboard.new()
##
## Entry format (Array[Dictionary]): {"rank": int, "name": String, "score": int, "is_player": bool}

signal entries_loaded(entries: Array)
signal score_submitted(success: bool)

const MAX_ENTRIES := 50


## Fetch the top MAX_ENTRIES and emit entries_loaded (may be async).
func request_entries() -> void:
	entries_loaded.emit([])


## Upload a score and emit score_submitted (may be async).
func submit_score(_player_name: String, _score: int) -> void:
	score_submitted.emit(false)


## True when the last entries/submit came from this device instead of the global board.
func is_offline() -> bool:
	return false


## Steam persona name via the project's SteamManager autoload when available.
static func resolve_player_name() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var steam_manager := tree.root.get_node_or_null("SteamManager")
		if steam_manager and steam_manager.get("is_steam_available"):
			var persona: String = str(steam_manager.get("persona_name"))
			if persona != "":
				return persona
	return "PLAYER"
