extends Node

## Global Steam integration manager
## Handles initialization, achievements, stats, and callbacks

# Signals
signal steam_initialized(success: bool)
signal achievement_unlocked(achievement_id: String)
signal stats_updated()
signal stats_ready()

# Steam availability
var is_steam_available: bool = false
var is_online: bool = false
var steam_input_enabled: bool = false

# Achievement tracking (API names as keys)
var achievements: Dictionary = {}

# Statistics tracking (API names as keys)
var statistics: Dictionary = {}

# Session tracking
var session_start_time: int = 0
var total_playtime_seconds: int = 0

# Debug mode
var debug_mode: bool = true  # Set to false for production

func _ready():
	initialize_steam()
	setup_achievements()
	setup_statistics()

func _process(_delta: float):
	# Run Steam callbacks every frame (required for events)
	if is_steam_available and _is_steam_singleton_available():
		Steam.run_callbacks()

func _is_steam_singleton_available() -> bool:
	"""Check if Steam singleton exists (GodotSteam addon installed)"""
	return Engine.has_singleton("Steam")

func initialize_steam() -> void:
	"""Initialize Steam API and check availability"""
	# Check if GodotSteam addon is installed
	if not _is_steam_singleton_available():
		push_warning("SteamManager: GodotSteam addon not installed! Steam features disabled.")
		is_steam_available = false
		steam_initialized.emit(false)
		return

	if OS.has_feature("editor"):
		print("SteamManager: Running in editor, Steam features limited")

	# Initialize Steam
	var init_response: Dictionary = Steam.steamInitEx()

	if debug_mode:
		print("SteamManager: Initialization response: ", init_response)

	if init_response['status'] != Steam.STEAM_API_INIT_RESULT_OK:
		push_warning("SteamManager: Failed to initialize Steam: %s" % init_response['status'])
		is_steam_available = false
		steam_initialized.emit(false)
		return

	is_steam_available = true
	is_online = Steam.loggedOn()

	# Get user info
	var steam_id: int = Steam.getSteamID()
	var persona_name: String = Steam.getPersonaName()

	print("SteamManager: Steam initialized successfully!")
	print("  User: %s (ID: %d)" % [persona_name, steam_id])
	print("  Online: %s" % is_online)

	# Start session timer
	session_start_time = Time.get_ticks_msec()

	# Load Steam data
	load_steam_stats()
	load_steam_achievements()

	# Initialize Steam Input API
	_initialize_steam_input()

	steam_initialized.emit(true)

func setup_achievements() -> void:
	"""Define all achievements (must match Steamworks backend)"""
	achievements = {
		# Tutorial & First Steps
		"ACH_FIRST_MISSION": false,
		"ACH_FIRST_PERFECT": false,

		# Mission Completion (Progressive)
		"ACH_MISSIONS_5": false,
		"ACH_MISSIONS_10": false,
		"ACH_MISSIONS_ALL": false,

		# Grade-Based
		"ACH_GRADE_S": false,
		"ACH_GRADE_S_5": false,
		"ACH_PERFECTIONIST": false,  # All missions S rank

		# Difficulty-Based
		"ACH_HARD_MISSION": false,
		"ACH_HARD_PERFECT": false,

		# Playtime
		"ACH_PLAY_1HOUR": false,
		"ACH_PLAY_10HOURS": false,

		# Fun/Hidden
		"ACH_SPEEDRUNNER": false,  # Complete mission under 1 minute
		"ACH_PAINTER": false,  # Place 1000 total stickers
	}

func setup_statistics() -> void:
	"""Define all statistics (must match Steamworks backend)"""
	statistics = {
		# Mission tracking
		"STAT_MISSIONS_COMPLETED": 0,
		"STAT_MISSIONS_PERFECT": 0,
		"STAT_MISSIONS_S_RANK": 0,
		"STAT_MISSIONS_FAILED": 0,

		# Sticker tracking
		"STAT_STICKERS_PLACED": 0,

		# Time tracking
		"STAT_PLAYTIME_SECONDS": 0,

		# Best scores
		"STAT_BEST_SCORE": 0,  # Highest mission score (0-100)
		"STAT_TOTAL_SCORE": 0,  # Sum of all mission scores
	}

func load_steam_achievements() -> void:
	"""Load achievement states from Steam"""
	if not is_steam_available:
		return

	for achievement_id in achievements.keys():
		var result: Dictionary = Steam.getAchievement(achievement_id)

		if not result['ret']:
			if debug_mode:
				push_warning("SteamManager: Achievement not found in Steamworks backend: %s" % achievement_id)
			continue

		achievements[achievement_id] = result['achieved']

		if debug_mode and result['achieved']:
			print("SteamManager: Achievement already unlocked: %s" % achievement_id)

func load_steam_stats() -> void:
	"""Load statistics from Steam"""
	if not is_steam_available:
		return

	for stat_id in statistics.keys():
		var stat_value: int = Steam.getStatInt(stat_id)
		statistics[stat_id] = stat_value

		if debug_mode:
			print("SteamManager: Loaded stat %s = %d" % [stat_id, stat_value])

	# Load total playtime
	total_playtime_seconds = statistics.get("STAT_PLAYTIME_SECONDS", 0)

	stats_ready.emit()

