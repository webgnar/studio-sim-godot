extends Node

## Global manager for painting missions
## Loads all available missions and tracks progression

signal mission_started(mission: PaintingMission)
signal mission_completed(mission: PaintingMission, result: ValidationResult)
signal mission_failed(mission: PaintingMission, result: ValidationResult)

# All available missions loaded from resources/missions/
var available_missions: Array[PaintingMission] = []

# Currently active mission (null if none)
var current_mission: PaintingMission = null

# Mission progression data (mission_id -> completion data)
# Format: {"mission_id": {"completed": true, "grade": "A", "best_score": 85.5}}
var progression: Dictionary = {}

func _ready():
	load_all_missions()
	load_progression()

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
	mission_started.emit(mission)

func complete_mission(result: ValidationResult):
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
			"best_score": 0.0
		}

	var mission_data = progression[mission_id]

	# Update if this is a better score
	if score > mission_data["best_score"]:
		mission_data["best_score"] = score
		mission_data["grade"] = grade

	# Mark as completed if passed
	if result.success:
		mission_data["completed"] = true
		mission_completed.emit(current_mission, result)
	else:
		mission_failed.emit(current_mission, result)

	save_progression()

func get_mission_completion(mission_id: String) -> Dictionary:
	"""Get completion data for a specific mission"""
	if progression.has(mission_id):
		return progression[mission_id]
	return {"completed": false, "grade": "F", "best_score": 0.0}

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
