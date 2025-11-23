extends RefCounted
class_name VisualValidator

## Visual validation utilities for comparing painted images
## Provides pixel-by-pixel comparison and color distribution analysis

static func compare_images(current: Image, reference: Image, color_tolerance: float = 20.0) -> Dictionary:
	"""
	Compare two images pixel-by-pixel and return similarity metrics

	Args:
		current: The player's painted image
		reference: The target reference image
		color_tolerance: Maximum RGB difference to consider a pixel matching (0-255)

	Returns:
		Dictionary with:
			- visual_score: 0.0-100.0 percentage of matching pixels
			- total_pixels: Total number of pixels compared
			- matching_pixels: Number of pixels within tolerance
	"""

	if not current or not reference:
		push_error("VisualValidator: Cannot compare null images!")
		return {"visual_score": 0.0, "total_pixels": 0, "matching_pixels": 0}

	# Ensure both images have the same size
	var current_size = current.get_size()
	var reference_size = reference.get_size()

	if current_size != reference_size:
		push_warning("VisualValidator: Image size mismatch! Current: %s, Reference: %s" % [current_size, reference_size])
		# Resize current to match reference
		current.resize(reference_size.x, reference_size.y, Image.INTERPOLATE_LANCZOS)

	var width = reference_size.x
	var height = reference_size.y
	var total_pixels = width * height
	var matching_pixels = 0

	# Compare pixel-by-pixel
	for y in range(height):
		for x in range(width):
			var current_color = current.get_pixel(x, y)
			var reference_color = reference.get_pixel(x, y)

			# Skip fully transparent pixels in reference (background)
			if reference_color.a < 0.1:
				total_pixels -= 1
				continue

			# Calculate color distance (RGB only, ignore alpha)
			var color_diff = _color_distance(current_color, reference_color)

			if color_diff <= color_tolerance:
				matching_pixels += 1

	# Calculate percentage
	var visual_score = 0.0
	if total_pixels > 0:
		visual_score = (float(matching_pixels) / float(total_pixels)) * 100.0

	return {
		"visual_score": visual_score,
		"total_pixels": total_pixels,
		"matching_pixels": matching_pixels
	}

static func calculate_color_distribution(image: Image) -> Dictionary:
	"""
	Analyze color distribution in an image

	Returns:
		Dictionary with color histogram data (simplified buckets)
	"""

	if not image:
		return {}

	var size = image.get_size()
	var histogram = {
		"red": 0.0,
		"green": 0.0,
		"blue": 0.0,
		"alpha": 0.0,
		"pixel_count": 0
	}

	# Sample every pixel and accumulate color values
	for y in range(size.y):
		for x in range(size.x):
			var color = image.get_pixel(x, y)

			# Skip fully transparent pixels
			if color.a < 0.1:
				continue

			histogram["red"] += color.r
			histogram["green"] += color.g
			histogram["blue"] += color.b
			histogram["alpha"] += color.a
			histogram["pixel_count"] += 1

	# Average the values
	if histogram["pixel_count"] > 0:
		var count = float(histogram["pixel_count"])
		histogram["red"] /= count
		histogram["green"] /= count
		histogram["blue"] /= count
		histogram["alpha"] /= count

	return histogram

static func compare_color_distributions(current_hist: Dictionary, reference_hist: Dictionary) -> float:
	"""
	Compare two color histograms and return similarity score (0.0-100.0)
	"""

	if current_hist.is_empty() or reference_hist.is_empty():
		return 0.0

	# Calculate difference in each channel
	var r_diff = abs(current_hist.get("red", 0.0) - reference_hist.get("red", 0.0))
	var g_diff = abs(current_hist.get("green", 0.0) - reference_hist.get("green", 0.0))
	var b_diff = abs(current_hist.get("blue", 0.0) - reference_hist.get("blue", 0.0))

	# Average difference (0.0-1.0 range)
	var avg_diff = (r_diff + g_diff + b_diff) / 3.0

	# Convert to similarity percentage (invert difference)
	var similarity = (1.0 - avg_diff) * 100.0

	return clamp(similarity, 0.0, 100.0)

static func _color_distance(color1: Color, color2: Color) -> float:
	"""
	Calculate Euclidean distance between two colors (RGB only)
	Returns value in 0-255 range for easier tolerance comparison
	"""

	var r_diff = (color1.r - color2.r) * 255.0
	var g_diff = (color1.g - color2.g) * 255.0
	var b_diff = (color1.b - color2.b) * 255.0

	# Euclidean distance
	var distance = sqrt(r_diff * r_diff + g_diff * g_diff + b_diff * b_diff)

	return distance
