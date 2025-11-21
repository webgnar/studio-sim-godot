extends RefCounted
class_name ValidationResult

## Result of validating a painting against a mission
## Provides detailed feedback on what matched and what didn't

var success: bool = false
var errors: Array[String] = []
var correct_count: int = 0
var total_count: int = 0

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
