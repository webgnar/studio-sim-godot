extends Resource
class_name PaintingMission

## Represents a painting mission/challenge for the player to complete

@export var mission_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var target_stickers: Array[PlacedStickerData] = []  # Full placement data
@export var reference_image_path: String = ""  # Path to reference screenshot
@export var reward: int = 100
@export var difficulty: int = 1  # 1-10 scale

# Helper to get list of required sticker IDs
func get_required_stickers() -> Array[String]:
	var sticker_ids: Array[String] = []
	for sticker_data in target_stickers:
		if not sticker_ids.has(sticker_data.sticker_id):
			sticker_ids.append(sticker_data.sticker_id)
	return sticker_ids

func get_tolerance_settings() -> Dictionary:
	"""Calculate validation tolerances based on difficulty (1-10)"""
	# Linear interpolation between easy (1) and hard (10)
	# Difficulty 1: ±40px, ±40° (very forgiving)
	# Difficulty 5: ±20px, ±20° (medium)
	# Difficulty 10: ±5px, ±5° (pixel-perfect)
	var position_tolerance = lerp(40.0, 5.0, (difficulty - 1) / 9.0)
	var rotation_tolerance = lerp(40.0, 5.0, (difficulty - 1) / 9.0)

	return {
		"position": position_tolerance,
		"rotation": rotation_tolerance
	}

func _init(p_id: String = "", p_reward: int = 100):
	mission_id = p_id
	reward = p_reward
	target_stickers = []
