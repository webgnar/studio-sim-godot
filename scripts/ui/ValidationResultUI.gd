extends Control
class_name ValidationResultUI

## UI for displaying painting validation results
## Shows grade, score, and allows retry or return to mission selection

@onready var dialog = $Dialog
@onready var grade_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/GradeLabel
@onready var score_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ScoreLabel
@onready var status_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/StatusLabel
@onready var message_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/MessageLabel
@onready var comparison_container = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ComparisonContainer
@onready var your_image = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ComparisonContainer/YourPaintingPanel/YourImage
@onready var target_image = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ComparisonContainer/TargetPaintingPanel/TargetImage
@onready var heatmap_panel = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HeatmapPanel
@onready var heatmap_image = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HeatmapPanel/HeatmapImage
@onready var histogram_panel = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HistogramPanel
@onready var player_histogram_display = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HistogramPanel/HistogramComparison/PlayerHistPanel/PlayerHistogramDisplay
@onready var player_swatch_display = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HistogramPanel/HistogramComparison/PlayerHistPanel/PlayerSwatchDisplay
@onready var reference_histogram_display = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HistogramPanel/HistogramComparison/ReferenceHistPanel/ReferenceHistogramDisplay
@onready var reference_swatch_display = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HistogramPanel/HistogramComparison/ReferenceHistPanel/ReferenceSwatchDisplay
@onready var breakdown_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/BreakdownLabel
@onready var coordinate_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/CoordinateLabel
@onready var visual_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/VisualLabel
@onready var color_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ColorLabel
@onready var retry_button = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ButtonContainer/RetryButton
@onready var back_button = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ButtonContainer/BackButton

var current_result: ValidationResult = null
var current_mission: PaintingMission = null
var painting_system_2d: PaintingSystem2D = null
var mission_selection_ui: MissionSelectionUI = null

func _ready():
	# Connect button signals
	retry_button.pressed.connect(_on_retry_mission)
	back_button.pressed.connect(_on_back_to_missions)

	# Hide dialog initially
	dialog.visible = false

	# Register with UIManager
	if UIManager:
		UIManager.register_screen("validation", self)

	# Find painting system and mission selection UI
	_find_dependencies()

func _find_dependencies():
	"""Find the PaintingSystem2D and MissionSelectionUI in the scene tree"""
	var root = get_tree().root
	painting_system_2d = _search_for_type(root, PaintingSystem2D)
	mission_selection_ui = _search_for_type(root, MissionSelectionUI)

	if not painting_system_2d:
		push_error("ValidationResultUI: Could not find PaintingSystem2D!")

	if not mission_selection_ui:
		push_error("ValidationResultUI: Could not find MissionSelectionUI!")

func _search_for_type(node: Node, type) -> Node:
	"""Recursively search for a node of specific type"""
	if is_instance_of(node, type):
		return node

	for child in node.get_children():
		var result = _search_for_type(child, type)
		if result:
			return result

	return null

func _input(event):
	if not dialog.visible:
		return

	# R key to retry
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_on_retry_mission()
		get_viewport().set_input_as_handled()
		return

	# Go back to missions
	if event.is_action_pressed("go_back"):
		_on_back_to_missions()
		get_viewport().set_input_as_handled()
		return

func show_screen():
	"""Show the validation result screen (called by UIManager)"""
	dialog.visible = true

	# Disable painting input
	if painting_system_2d:
		painting_system_2d.set_input_enabled(false)

	# Focus retry button
	retry_button.grab_focus()

func hide_screen():
	"""Hide the validation result screen (called by UIManager)"""
	dialog.visible = false

	# Re-enable painting input
	if painting_system_2d:
		painting_system_2d.set_input_enabled(true)

