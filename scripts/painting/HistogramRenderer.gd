extends RefCounted
class_name HistogramRenderer

## Renders RGB histograms as bar charts with color swatches

static func create_histogram_texture(histogram: Dictionary, size: Vector2i = Vector2i(256, 100)) -> ImageTexture:
	"""Create RGB bar chart from histogram data"""
	if histogram.is_empty():
		return null

	var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.1, 0.1, 1.0))  # Dark background

	var r = histogram.get("red", 0.0)
	var g = histogram.get("green", 0.0)
	var b = histogram.get("blue", 0.0)

	var bar_width = size.x / 3
	var max_height = size.y - 20

	# Draw three bars
	_draw_bar(image, 0, int(bar_width), max_height, r, Color.RED)
	_draw_bar(image, int(bar_width), int(bar_width * 2), max_height, g, Color.GREEN)
	_draw_bar(image, int(bar_width * 2), size.x, max_height, b, Color.BLUE)

	return ImageTexture.create_from_image(image)

static func _draw_bar(image: Image, x_start: int, x_end: int, max_height: int, value: float, color: Color):
	"""Draw single colored bar"""
	var bar_height = int(value * max_height)
	var y_start = image.get_height() - bar_height

	for y in range(y_start, image.get_height()):
		for x in range(x_start, x_end):
			image.set_pixel(x, y, color)

static func create_color_swatch(histogram: Dictionary, size: Vector2i = Vector2i(50, 50)) -> ImageTexture:
	"""Create solid color swatch showing average color"""
	if histogram.is_empty():
		return null

	var avg_color = Color(
		histogram.get("red", 0.0),
		histogram.get("green", 0.0),
		histogram.get("blue", 0.0),
		1.0
	)

	var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(avg_color)
	return ImageTexture.create_from_image(image)

static func get_histogram_text(histogram: Dictionary) -> String:
	"""Format histogram as readable text"""
	if histogram.is_empty():
		return "No data"

	return "R: %.3f | G: %.3f | B: %.3f | Pixels: %d" % [
		histogram.get("red", 0.0),
		histogram.get("green", 0.0),
		histogram.get("blue", 0.0),
		histogram.get("pixel_count", 0)
	]

static func create_top_colors_swatch(histogram: Dictionary, size: Vector2i = Vector2i(150, 50)) -> ImageTexture:
	"""Create 3-panel color swatch showing top 3 colors"""
	if histogram.is_empty() or not histogram.has("top_colors"):
		return create_color_swatch(histogram, size)  # Fallback to average

	var top_colors = histogram["top_colors"]
	if top_colors.is_empty():
		return create_color_swatch(histogram, size)

	var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

	# Divide into 3 vertical sections
	var section_width = size.x / 3

	for i in range(min(3, top_colors.size())):
		var x_start = int(i * section_width)
		var x_end = int((i + 1) * section_width) if i < 2 else size.x
		var color = top_colors[i]["color"]

		# Fill section
		for y in range(size.y):
			for x in range(x_start, x_end):
				image.set_pixel(x, y, color)

	# If fewer than 3 colors, fill remaining with black
	if top_colors.size() < 3:
		for i in range(top_colors.size(), 3):
			var x_start = int(i * section_width)
			var x_end = int((i + 1) * section_width) if i < 2 else size.x
			for y in range(size.y):
				for x in range(x_start, x_end):
					image.set_pixel(x, y, Color.BLACK)

	return ImageTexture.create_from_image(image)

static func get_top_colors_text(histogram: Dictionary) -> String:
	"""Format top 3 colors as readable text"""
	if histogram.is_empty() or not histogram.has("top_colors"):
		return get_histogram_text(histogram)  # Fallback

	var top_colors = histogram["top_colors"]
	if top_colors.is_empty():
		return "No color data"

	var lines = []
	for i in range(top_colors.size()):
		var entry = top_colors[i]
		var c = entry["color"]
		lines.append("#%d: RGB(%.0f,%.0f,%.0f) - %.1f%%" % [
			i + 1,
			c.r * 255, c.g * 255, c.b * 255,
			entry["percentage"]
		])

	return "\n".join(lines)
