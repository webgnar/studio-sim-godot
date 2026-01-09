extends Node

## Global reputation manager - Tracks reputation points and levels
## Autoload singleton for managing artist reputation progression

# Reputation state
var reputation_level: int = 0
var reputation_points: float = 0.0

# Level thresholds (exponential progression)
const LEVEL_THRESHOLDS = [0, 10, 30, 60, 100, 150, 210, 280, 360, 450, 550]

# Signals
signal reputation_changed(new_points: float, new_level: int)
signal level_up(new_level: int, old_level: int)

func _ready():
	print("ReputationManager: Initialized at Level %d (%.1f points)" % [reputation_level, reputation_points])

func add_reputation(amount: float, source: String = "unknown"):
	"""Add reputation points and check for level up"""
	reputation_points += amount
	print("ReputationManager: +%.2f reputation from %s (Total: %.1f)" % [amount, source, reputation_points])

	_check_level_up()
	reputation_changed.emit(reputation_points, reputation_level)

func _check_level_up():
	"""Check if player has leveled up and emit signal if so"""
	var old_level = reputation_level

	# Check each threshold from current level upward
	for i in range(reputation_level + 1, LEVEL_THRESHOLDS.size()):
		if reputation_points >= LEVEL_THRESHOLDS[i]:
			reputation_level = i
		else:
			break

	# Emit level up signal if leveled up
	if reputation_level > old_level:
		print("ReputationManager: LEVEL UP! %d → %d" % [old_level, reputation_level])
		level_up.emit(reputation_level, old_level)

func get_price_multiplier() -> float:
	"""Calculate price multiplier based on reputation level (+20% per level)"""
	return 1.0 + (reputation_level * 0.2)

func get_reputation_level() -> int:
	"""Get current reputation level"""
	return reputation_level

func get_reputation_points() -> float:
	"""Get current reputation points"""
	return reputation_points

func get_points_to_next_level() -> float:
	"""Get points needed to reach next level"""
	if reputation_level >= LEVEL_THRESHOLDS.size() - 1:
		return 0.0  # Max level

	var next_threshold = LEVEL_THRESHOLDS[reputation_level + 1]
	return next_threshold - reputation_points

func get_level_progress() -> float:
	"""Get progress to next level as 0.0-1.0"""
	if reputation_level >= LEVEL_THRESHOLDS.size() - 1:
		return 1.0  # Max level

	var current_threshold = LEVEL_THRESHOLDS[reputation_level]
	var next_threshold = LEVEL_THRESHOLDS[reputation_level + 1]
	var range_size = next_threshold - current_threshold
	var progress = reputation_points - current_threshold

	return clamp(progress / range_size, 0.0, 1.0)

func set_reputation(points: float, level: int):
	"""Set reputation directly (used by save system)"""
	reputation_points = points
	reputation_level = level
	reputation_changed.emit(reputation_points, reputation_level)
