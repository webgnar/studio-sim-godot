extends CanvasLayer

## F3-toggleable debug overlay showing validation analysis (heatmap, histograms, scores)

# Node references (will be connected after scene creation)
@onready var panel = $PanelContainer
@onready var heatmap_image = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/HeatmapImageDisplay
@onready var pixel_stats = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/PixelStatsLabel

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

func _ready():
	panel.visible = false
	layer = 100  # Above HUD

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

func update_display(result: ValidationResult):
	"""Populate all UI elements from ValidationResult"""
	if not result or not result.debug_enabled or result.debug_data.is_empty():
		push_warning("ValidationDebugOverlay: No debug data available")
		return

	current_validation_result = result
	var debug = result.debug_data

	# Display Heatmap
	if debug.has("heatmap_data"):
		heatmap_image.texture = ImageTexture.create_from_image(debug["heatmap_data"])

		var total = debug.get("total_pixels", 0)
		var matching = debug.get("matching_pixels", 0)
		var pct = (float(matching) / float(total)) * 100.0 if total > 0 else 0.0
		pixel_stats.text = "Matching: %d / %d pixels (%.1f%%)" % [matching, total, pct]

	# Display Histograms
	if debug.has("current_histogram") and debug.has("reference_histogram"):
		var player_hist = debug["current_histogram"]
		player_histogram_display.texture = HistogramRenderer.create_histogram_texture(player_hist)
		player_swatch.texture = HistogramRenderer.create_color_swatch(player_hist)
		player_hist_text.text = HistogramRenderer.get_histogram_text(player_hist)

		var ref_hist = debug["reference_histogram"]
		reference_histogram_display.texture = HistogramRenderer.create_histogram_texture(ref_hist)
		reference_swatch.texture = HistogramRenderer.create_color_swatch(ref_hist)
		reference_hist_text.text = HistogramRenderer.get_histogram_text(ref_hist)

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
