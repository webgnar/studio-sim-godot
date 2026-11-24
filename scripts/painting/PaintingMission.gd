extends Resource
class_name PaintingMission

## Represents a painting mission/challenge for the player to complete

@export var mission_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var target_stickers: Array[PlacedStickerData] = []  # Full placement data
@export var reference_image_path: String = ""  # Path to reference screenshot
@export var reward: int = 75

## Hall of fame commissions are built at startup from res://hall_of_fame/manifest.json
## (see MissionManager.HALL_OF_FAME_SLOTS), not saved as .tres files.
var is_hall_of_fame: bool = false
## Who painted it (hall of fame only), shown in the commission's description.
var artist_name: String = ""
## Sticker recording that came with the upload (hall of fame only), for Watch Replay.
var recording_path_override: String = ""

# Helper to get list of required sticker IDs
func get_required_stickers() -> Array[String]:
	var sticker_ids: Array[String] = []
	for sticker_data in target_stickers:
		if not sticker_ids.has(sticker_data.sticker_id):
			sticker_ids.append(sticker_data.sticker_id)
	return sticker_ids

## The sticker-by-sticker recording saved next to this mission
## (<mission>_recording.json), or {} if it has none. See PaintingRecording.
func get_recording_path() -> String:
	if recording_path_override != "":
		return recording_path_override
	return PaintingRecording.path_for_mission(resource_path) if resource_path != "" else ""

func has_recording() -> bool:
	var path := get_recording_path()
	return path != "" and FileAccess.file_exists(path)

func load_recording() -> Dictionary:
	return PaintingRecording.load_file(get_recording_path())

func get_pass_threshold() -> float:
	return 65.0

func get_color_tolerance() -> float:
	return 20.0

func _init(p_id: String = "", p_reward: int = 75):
	mission_id = p_id
	reward = p_reward
	target_stickers = []