func unlock_achievement(achievement_id: String) -> void:
	"""Unlock an achievement (idempotent - safe to call multiple times)"""
	if not is_steam_available:
		if debug_mode:
			print("SteamManager: [OFFLINE] Achievement unlocked: %s" % achievement_id)
		return

	if not achievements.has(achievement_id):
		push_warning("SteamManager: Unknown achievement ID: %s" % achievement_id)
		return

	# Check if already unlocked
	if achievements[achievement_id]:
		if debug_mode:
			print("SteamManager: Achievement already unlocked: %s" % achievement_id)
		return

	# Unlock on Steam
	if not Steam.setAchievement(achievement_id):
		push_error("SteamManager: Failed to set achievement: %s" % achievement_id)
		return

	# Store to Steam (required for achievement popup)
	store_steam_data()

	# Update local state
	achievements[achievement_id] = true

	print("SteamManager: ✓ Achievement unlocked: %s" % achievement_id)
	achievement_unlocked.emit(achievement_id)

func set_stat_int(stat_id: String, value: int) -> void:
	"""Set an integer statistic (absolute value)"""
	if not is_steam_available:
		if debug_mode:
			print("SteamManager: [OFFLINE] Stat set: %s = %d" % [stat_id, value])
		statistics[stat_id] = value
		return

	if not statistics.has(stat_id):
		push_warning("SteamManager: Unknown stat ID: %s" % stat_id)
		return

	# Update Steam
	if not Steam.setStatInt(stat_id, value):
		# push_error("SteamManager: Failed to set stat: %s" % stat_id)  # Commented until Steamworks backend configured
		return

	# Update local state
	statistics[stat_id] = value

	if debug_mode:
		print("SteamManager: Stat updated: %s = %d" % [stat_id, value])

	stats_updated.emit()

func increment_stat(stat_id: String, amount: int = 1) -> void:
	"""Increment a statistic by amount"""
	var current_value = statistics.get(stat_id, 0)
	set_stat_int(stat_id, current_value + amount)

func store_steam_data() -> void:
	"""Persist stats and achievements to Steam (required for popups)"""
	if not is_steam_available:
		return

	if not Steam.storeStats():
		push_error("SteamManager: Failed to store stats to Steam")
		return

	if debug_mode:
		print("SteamManager: Data successfully stored to Steam")

func update_playtime() -> void:
	"""Update total playtime statistic"""
	if session_start_time == 0:
		return

	var current_time: int = Time.get_ticks_msec()
	var session_duration_sec: int = int((current_time - session_start_time) / 1000.0)

	var new_total_playtime = total_playtime_seconds + session_duration_sec
	set_stat_int("STAT_PLAYTIME_SECONDS", new_total_playtime)
	total_playtime_seconds = new_total_playtime

	# Reset session timer
	session_start_time = current_time

	# Check playtime achievements
	check_playtime_achievements()

func check_playtime_achievements() -> void:
	"""Check and unlock playtime-based achievements"""
	var hours_played = total_playtime_seconds / 3600.0

	if hours_played >= 1.0:
		unlock_achievement("ACH_PLAY_1HOUR")

	if hours_played >= 10.0:
		unlock_achievement("ACH_PLAY_10HOURS")

func get_stat(stat_id: String) -> int:
	"""Get current value of a statistic"""
	return statistics.get(stat_id, 0)

func is_achievement_unlocked(achievement_id: String) -> bool:
	"""Check if an achievement is unlocked"""
	return achievements.get(achievement_id, false)

func reset_all_achievements_and_stats() -> void:
	"""DEVELOPER ONLY: Reset all achievements and stats for testing"""
	if not is_steam_available:
		return

	if not OS.has_feature("editor"):
		push_warning("SteamManager: reset_all_achievements_and_stats() should only be used in editor!")
		return

	Steam.resetAllStats(true)  # true = also reset achievements
	load_steam_stats()
	load_steam_achievements()

	print("SteamManager: All stats and achievements reset")

func _initialize_steam_input():
	"""Initialize Steam Input API"""
	if not _is_steam_singleton_available():
		return

	# Try to initialize Steam Input
	var init_result = Steam.inputInit(false)  # false = don't use explicit controller config

	if init_result:
		# Enable device callbacks for hot-plug support
		Steam.enableDeviceCallbacks()
		print("SteamManager: Steam Input device callbacks enabled")
		if DebugLogger:
			DebugLogger.write_log("[SteamManager] Device callbacks enabled - hot-swap supported")

		steam_input_enabled = true
		print("SteamManager: Steam Input initialized successfully")
		print("  Steam Input will provide superior controller support")
		if DebugLogger:
			DebugLogger.write_log("[SteamManager] Steam Input API enabled")
	else:
		steam_input_enabled = false
		print("SteamManager: Steam Input not available - using Godot Input fallback")
		if DebugLogger:
			DebugLogger.write_log("[SteamManager] Steam Input not available - using fallback")

func _exit_tree():
	"""Update playtime before exiting"""
	update_playtime()
	store_steam_data()
