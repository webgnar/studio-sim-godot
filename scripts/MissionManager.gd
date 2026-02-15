extends Node

## Global manager for painting missions
## Loads all available missions and tracks progression

signal mission_started(mission: PaintingMission)
signal mission_completed(mission: PaintingMission, result: ValidationResult)
signal mission_failed(mission: PaintingMission, result: ValidationResult)
signal mission_aborted(mission: PaintingMission)

# All available missions loaded from resources/missions/
var available_missions: Array[PaintingMission] = []

# Currently active mission (null if none)
var current_mission: PaintingMission = null

# Mission progression data (mission_id -> completion data)
# Format: {"mission_id": {"completed": true, "grade": "A", "best_score": 85.5}}
var progression: Dictionary = {}

# Mission timing for Steam achievements
var mission_start_time: int = 0

# No-save achievement tracking (runtime only, resets each session)
var has_manually_saved: bool = false

func _ready():
	ensure_paintings_directory()
	load_all_missions()
	load_progression()

func ensure_paintings_directory():
	"""Create mission_paintings directory if it doesn't exist"""
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("mission_paintings"):
			var error = dir.make_dir("mission_paintings")
			if error == OK:
				print("MissionManager: Created mission_paintings directory")
			else:
				push_error("MissionManager: Failed to create mission_paintings directory!")
	else:
		push_error("MissionManager: Failed to access user directory!")

func load_all_missions():
	"""Load all mission .tres files using the missions manifest"""
	available_missions.clear()

	var missions_path = "res://resources/missions/"
	var manifest_path = missions_path + "missions_manifest.json"

	# Load the manifest file
	if not FileAccess.file_exists(manifest_path):
		push_error("MissionManager: Manifest file not found: %s" % manifest_path)
		push_error("  Please run the mission_manifest_generator.gd script to create it.")
		return

	var file = FileAccess.open(manifest_path, FileAccess.READ)
	if not file:
		push_error("MissionManager: Failed to open manifest: %s" % manifest_path)
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)

	if error != OK:
		push_error("MissionManager: Failed to parse manifest JSON!")
		return

	var manifest = json.data
	if not manifest.has("missions"):
		push_error("MissionManager: Invalid manifest format - missing 'missions' key")
		return

	var file_names: Array = manifest["missions"]

	# Load each mission resource
	for filename in file_names:
		var path = missions_path + filename
		var mission = load(path) as PaintingMission

		if mission:
			available_missions.append(mission)
		else:
			push_error("MissionManager: Failed to load mission: %s" % path)

	# Sort by difficulty (easiest first)
	available_missions.sort_custom(func(a, b): return a.difficulty < b.difficulty)

	print("MissionManager: Loaded %d missions from manifest" % available_missions.size())

func start_mission(mission: PaintingMission):
	"""Start a new mission"""
	if not mission:
		push_error("MissionManager: Cannot start null mission!")
		return

	current_mission = mission
	mission_start_time = Time.get_ticks_msec()  # Track mission start for Steam achievements
	mission_started.emit(mission)

	# Transition to IN_MISSION state
	if UIManager:
		UIManager.change_state(UIManager.GameState.IN_MISSION)

func complete_mission(result: ValidationResult, latest_painting_path: String = "", best_painting_path: String = ""):
	"""Mark current mission as completed with the given result"""
	if not current_mission:
		push_error("MissionManager: No active mission to complete!")
		return

	# Update progression data
	var mission_id = current_mission.mission_id
	var grade = result.get_grade()
	var score = result.match_percentage

	if not progression.has(mission_id):
		progression[mission_id] = {
			"completed": false,
			"grade": "F",
			"best_score": 0.0,
			"latest_painting_path": "",
			"best_painting_path": ""
		}

	var mission_data = progression[mission_id]
	var was_completed_before = mission_data["completed"]  # Track for Steam achievements

	# Always update latest painting path
	if latest_painting_path != "":
		mission_data["latest_painting_path"] = latest_painting_path

	# Update if this is a better score
	if score > mission_data["best_score"]:
		mission_data["best_score"] = score
		mission_data["grade"] = grade
		# Update best painting path only if this is the new best
		if best_painting_path != "":
			mission_data["best_painting_path"] = best_painting_path

	# Mark as completed if passed
	if result.success:
		mission_data["completed"] = true
		mission_completed.emit(current_mission, result)

		# Calculate mission duration for Steam
		var mission_duration_sec: float = 0.0
		if mission_start_time > 0:
			mission_duration_sec = (Time.get_ticks_msec() - mission_start_time) / 1000.0

		# === PHASE 0: Economy Integration ===
		# Calculate payout based on reputation and repetition
		var base_price = 100  # $100 base
		var commission_bonus = 1.5  # +50% for commissioned work
		var rep_multiplier = 1.0
		var repetition_penalty = 1.0

		# Get reputation multiplier if ReputationManager exists
		if has_node("/root/ReputationManager"):
			rep_multiplier = ReputationManager.get_price_multiplier()

		# Get repetition penalty if StyleTracker exists
		if has_node("/root/StyleTracker"):
			repetition_penalty = StyleTracker.get_repetition_penalty()

		# Calculate final payout
		var payout = int(base_price * commission_bonus * rep_multiplier * repetition_penalty)
		payout = max(payout, int(base_price * 0.2))  # Floor at 20% of base

		# Award money if EconomyManager exists
		if has_node("/root/EconomyManager"):
			EconomyManager.add_money(payout, "mission: " + current_mission.title)

		# Award reputation (0.5-2.0 points based on validation score)
		if has_node("/root/ReputationManager"):
			var rep_gain = (result.match_percentage / 100.0) * 2.0
			ReputationManager.add_reputation(rep_gain, "mission")

		# Track painting style for repetition detection
		if has_node("/root/StyleTracker") and has_node("/root/PaintingSystem2D"):
			var painting_system = get_node("/root/World/PaintingRoot2D/PaintingSystem2D")
			if painting_system:
				var sticker_ids = _extract_sticker_ids(painting_system.placed_layers)
				var colors = _extract_dominant_colors(painting_system.placed_layers)
				StyleTracker.record_painting(sticker_ids, colors)

		# Update Steam achievements and stats
		if SteamManager:
			_update_steam_on_mission_complete(
				current_mission, result, score, grade,
				mission_duration_sec, was_completed_before
			)
	else:
		mission_failed.emit(current_mission, result)

		# Track failed attempts in Steam
		if SteamManager:
			SteamManager.increment_stat("STAT_MISSIONS_FAILED")

	save_progression()

	# Transition to VALIDATION state
	if UIManager:
		UIManager.change_state(UIManager.GameState.VALIDATION)

