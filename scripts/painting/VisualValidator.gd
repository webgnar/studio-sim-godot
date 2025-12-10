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
			var color_diff = color_distance(current_color, reference_color)

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
	Analyze color distribution and extract top 3 most frequent colors

	Returns:
		Dictionary with:
			- red, green, blue, alpha: Average color (backward compatibility)
			- pixel_count: Total non-transparent pixels
			- top_colors: Array of top 3 {color: Color, count: int, percentage: float}
	"""

	if not image:
		return {}

	var size = image.get_size()

	# Build color frequency map (bucketed to reduce unique colors)
	var color_buckets = {}  # Quantized color -> count
	var total_pixels = 0
	var sum_r = 0.0
	var sum_g = 0.0
	var sum_b = 0.0

	# Bucket size: 16 RGB steps (256/16 = 16 buckets per channel)
	# This reduces color space from 16M colors to ~4K buckets
	var bucket_size = 16

	for y in range(size.y):
		for x in range(size.x):
			var color = image.get_pixel(x, y)

			# Skip fully transparent pixels
			if color.a < 0.1:
				continue

			# Quantize color to bucket (reduces near-identical colors)
			var r_bucket = int((color.r * 255) / bucket_size) * bucket_size
			var g_bucket = int((color.g * 255) / bucket_size) * bucket_size
			var b_bucket = int((color.b * 255) / bucket_size) * bucket_size
			var bucket_key = "%d,%d,%d" % [r_bucket, g_bucket, b_bucket]

			# Increment bucket count
			color_buckets[bucket_key] = color_buckets.get(bucket_key, 0) + 1

			# Accumulate for average
			sum_r += color.r
			sum_g += color.g
			sum_b += color.b
			total_pixels += 1

	if total_pixels == 0:
		return {}

	# Sort buckets by frequency and get top 3
	var sorted_buckets = []
	for bucket_key in color_buckets:
		var parts = bucket_key.split(",")
		var bucket_color = Color(
			int(parts[0]) / 255.0,
			int(parts[1]) / 255.0,
			int(parts[2]) / 255.0,
			1.0
		)
		sorted_buckets.append({
			"color": bucket_color,
			"count": color_buckets[bucket_key]
		})

	sorted_buckets.sort_custom(func(a, b): return a["count"] > b["count"])

	# Extract top 3 with percentages
	var top_colors = []
	for i in range(min(3, sorted_buckets.size())):
		var bucket = sorted_buckets[i]
		top_colors.append({
			"color": bucket["color"],
			"count": bucket["count"],
			"percentage": (float(bucket["count"]) / total_pixels) * 100.0
		})

	# Return both old format (backward compat) and new top colors
	return {
		"red": sum_r / total_pixels,
		"green": sum_g / total_pixels,
		"blue": sum_b / total_pixels,
		"alpha": 1.0,
		"pixel_count": total_pixels,
		"top_colors": top_colors
	}

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

static func color_distance(color1: Color, color2: Color) -> float:
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
