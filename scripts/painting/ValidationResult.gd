extends RefCounted
class_name ValidationResult

## Result of validating a painting against a mission
## Provides detailed feedback on what matched and what didn't

var success: bool = false
var errors: Array[String] = []
var correct_count: int = 0
var total_count: int = 0

# Placement-based validation (new system)
var match_percentage: float = 0.0  # 0.0 to 100.0
var per_sticker_scores: Array[float] = []  # Individual scores for each sticker (0.0 to 1.0)
var pass_threshold: float = 70.0  # Minimum percentage to pass

func _init(p_success: bool = false):
	success = p_success

func add_error(message: String):
	"""Add an error message to the result"""
	errors.append(message)
	success = false

func get_accuracy() -> float:
	"""Calculate accuracy percentage (0.0 to 1.0)"""
	if total_count == 0:
		return 0.0
	return float(correct_count) / float(total_count)

func get_accuracy_percentage() -> int:
	"""Get accuracy as integer percentage (0 to 100)"""
	return int(get_accuracy() * 100.0)

func is_perfect() -> bool:
	"""Check if the painting was a perfect match"""
	return success and errors.is_empty() and correct_count == total_count

func set_placement_score(percentage: float, sticker_scores: Array[float]):
	"""Set the placement-based validation score"""
	match_percentage = clamp(percentage, 0.0, 100.0)
	per_sticker_scores = sticker_scores
	success = (match_percentage >= pass_threshold)

func get_grade() -> String:
	"""Get a letter grade based on match percentage"""
	if match_percentage >= 95.0:
		return "S"
	elif match_percentage >= 85.0:
		return "A"
	elif match_percentage >= 75.0:
		return "B"
	elif match_percentage >= 65.0:
		return "C"
	elif match_percentage >= 50.0:
		return "D"
	else:
		return "F"