func abort_mission():
	"""Abort the current mission without saving progress"""
	if not current_mission:
		push_error("MissionManager: No active mission to abort!")
		return

	var aborted_mission = current_mission
	mission_aborted.emit(aborted_mission)
	current_mission = null

	print("MissionManager: Mission '%s' aborted" % aborted_mission.title)

func get_mission_completion(mission_id: String) -> Dictionary:
	"""Get completion data for a specific mission"""
	if progression.has(mission_id):
		var data = progression[mission_id]
		# Ensure painting path fields exist (backward compatibility)
		if not data.has("latest_painting_path"):
			data["latest_painting_path"] = ""
		if not data.has("best_painting_path"):
			data["best_painting_path"] = ""
		return data
	return {
		"completed": false,
		"grade": "F",
		"best_score": 0.0,
		"latest_painting_path": "",
		"best_painting_path": ""
	}

func is_mission_completed(mission_id: String) -> bool:
	"""Check if a mission has been completed"""
	return progression.has(mission_id) and progression[mission_id]["completed"]

func save_progression():
	"""Save progression data to user data"""
	var save_path = "user://mission_progression.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)

	if file:
		var json_string = JSON.stringify(progression, "\t")
		file.store_string(json_string)
		file.close()
	else:
		push_error("MissionManager: Failed to save progression!")

func load_progression():
	"""Load progression data from user data"""
	var save_path = "user://mission_progression.json"

	if not FileAccess.file_exists(save_path):
		return

	var file = FileAccess.open(save_path, FileAccess.READ)

	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var error = json.parse(json_string)

		if error == OK:
			progression = json.data
		else:
			push_error("MissionManager: Failed to parse progression JSON!")
	else:
		push_error("MissionManager: Failed to open progression file!")

func _update_steam_on_mission_complete(_mission: PaintingMission, result: ValidationResult, score: float, grade: String, duration_sec: float, was_completed_before: bool):
	"""Handle all Steam achievement/stat updates for mission completion"""

	# Update statistics
	if not was_completed_before:
		SteamManager.increment_stat("STAT_MISSIONS_COMPLETED")

	# Track perfect missions
	if result.is_perfect():
		SteamManager.increment_stat("STAT_MISSIONS_PERFECT")

	# Track S-rank missions
	if grade == "S":
		SteamManager.increment_stat("STAT_MISSIONS_S_RANK")

	# Update best score
	var current_best = SteamManager.get_stat("STAT_BEST_SCORE")
	if int(score) > current_best:
		SteamManager.set_stat_int("STAT_BEST_SCORE", int(score))

	# Update total score
	SteamManager.increment_stat("STAT_TOTAL_SCORE", int(score))

	# Achievement: Speedrunner (under 60 seconds)
	if duration_sec > 0.0 and duration_sec < 60.0:
		SteamManager.unlock_achievement("ACH_SPEEDRUNNER")

	# Achievement: Complete all co-missions without manual save
	if not has_manually_saved:
		var all_completed = true
		for m in available_missions:
			if not is_mission_completed(m.mission_id):
				all_completed = false
				break
		if all_completed:
			SteamManager.unlock_achievement("ACH_ALL_MISSIONS_NO_SAVE")

	# Store all changes to Steam
	SteamManager.store_steam_data()

func _extract_sticker_ids(placed_layers: Array) -> Array[String]:
	"""Extract sticker IDs from placed layers for style tracking"""
	var sticker_ids: Array[String] = []

	for layer in placed_layers:
		if layer.has("id"):
			sticker_ids.append(str(layer.id))

	return sticker_ids

func _extract_dominant_colors(placed_layers: Array) -> Array[Color]:
	"""Extract dominant colors from placed layers for style tracking"""
	var colors: Array[Color] = []

	# For now, extract colors from sticker textures
	# This is a simplified version - can be enhanced later
	for layer in placed_layers:
		if layer.has("node") and layer.node:
			var sprite = layer.node as Sprite2D
			if sprite and sprite.texture:
				# Sample center pixel of texture (simplified)
				var tex = sprite.texture as Texture2D
				if tex:
					# For now, use a placeholder color based on texture path
					# In a real implementation, you'd sample the texture
					colors.append(Color(randf(), randf(), randf()))

	# Limit to top 5 colors
	if colors.size() > 5:
		colors.resize(5)

	return colors
