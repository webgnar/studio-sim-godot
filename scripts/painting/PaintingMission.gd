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

func get_pass_threshold() -> float:
	"""Get the pass threshold percentage based on difficulty level"""
	if difficulty <= 3:
		return 60.0  # Easy: 60% to pass
	elif difficulty <= 7:
		return 80.0  # Medium: 80% to pass
	else:
		return 95.0  # Hard: 95% to pass

func get_color_tolerance() -> float:
	"""Calculate color tolerance for pixel comparison based on difficulty"""
	# Difficulty 1: ±30 RGB (very forgiving color matching)
	# Difficulty 5: ±20 RGB (medium)
	# Difficulty 10: ±10 RGB (strict color matching)
	return lerp(30.0, 10.0, (difficulty - 1) / 9.0)

func _init(p_id: String = "", p_reward: int = 100):
	mission_id = p_id
	reward = p_reward
	target_stickers = []
