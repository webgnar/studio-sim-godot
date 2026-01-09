extends Node

## Style repetition tracker - Penalizes similar paintings
## Autoload singleton that tracks recent paintings and calculates similarity penalties

# Recent paintings (last 3)
var recent_paintings: Array[Dictionary] = []

# Repetition penalty constants
const MAX_RECENT_PAINTINGS = 3
const SIMILARITY_THRESHOLD = 0.7  # 70% similar = penalty
const REPETITION_PENALTY = 0.7    # -30% price if similar
const MIN_PRICE_MULTIPLIER = 0.2  # Floor at 20% of base price

func _ready():
	print("StyleTracker: Initialized (tracking last %d paintings)" % MAX_RECENT_PAINTINGS)

func record_painting(sticker_ids: Array[String], colors: Array[Color]):
	"""Record a completed painting for similarity tracking"""
	var painting_data = {
		"stickers": sticker_ids.duplicate(),
		"colors": _extract_color_values(colors),
		"timestamp": Time.get_unix_time_from_system()
	}

	recent_paintings.append(painting_data)

	# Keep only last N paintings
	if recent_paintings.size() > MAX_RECENT_PAINTINGS:
		recent_paintings.pop_front()

	print("StyleTracker: Recorded painting with %d stickers, %d colors (history size: %d)" %
		[sticker_ids.size(), colors.size(), recent_paintings.size()])

func get_repetition_penalty() -> float:
	"""Calculate repetition penalty based on similarity to recent paintings
	Returns 1.0 (no penalty) or 0.7 (30% penalty) but never below 0.2 floor

	NOTE: Currently DISABLED because missions enforce variety naturally.
	May be useful later for freeform painting (Phase 4)."""

	# DISABLED: Missions already enforce variety
	return 1.0

	# Original logic (kept for potential Phase 4 freeform painting):
	#if recent_paintings.size() < 2:
	#	return 1.0  # Not enough history to compare
	#
	#var similarity = _calculate_similarity()
	#
	#if similarity > SIMILARITY_THRESHOLD:
	#	print("StyleTracker: High similarity detected (%.1f%%) - Applying penalty" % (similarity * 100))
	#	return max(REPETITION_PENALTY, MIN_PRICE_MULTIPLIER)
	#
	#return 1.0

func _calculate_similarity() -> float:
	"""Calculate similarity between most recent painting and previous ones"""
	if recent_paintings.size() < 2:
		return 0.0

	var latest = recent_paintings[-1]
	var similarities: Array[float] = []

	# Compare latest to each previous painting
	for i in range(recent_paintings.size() - 1):
		var previous = recent_paintings[i]
		var sim = _compare_paintings(latest, previous)
		similarities.append(sim)

	# Return highest similarity (most similar to any previous painting)
	var max_similarity = 0.0
	for sim in similarities:
		if sim > max_similarity:
			max_similarity = sim

	return max_similarity

func _compare_paintings(painting1: Dictionary, painting2: Dictionary) -> float:
	"""Compare two paintings and return similarity score (0.0-1.0)"""
	var sticker_similarity = _compare_sticker_arrays(painting1.stickers, painting2.stickers)
	var color_similarity = _compare_color_arrays(painting1.colors, painting2.colors)

	# Weighted average: stickers 60%, colors 40%
	return sticker_similarity * 0.6 + color_similarity * 0.4

func _compare_sticker_arrays(stickers1: Array, stickers2: Array) -> float:
	"""Calculate Jaccard similarity coefficient for sticker sets"""
	if stickers1.is_empty() and stickers2.is_empty():
		return 1.0

	if stickers1.is_empty() or stickers2.is_empty():
		return 0.0

	# Count matching stickers
	var matches = 0
	for sticker in stickers1:
		if sticker in stickers2:
			matches += 1

	# Jaccard similarity: intersection / union
	var union_size = stickers1.size() + stickers2.size() - matches
	return float(matches) / float(union_size)

func _compare_color_arrays(colors1: Array, colors2: Array) -> float:
	"""Calculate similarity between color palettes"""
	if colors1.is_empty() and colors2.is_empty():
		return 1.0

	if colors1.is_empty() or colors2.is_empty():
		return 0.0

	# For each color in palette1, find closest color in palette2
	var total_distance = 0.0
	for color1 in colors1:
		var min_distance = 1.0
		for color2 in colors2:
			var distance = _color_distance(color1, color2)
			if distance < min_distance:
				min_distance = distance
		total_distance += min_distance

	# Average distance (lower = more similar)
	var avg_distance = total_distance / colors1.size()

	# Convert distance to similarity (1.0 - distance)
	return 1.0 - avg_distance

func _color_distance(color1: Array, color2: Array) -> float:
	"""Calculate Euclidean distance between two RGB colors (normalized 0-1)"""
	if color1.size() < 3 or color2.size() < 3:
		return 1.0

	var dr = color1[0] - color2[0]
	var dg = color1[1] - color2[1]
	var db = color1[2] - color2[2]

	return sqrt(dr * dr + dg * dg + db * db) / sqrt(3.0)  # Normalize by max distance

func _extract_color_values(colors: Array[Color]) -> Array:
	"""Convert Color objects to simple [r, g, b] arrays for storage"""
	var color_values: Array = []
	for color in colors:
		color_values.append([color.r, color.g, color.b])
	return color_values

func clear_history():
	"""Clear all painting history (used on save/reset)"""
	recent_paintings.clear()
	print("StyleTracker: History cleared")

func get_recent_paintings() -> Array[Dictionary]:
	"""Get recent paintings array (for save system)"""
	return recent_paintings

func set_recent_paintings(paintings: Array):
	"""Set recent paintings array (for load system)"""
	recent_paintings.clear()
	for painting in paintings:
		recent_paintings.append(painting)
	print("StyleTracker: Loaded %d paintings from save" % recent_paintings.size())
