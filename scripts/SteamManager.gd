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

# User info
var persona_name: String = ""


# Debug mode
var debug_mode: bool = false

func _ready():
	setup_achievements()
	setup_statistics()
	initialize_steam()
	# Retroactively unlock export achievements based on save data (fixes players affected by stat-tracking bug)
	if WorldStateManager:
		WorldStateManager.world_state_loaded.connect(_check_retroactive_export_achievements, CONNECT_ONE_SHOT)
		WorldStateManager.world_state_loaded.connect(_check_retroactive_visitor_achievement, CONNECT_ONE_SHOT)

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
	persona_name = Steam.getPersonaName()

	print("SteamManager: Steam initialized successfully!")
	print("  User: %s (ID: %d)" % [persona_name, steam_id])
	print("  Online: %s" % is_online)

	# Load Steam data
	load_steam_stats()
	load_steam_achievements()

	# Initialize Steam Input API
	_initialize_steam_input()

	steam_initialized.emit(true)

func _check_retroactive_export_achievements() -> void:
	"""On load, count shipped paintings from save data and unlock any earned achievements retroactively"""
	var all_paintings = WorldStateManager.get_all_paintings()
	var shipped_count = 0
	for p in all_paintings:
		if p.get("status", "") == "SHIPPED":
			shipped_count += 1

	if shipped_count == 0:
		return

	# Use whichever is higher: the Steam-tracked stat or the actual save data count
	var tracked = get_stat("STAT_PAINTINGS_EXPORTED")
	if shipped_count > tracked:
		set_stat_int("STAT_PAINTINGS_EXPORTED", shipped_count)
		if debug_mode:
			print("SteamManager: Retroactive stat update — STAT_PAINTINGS_EXPORTED: %d → %d" % [tracked, shipped_count])

	var final_count = get_stat("STAT_PAINTINGS_EXPORTED")
	if final_count >= 1:
		unlock_achievement("ACH_EXPORT_PAINTING")
	if final_count >= 5:
		unlock_achievement("ACH_EXPORT_5")
	if final_count >= 10:
		unlock_achievement("ACH_EXPORT_10")
	if final_count >= 20:
		unlock_achievement("ACH_EXPORT_20")
	if final_count >= 50:
		unlock_achievement("ACH_EXPORT_50")

func _check_retroactive_visitor_achievement() -> void:
	"""On load, unlock ACH_ALL_VISITORS if the player has already seen all 12 visitor skins."""
	if WorldStateManager.get_seen_visitor_skins().size() >= 12:
		unlock_achievement("ACH_ALL_VISITORS")

func setup_achievements() -> void:
	"""Define all achievements (must match Steamworks backend)"""
	achievements = {
		# Skill
		"ACH_SPEEDRUNNER": false,  # Complete mission under 1 minute
		"ACH_ALL_MISSIONS_NO_SAVE": false,  # Complete all co-missions without saving

		# Painting / Stickers
		"ACH_PAINTER": false,  # Place 500 2D stickers in missions
		"ACH_TAGGER": false,  # Place 100 3D stickers in the world
		"ACH_EXPORT_PAINTING": false,  # Export a painting
		"ACH_EXPORT_5": false,
		"ACH_EXPORT_10": false,
		"ACH_EXPORT_20": false,
		"ACH_EXPORT_50": false,

		# Discovery / Fun
		"ACH_FAN": false,  # Turn on the Stanley
		"ACH_NAILGUN": false,  # Break a window with the nailgun
		"ACH_ELEVATOR": false,  # Lock yourself in the elevator
		"ACH_DIE": false,  # Cause the player to die
		"ACH_LET_THERE_BE_LIGHT": false,  # Turn on lightswitch3 in light switch box2

		# Social
		"ACH_INSTAGRAM_10": false,  # Receive 10 or more Instagram likes on a painting

		# Shop
		"ACH_BRAVE_NEW_WORLD": false,  # Purchase all three free energy devices (GEET, Water Fuel Cell, SEG)
		"ACH_CONSCIOUSNESS_CREATES_REALITY": false,  # Purchase the Custom Sticker button
"ACH_STUDIO_ASSISTANT": false,  # Purchase the studio assistant

		# Commissions
		"ACH_ALL_MISSIONS_COMPLETED": false,  # Complete all commissions

		# Gallery
		"ACH_ALL_VISITORS": false,  # Encounter all 12 unique gallery visitors

	}

func setup_statistics() -> void:
	"""Define all statistics (must match Steamworks backend)"""
	statistics = {
		# Mission tracking
		"STAT_MISSIONS_COMPLETED": 0,
		"STAT_MISSIONS_PERFECT": 0,
		"STAT_MISSIONS_S_RANK": 0,
		"STAT_MISSIONS_FAILED": 0,

		# Sticker tracking (split by system)
		"STAT_STICKERS_PLACED_2D": 0,  # 2D mission stickers
		"STAT_STICKERS_PLACED_3D": 0,  # 3D world stickers
		"STAT_PAINTINGS_EXPORTED": 0,

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

	stats_ready.emit()

func unlock_achievement(achievement_id: String) -> void:
	"""Unlock an achievement (idempotent - safe to call multiple times)"""
	if not achievements.has(achievement_id):
		push_warning("SteamManager: Unknown achievement ID: %s" % achievement_id)
		return

	# Check if already unlocked
	if achievements[achievement_id]:
		if debug_mode:
			print("SteamManager: Achievement already unlocked: %s" % achievement_id)
		return

	# Update local state
	achievements[achievement_id] = true

	if not is_steam_available:
		print("SteamManager: [OFFLINE] Achievement unlocked: %s" % achievement_id)
	else:
		# Unlock on Steam
		if not Steam.setAchievement(achievement_id):
			push_error("SteamManager: Failed to set achievement: %s" % achievement_id)
		else:
			store_steam_data()

	print("SteamManager: ✓ Achievement unlocked: %s" % achievement_id)
	achievement_unlocked.emit(achievement_id)

func debug_unlock_all_achievements() -> void:
	"""DEBUG ONLY: Unlock all achievements to test completionist flow"""
	if not debug_mode:
		return
	print("SteamManager: [DEBUG] Unlocking all achievements...")
	for id in achievements.keys():
		unlock_achievement(id)

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

	# Always update local state first so get_stat() reflects the change even if Steam sync fails
	statistics[stat_id] = value

	# Update Steam
	if not Steam.setStatInt(stat_id, value):
		# push_error("SteamManager: Failed to set stat: %s" % stat_id)  # Commented until Steamworks backend configured
		return

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
	"""Store data before exiting"""
	store_steam_data()
