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
	# Difficulty 1: ±100px, ±100° (very forgiving)
	# Difficulty 5: ±50px, ±50° (medium)
	# Difficulty 10: ±5px, ±5° (pixel-perfect)
	var position_tolerance = lerp(1000.0, 5.0, (difficulty - 1) / 9.0)
	var rotation_tolerance = lerp(1000.0, 5.0, (difficulty - 1) / 9.0)

	return {
		"position": position_tolerance,
		"rotation": rotation_tolerance
	}

func get_validation_weights() -> Dictionary:
	"""Calculate validation score weights based on difficulty (1-10)"""
	# Difficulty-based weight distribution for hybrid validation
	# Easy difficulties: Emphasize visual similarity (more forgiving)
	# Hard difficulties: Emphasize coordinate precision (stricter)

	var coord_weight: float
	var visual_weight: float
	var color_weight: float

	if difficulty <= 3:
		# Easy: Visual matters most (artistic mode)
		coord_weight = 0.2
		visual_weight = 0.7
		color_weight = 0.1
	elif difficulty <= 7:
		# Medium: Balanced approach
		coord_weight = 0.5
		visual_weight = 0.4
		color_weight = 0.1
	else:
		# Hard: Coordinate precision matters most
		coord_weight = 0.7
		visual_weight = 0.2
		color_weight = 0.1

	return {
		"coordinate": coord_weight,
		"visual": visual_weight,
		"color": color_weight
	}

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
