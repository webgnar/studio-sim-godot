extends Control
class_name ValidationResultUI

## UI for displaying painting validation results after mission submission
## Shows grade, score, and allows retry or return to mission selection

@export var runtime_margin_h: float = 40.0
@export var runtime_margin_v: float = 20.0

@export_group("Grade Colors")
@export var grade_s_color: Color = Color(1.0, 0.84, 0.0)
@export var grade_a_color: Color = Color(0.2, 1.0, 0.2)
@export var grade_b_color: Color = Color(0.4, 0.8, 1.0)
@export var grade_c_color: Color = Color(1.0, 1.0, 0.4)
@export var grade_d_color: Color = Color(1.0, 0.6, 0.2)
@export var grade_f_color: Color = Color(1.0, 0.3, 0.3)

@export_group("Status Colors")
@export var pass_color: Color = Color(0.4, 1.0, 0.4)
@export var fail_color: Color = Color(1.0, 0.4, 0.4)

@export_group("Analysis")
@export var swatch_size: Vector2i = Vector2i(300, 80)

@onready var dialog = $Dialog
@onready var grade_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer/GradeLabel
@onready var score_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer/ScoreLabel
@onready var status_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/StatusLabel
@onready var message_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/MessageLabel
@onready var comparison_container = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ComparisonContainer
@onready var your_image = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ComparisonContainer/YourPaintingPanel/YourImage
@onready var target_image = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ComparisonContainer/TargetPaintingPanel/TargetImage
@onready var heatmap_panel = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HeatmapPanel
@onready var heatmap_image = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HeatmapPanel/HeatmapImage
@onready var histogram_panel = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/HistogramPanel
@onready var player_swatch_display = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ComparisonContainer/PlayerSwatchDisplay
@onready var reference_swatch_display = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ComparisonContainer/ReferenceSwatchDisplay
@onready var breakdown_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/BreakdownLabel
@onready var coordinate_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/CoordinateLabel
@onready var visual_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/VisualLabel
@onready var color_label = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ColorLabel
@onready var retry_button = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ButtonContainer/RetryButton
@onready var back_button = $Dialog/MarginContainer/ScrollContainer/VBoxContainer/ButtonContainer/BackButton

var current_result: ValidationResult = null
var current_mission: PaintingMission = null
var painting_system_2d: PaintingSystem2D = null

func _ready():
	retry_button.pressed.connect(_on_retry_mission)
	back_button.pressed.connect(_on_back_to_missions)

	# At runtime, anchor the Dialog to fill the screen with margins
	# (In the editor it uses a large fixed size so all content is visible)
	dialog.anchor_left = 0.0
	dialog.anchor_top = 0.0
	dialog.anchor_right = 1.0
	dialog.anchor_bottom = 1.0
	dialog.offset_left = runtime_margin_h
	dialog.offset_top = runtime_margin_v
	dialog.offset_right = -runtime_margin_h
	dialog.offset_bottom = -runtime_margin_v

	dialog.visible = false

	if UIManager:
		UIManager.register_screen("validation", self)

	_find_dependencies()

func _find_dependencies():
	var root = get_tree().root
	painting_system_2d = _search_for_type(root, PaintingSystem2D)

	if not painting_system_2d:
		push_error("ValidationResultUI: Could not find PaintingSystem2D!")

func _search_for_type(node: Node, type) -> Node:
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

	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_on_retry_mission()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("go_back"):
		_on_back_to_missions()
		get_viewport().set_input_as_handled()
		return

func show_screen():
	dialog.visible = true

	if painting_system_2d:
		painting_system_2d.set_input_enabled(false)

	retry_button.grab_focus()

func hide_screen():
	dialog.visible = false

	if painting_system_2d:
		painting_system_2d.set_input_enabled(true)

func show_results(result: ValidationResult, mission: PaintingMission):
	current_result = result
	current_mission = mission

	var grade = result.get_grade()
	grade_label.text = grade

	grade_label.modulate = _get_grade_color(grade)

	score_label.text = tr("Score: %.1f%%") % result.match_percentage

	if result.success:
		status_label.text = tr("PASSED! (%.0f%% required)") % result.pass_threshold
		status_label.modulate = pass_color
	else:
		status_label.text = tr("Failed (%.0f%% required)") % result.pass_threshold
		status_label.modulate = fail_color

	if not result.errors.is_empty():
		message_label.text = "\n".join(result.errors)

	_display_comparison_images(mission)
	_display_analysis_visualizations(result)

	breakdown_label.visible = true
	coordinate_label.visible = false
	visual_label.visible = true
	color_label.visible = true
	visual_label.text = tr("Precision: %.1f%% (weight: 30%%)") % result.visual_match_percentage
	color_label.text = tr("Color Field: %.1f%% (weight: 70%%)") % result.color_distribution_score

	dialog.visible = true
	retry_button.grab_focus()

func _display_comparison_images(mission: PaintingMission):
	if not mission or not painting_system_2d:
		comparison_container.visible = false
		return

	var player_texture: ImageTexture = null
	var reference_texture: Texture2D = null

	if painting_system_2d.canvas_viewport:
		var viewport_texture = painting_system_2d.canvas_viewport.get_texture()
		if viewport_texture:
			var current_image = viewport_texture.get_image()
			if current_image:
				current_image.rotate_90(CLOCKWISE)
				player_texture = ImageTexture.create_from_image(current_image)

	if mission.reference_image_path and mission.reference_image_path != "":
		reference_texture = load(mission.reference_image_path) as Texture2D

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
	if not result or not result.debug_enabled or result.debug_data.is_empty():
		heatmap_panel.visible = false
		histogram_panel.visible = false
		return

	var debug = result.debug_data

	if debug.has("heatmap_data"):
		heatmap_image.texture = ImageTexture.create_from_image(debug["heatmap_data"])
		heatmap_panel.visible = true
	else:
		heatmap_panel.visible = false

	if debug.has("current_histogram") and debug.has("reference_histogram"):
		var player_hist = debug["current_histogram"]
		var ref_hist = debug["reference_histogram"]
		player_swatch_display.texture = HistogramRenderer.create_top_colors_swatch(player_hist, swatch_size)
		reference_swatch_display.texture = HistogramRenderer.create_top_colors_swatch(ref_hist, swatch_size)
		histogram_panel.visible = true
	else:
		histogram_panel.visible = false

func _get_grade_color(grade: String) -> Color:
	match grade:
		"S": return grade_s_color
		"A": return grade_a_color
		"B": return grade_b_color
		"C": return grade_c_color
		"D": return grade_d_color
		"F": return grade_f_color
		_: return Color.WHITE

func _on_retry_mission():
	if not current_mission:
		push_error("ValidationResultUI: No mission to retry!")
		return

	if not painting_system_2d:
		push_error("ValidationResultUI: No painting system found!")
		return

	painting_system_2d.start_mission(current_mission)
	MissionManager.start_mission(current_mission)

func _on_back_to_missions():
	MissionManager.current_mission = null

	if UIManager:
		UIManager.change_state(UIManager.GameState.PAUSE_MENU)
