extends CanvasLayer

## F3-toggleable debug overlay showing validation analysis (heatmap, histograms, scores)

# Node references (will be connected after scene creation)
@onready var panel = $PanelContainer
@onready var heatmap_image = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/HeatmapImageDisplay
@onready var pixel_stats = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/PixelStatsLabel
@onready var heatmap_multiplier_slider = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/HeatmapMultiplierContainer/HeatmapMultiplierSlider
@onready var heatmap_multiplier_value = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/HeatmapMultiplierContainer/HeatmapMultiplierValue

# Histogram nodes
@onready var player_histogram_display = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/HistogramComparison/PlayerHistPanel/PlayerHistogramDisplay
@onready var player_swatch = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/HistogramComparison/PlayerHistPanel/PlayerSwatchDisplay
@onready var player_hist_text = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/HistogramComparison/PlayerHistPanel/PlayerHistogramText

@onready var reference_histogram_display = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/HistogramComparison/ReferenceHistPanel/ReferenceHistogramDisplay
@onready var reference_swatch = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/HistogramComparison/ReferenceHistPanel/ReferenceSwatchDisplay
@onready var reference_hist_text = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/HistogramComparison/ReferenceHistPanel/ReferenceHistogramText

# Score nodes
@onready var visual_score_label = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/ScoresGrid/VisualScoreLabel
@onready var color_score_label = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/ScoresGrid/ColorScoreLabel
@onready var blended_score_label = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/ScoresGrid/BlendedScoreLabel
@onready var tolerance_label = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/ScoresGrid/ToleranceLabel
@onready var threshold_label = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/ScoresGrid/ThresholdLabel
@onready var final_grade_label = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/FinalGradeLabel

var is_debug_visible: bool = false
var current_validation_result: ValidationResult = null
var heatmap_tolerance_multiplier: float = 5.0  # Adjustable multiplier for heatmap visualization

func _ready():
	panel.visible = false
	layer = 100  # Above HUD

	# Wire up multiplier slider
	heatmap_multiplier_slider.value_changed.connect(_on_multiplier_changed)
	heatmap_multiplier_slider.value = heatmap_tolerance_multiplier

func _input(event):
	# F3 toggles debug overlay
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		toggle_debug_overlay()
		get_viewport().set_input_as_handled()

func toggle_debug_overlay():
	"""Toggle visibility"""
	is_debug_visible = !is_debug_visible
	panel.visible = is_debug_visible

	# Refresh display if we have cached data
	if is_debug_visible and current_validation_result:
		update_display(current_validation_result)

func is_overlay_visible() -> bool:
	return is_debug_visible

func _generate_heatmap_with_tolerance(current: Image, reference: Image, tolerance: float) -> Image:
	"""Generate heatmap showing pixel matching quality with custom tolerance"""
	var width = reference.get_size().x
	var height = reference.get_size().y

	# Optional downsampling for performance
	var max_dim = 512
	if width > max_dim or height > max_dim:
		var scale = float(max_dim) / max(width, height)
		current = current.duplicate()
		reference = reference.duplicate()
		current.resize(int(width * scale), int(height * scale), Image.INTERPOLATE_LANCZOS)
		reference.resize(int(width * scale), int(height * scale), Image.INTERPOLATE_LANCZOS)
		width = current.get_size().x
		height = current.get_size().y

	var heatmap = Image.create(width, height, false, Image.FORMAT_RGBA8)

	for y in range(height):
		for x in range(width):
			var current_color = current.get_pixel(x, y)
			var reference_color = reference.get_pixel(x, y)

			# Skip fully transparent pixels in reference (background)
			if reference_color.a < 0.1:
				heatmap.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			# Calculate color distance using public method
			var color_diff = VisualValidator.color_distance(current_color, reference_color)

			if color_diff <= tolerance:
				# Green for matching (brighter = closer match)
				var quality = 1.0 - (color_diff / tolerance)
				heatmap.set_pixel(x, y, Color(0, quality, 0, 0.7))
			else:
				# Red for mismatch (brighter = worse)
				var severity = min((color_diff - tolerance) / tolerance, 1.0)
				heatmap.set_pixel(x, y, Color(1.0, 0, 0, 0.5 + severity * 0.3))

	return heatmap