func show_results(result: ValidationResult, mission: PaintingMission):
	"""Display validation results"""
	current_result = result
	current_mission = mission

	# Show grade
	var grade = result.get_grade()
	grade_label.text = grade

	# Color code the grade
	match grade:
		"S":
			grade_label.modulate = Color(1.0, 0.84, 0.0)  # Gold
		"A":
			grade_label.modulate = Color(0.2, 1.0, 0.2)  # Green
		"B":
			grade_label.modulate = Color(0.4, 0.8, 1.0)  # Light blue
		"C":
			grade_label.modulate = Color(1.0, 1.0, 0.4)  # Yellow
		"D":
			grade_label.modulate = Color(1.0, 0.6, 0.2)  # Orange
		"F":
			grade_label.modulate = Color(1.0, 0.3, 0.3)  # Red

	# Show score
	score_label.text = "Score: %.1f%%" % result.match_percentage

	# Show pass/fail status with threshold
	if result.success:
		status_label.text = "PASSED! (%.0f%% required)" % result.pass_threshold
		status_label.modulate = Color(0.4, 1.0, 0.4)
	else:
		status_label.text = "Failed (%.0f%% required)" % result.pass_threshold
		status_label.modulate = Color(1.0, 0.4, 0.4)

	# Show message
	if result.errors.is_empty():
		message_label.text = "Great work! Mission completed."
	else:
		message_label.text = "\n".join(result.errors)

	# Show image comparison
	_display_comparison_images(mission)

	# Show heatmap and histograms if debug data is available
	_display_analysis_visualizations(result)

	# Show score breakdown (simplified validation - Visual + Color only)
	breakdown_label.visible = true
	coordinate_label.visible = false  # No longer used
	visual_label.visible = true
	color_label.visible = true

	# Show Precision and Color Field scores with fixed weights (30% precision, 70% color field)
	visual_label.text = "Precision: %.1f%% (weight: 30%%)" % result.visual_match_percentage
	color_label.text = "Color Field: %.1f%% (weight: 70%%)" % result.color_distribution_score

	# Show results via UIManager (which will call show_screen())
	# Note: Dialog visibility is now managed by UIManager
	dialog.visible = true

	# Focus retry button
	retry_button.grab_focus()

func _display_comparison_images(mission: PaintingMission):
	"""Display side-by-side comparison of player's painting vs target"""
	if not mission or not painting_system_2d:
		comparison_container.visible = false
		return

	var player_texture: ImageTexture = null
	var reference_texture: Texture2D = null

	# Capture player's current painting
	if painting_system_2d.canvas_viewport:
		var viewport_texture = painting_system_2d.canvas_viewport.get_texture()
		if viewport_texture:
			var current_image = viewport_texture.get_image()
			if current_image:
				# Rotate to match reference orientation (references are rotated 90° clockwise)
				current_image.rotate_90(CLOCKWISE)

				# Convert Image to ImageTexture
				player_texture = ImageTexture.create_from_image(current_image)

	# Load reference image
	if mission.reference_image_path and mission.reference_image_path != "":
		reference_texture = load(mission.reference_image_path) as Texture2D

	# Display images if both are available
	if player_texture and reference_texture:
		your_image.texture = player_texture
		target_image.texture = reference_texture
		comparison_container.visible = true
	else:
		comparison_container.visible = false
		if not player_texture:
			push_warning("ValidationResultUI: Could not capture player's painting")
		if not reference_texture:
			push_warning("ValidationResultUI: Could not load reference image from '%s'" % mission.reference_image_path)

func _display_analysis_visualizations(result: ValidationResult):
	"""Display heatmap and histograms from debug data"""
	if not result or not result.debug_enabled or result.debug_data.is_empty():
		# Hide visualizations if no debug data
		heatmap_panel.visible = false
		histogram_panel.visible = false
		return

	var debug = result.debug_data

	# Display heatmap
	if debug.has("heatmap_data"):
		heatmap_image.texture = ImageTexture.create_from_image(debug["heatmap_data"])
		heatmap_panel.visible = true
	else:
		heatmap_panel.visible = false

	# Display histograms
	if debug.has("current_histogram") and debug.has("reference_histogram"):
		var player_hist = debug["current_histogram"]
		var ref_hist = debug["reference_histogram"]

		player_histogram_display.texture = HistogramRenderer.create_histogram_texture(player_hist)
		player_swatch_display.texture = HistogramRenderer.create_top_colors_swatch(player_hist)

		reference_histogram_display.texture = HistogramRenderer.create_histogram_texture(ref_hist)
		reference_swatch_display.texture = HistogramRenderer.create_top_colors_swatch(ref_hist)

		histogram_panel.visible = true
	else:
		histogram_panel.visible = false

func _on_retry_mission():
	"""Retry the current mission"""
	if not current_mission:
		push_error("ValidationResultUI: No mission to retry!")
		return

	if not painting_system_2d:
		push_error("ValidationResultUI: No painting system found!")
		return

	# Restart the mission (clear canvas)
	painting_system_2d.start_mission(current_mission)
	MissionManager.start_mission(current_mission)

	# Note: MissionManager.start_mission() will call UIManager.change_state(IN_MISSION)

func _on_back_to_missions():
	"""Return to mission selection"""
	# Clear current mission
	MissionManager.current_mission = null

	# Return to mission selection via UIManager
	if UIManager:
		UIManager.change_state(UIManager.GameState.MISSION_SELECT)
