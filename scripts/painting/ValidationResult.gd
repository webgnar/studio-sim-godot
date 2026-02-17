extends RefCounted
class_name ValidationResult

## Result of validating a painting against a mission
## Provides detailed feedback on what matched and what didn't

var success: bool = false
var errors: Array[String] = []
var correct_count: int = 0
var total_count: int = 0

# Placement-based validation (new system)
var match_percentage: float = 0.0  # 0.0 to 100.0 (final blended score)
var per_sticker_scores: Array[float] = []  # Individual scores for each sticker (0.0 to 1.0)
var pass_threshold: float = 70.0  # Minimum percentage to pass

# Hybrid validation scores (visual + coordinate)
var coordinate_match_percentage: float = 0.0  # Position/rotation accuracy (0.0-100.0)
var visual_match_percentage: float = 0.0  # Pixel-level visual similarity (0.0-100.0)
var color_distribution_score: float = 0.0  # Color histogram similarity (0.0-100.0)
var validation_weights: Dictionary = {}  # Weights used for blending scores

# Analysis data (heatmap, histograms, etc.)
var debug_data: Dictionary = {}

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
	"""Set the placement-based validation score (backward compatibility)"""
	coordinate_match_percentage = clamp(percentage, 0.0, 100.0)
	match_percentage = coordinate_match_percentage
	per_sticker_scores = sticker_scores
	success = (match_percentage >= pass_threshold)

func set_simple_score(visual_score: float, color_score: float, pass_threshold_override: float):
	"""Set simplified validation score using visual and color distribution only"""
	visual_match_percentage = clamp(visual_score, 0.0, 100.0)
	color_distribution_score = clamp(color_score, 0.0, 100.0)

	# Fixed weights: Color histogram (70%) + Visual pixel (30%)
	match_percentage = (color_distribution_score * 0.7 + visual_match_percentage * 0.3)
	match_percentage = clamp(match_percentage, 0.0, 100.0)

	# Use difficulty-based pass threshold
	pass_threshold = pass_threshold_override
	success = (match_percentage >= pass_threshold)

func set_hybrid_score(coord_score: float, visual_score: float, color_score: float, weights: Dictionary, sticker_scores: Array[float]):
	"""DEPRECATED: Use set_simple_score() instead. Kept for backward compatibility."""
	coordinate_match_percentage = clamp(coord_score, 0.0, 100.0)
	visual_match_percentage = clamp(visual_score, 0.0, 100.0)
	color_distribution_score = clamp(color_score, 0.0, 100.0)
	validation_weights = weights

	# Blend scores using weights
	var coord_weight = weights.get("coordinate", 0.5)
	var visual_weight = weights.get("visual", 0.4)
	var color_weight = weights.get("color", 0.1)

	match_percentage = (
		coordinate_match_percentage * coord_weight +
		visual_match_percentage * visual_weight +
		color_distribution_score * color_weight
	)
	match_percentage = clamp(match_percentage, 0.0, 100.0)

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