func _refresh_heatmap():
	"""Regenerate heatmap with new multiplier"""
	if not current_validation_result or not current_validation_result.debug_enabled:
		return

	var debug = current_validation_result.debug_data
	if not debug.has("current_image") or not debug.has("reference_image"):
		return

	# Regenerate heatmap with adjusted tolerance
	var base_tolerance = debug.get("color_tolerance", 20.0)
	var adjusted_tolerance = base_tolerance * heatmap_tolerance_multiplier

	var new_heatmap = _generate_heatmap_with_tolerance(
		debug["current_image"],
		debug["reference_image"],
		adjusted_tolerance
	)
	heatmap_image.texture = ImageTexture.create_from_image(new_heatmap)

	# Update pixel stats to show adjusted tolerance
	var total = debug.get("total_pixels", 0)
	var matching = debug.get("matching_pixels", 0)
	var pct = (float(matching) / float(total)) * 100.0 if total > 0 else 0.0
	pixel_stats.text = "Matching: %d / %d (%.1f%%) | Tolerance: %.1f (base: %.1f × %.1fx)" % [
		matching, total, pct, adjusted_tolerance, base_tolerance, heatmap_tolerance_multiplier
	]

func _on_multiplier_changed(new_value: float):
	"""Called when slider value changes"""
	heatmap_tolerance_multiplier = new_value
	heatmap_multiplier_value.text = "%.1fx" % new_value

	# Auto-refresh heatmap if we have cached data
	if current_validation_result:
		_refresh_heatmap()

func update_display(result: ValidationResult):
	"""Populate all UI elements from ValidationResult"""
	if not result or not result.debug_enabled or result.debug_data.is_empty():
		push_warning("ValidationDebugOverlay: No debug data available")
		return

	current_validation_result = result
	var debug = result.debug_data

	# Display Heatmap with adjusted tolerance
	if debug.has("current_image") and debug.has("reference_image"):
		var base_tolerance = debug.get("color_tolerance", 20.0)
		var adjusted_tolerance = base_tolerance * heatmap_tolerance_multiplier

		var heatmap = _generate_heatmap_with_tolerance(
			debug["current_image"],
			debug["reference_image"],
			adjusted_tolerance
		)
		heatmap_image.texture = ImageTexture.create_from_image(heatmap)

		var total = debug.get("total_pixels", 0)
		var matching = debug.get("matching_pixels", 0)
		var pct = (float(matching) / float(total)) * 100.0 if total > 0 else 0.0
		pixel_stats.text = "Matching: %d / %d (%.1f%%) | Tolerance: %.1f (base: %.1f × %.1fx)" % [
			matching, total, pct, adjusted_tolerance, base_tolerance, heatmap_tolerance_multiplier
		]
	elif debug.has("heatmap_data"):
		# Fallback to pre-generated heatmap if images not available
		heatmap_image.texture = ImageTexture.create_from_image(debug["heatmap_data"])

		var total = debug.get("total_pixels", 0)
		var matching = debug.get("matching_pixels", 0)
		var pct = (float(matching) / float(total)) * 100.0 if total > 0 else 0.0
		pixel_stats.text = "Matching: %d / %d pixels (%.1f%%)" % [matching, total, pct]

	# Display Histograms with Top 5 Diverse Colors
	if debug.has("current_histogram") and debug.has("reference_histogram"):
		var player_hist = debug["current_histogram"]
		player_histogram_display.texture = HistogramRenderer.create_histogram_texture(player_hist)
		player_swatch.texture = HistogramRenderer.create_top_colors_swatch(player_hist, Vector2i(250, 50))
		player_hist_text.text = HistogramRenderer.get_top_colors_text(player_hist)

		var ref_hist = debug["reference_histogram"]
		reference_histogram_display.texture = HistogramRenderer.create_histogram_texture(ref_hist)
		reference_swatch.texture = HistogramRenderer.create_top_colors_swatch(ref_hist, Vector2i(250, 50))
		reference_hist_text.text = HistogramRenderer.get_top_colors_text(ref_hist)

	# Display Scores
	visual_score_label.text = "%.1f%%" % debug.get("visual_score", 0.0)
	color_score_label.text = "%.1f%%" % debug.get("color_score", 0.0)
	blended_score_label.text = "%.1f%%" % debug.get("blended_score", 0.0)
	tolerance_label.text = "%.1f" % debug.get("color_tolerance", 0.0)
	threshold_label.text = "%.1f%%" % debug.get("pass_threshold", 0.0)

	# Display Final Grade
	var grade = debug.get("grade", "F")
	var passed = result.success
	final_grade_label.text = "%s - %s" % [grade, "PASSED" if passed else "FAILED"]

	# Color code grade
	match grade:
		"S": final_grade_label.modulate = Color(1.0, 0.84, 0.0)
		"A": final_grade_label.modulate = Color(0.2, 1.0, 0.2)
		"B": final_grade_label.modulate = Color(0.4, 0.8, 1.0)
		"C": final_grade_label.modulate = Color(1.0, 1.0, 0.4)
		"D": final_grade_label.modulate = Color(1.0, 0.6, 0.2)
		"F": final_grade_label.modulate = Color(1.0, 0.3, 0.3)
