extends Resource
class_name PaintingMission

## Represents a painting mission/challenge for the player to complete

@export var mission_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var target_stickers: Array[PlacedStickerData] = []  # Full placement data
@export var reference_image_path: String = ""  # Path to reference screenshot
@export var reward: int = 100

# Helper to get list of required sticker IDs
func get_required_stickers() -> Array[String]:
	var sticker_ids: Array[String] = []
	for sticker_data in target_stickers:
		if not sticker_ids.has(sticker_data.sticker_id):
			sticker_ids.append(sticker_data.sticker_id)
	return sticker_ids

func get_pass_threshold() -> float:
	return 65.0

func get_color_tolerance() -> float:
	return 20.0

func _init(p_id: String = "", p_reward: int = 100):
	mission_id = p_id
	reward = p_reward
	target_stickers = []
