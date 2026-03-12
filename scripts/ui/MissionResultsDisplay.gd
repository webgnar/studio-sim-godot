extends Control
class_name MissionResultsDisplay

## Unified mission results display component
## Works in two modes: LIVE_VALIDATION (post-submission) and SAVED_RESULTS (browsing history)

@export var swatch_size: Vector2i = Vector2i(60, 300)

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var grade_label: Label = $ScrollContainer/VBoxContainer/ScoreHeader/GradeLabel
@onready var score_label: Label = $ScrollContainer/VBoxContainer/ScoreHeader/ScoreLabel
@onready var status_label: Label = $ScrollContainer/VBoxContainer/StatusLabel
@onready var message_label: Label = $ScrollContainer/VBoxContainer/MessageLabel
@onready var comparison_container: HBoxContainer = $ScrollContainer/VBoxContainer/ComparisonContainer
@onready var player_swatch_display: TextureRect = $ScrollContainer/VBoxContainer/ComparisonContainer/PlayerSwatchDisplay
@onready var player_image: TextureRect = $ScrollContainer/VBoxContainer/ComparisonContainer/PlayerPaintingPanel/PlayerImage
@onready var target_image: TextureRect = $ScrollContainer/VBoxContainer/ComparisonContainer/TargetPaintingPanel/TargetImage
@onready var reference_swatch_display: TextureRect = $ScrollContainer/VBoxContainer/ComparisonContainer/ReferenceSwatchDisplay
@onready var heatmap_panel: VBoxContainer = $ScrollContainer/VBoxContainer/HeatmapPanel
@onready var heatmap_image: TextureRect = $ScrollContainer/VBoxContainer/HeatmapPanel/HeatmapImage
@onready var visual_label: Label = $ScrollContainer/VBoxContainer/VisualLabel
@onready var color_label: Label = $ScrollContainer/VBoxContainer/ColorLabel
@onready var retry_button: Button = $ScrollContainer/VBoxContainer/ButtonContainer/RetryButton

var current_mission: PaintingMission = null
var _retry_button_selected: bool = false

signal retry_pressed(mission: PaintingMission)

func _ready():
	retry_button.pressed.connect(func(): retry_pressed.emit(current_mission))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var viewport = get_viewport()

	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		if _retry_button_selected:
			_retry_button_selected = false
			_update_retry_highlight()
		else:
			scroll_container.scroll_vertical -= 100
		viewport.set_input_as_handled()

	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		var scroll_bar = scroll_container.get_v_scroll_bar()
		var at_bottom = scroll_container.scroll_vertical >= scroll_bar.max_value - scroll_container.size.y
		if not _retry_button_selected and at_bottom:
			_retry_button_selected = true
			_update_retry_highlight()
		elif not _retry_button_selected:
			scroll_container.scroll_vertical += 100
		viewport.set_input_as_handled()

	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if _retry_button_selected and retry_button.visible:
			retry_pressed.emit(current_mission)
			viewport.set_input_as_handled()
	# go_back: intentionally NOT consumed — MissionSelectionUI handles it

func _update_retry_highlight():
	retry_button.modulate = Color(1.2, 1.2, 1.0) if _retry_button_selected else Color(1, 1, 1)

func show_live_results(result: ValidationResult, mission: PaintingMission, painting_system: PaintingSystem2D):
	current_mission = mission
	_retry_button_selected = false
	_update_retry_highlight()
	scroll_container.scroll_vertical = 0

	# Grade and score
	var grade = result.get_grade()
	grade_label.text = grade
	score_label.text = tr("Score: %.1f%%") % result.match_percentage

	# Pass/fail status
	if result.success:
		status_label.text = tr("PASSED! (%.0f%% required)") % result.pass_threshold
	else:
		status_label.text = tr("Failed (%.0f%% required)") % result.pass_threshold
	status_label.visible = true

	# Error messages
	if not result.errors.is_empty():
		message_label.text = "\n".join(result.errors)
		message_label.visible = true
	else:
		message_label.visible = false

	# Comparison images
	_display_live_comparison(mission, painting_system)
	_display_analysis(result)

	# Score breakdown
	visual_label.visible = true
	color_label.visible = true
	visual_label.text = tr("Precision: %.1f%% (weight: 30%%)") % result.visual_match_percentage
	color_label.text = tr("Color Field: %.1f%% (weight: 70%%)") % result.color_distribution_score

	visible = true

func show_saved_results(mission: PaintingMission, completion_data: Dictionary):
	current_mission = mission
	_retry_button_selected = false
	_update_retry_highlight()
	scroll_container.scroll_vertical = 0

	message_label.visible = false

	# Display scores and analysis images (always latest)
	_update_saved_display(completion_data)

	# Load target image
	if mission.reference_image_path and mission.reference_image_path != "":
		var texture = load(mission.reference_image_path) as Texture2D
		target_image.texture = texture
	else:
		target_image.texture = null

	# Load player painting
	_load_saved_painting(completion_data)

	comparison_container.visible = true
	visible = true

func _update_saved_display(completion_data: Dictionary):
	grade_label.text = completion_data.get("latest_grade", completion_data["grade"])
	score_label.text = tr("Score: %.1f%%") % completion_data.get("latest_score", completion_data["best_score"])
	status_label.text = tr("Latest Attempt")
	status_label.visible = true
	visual_label.text = tr("Precision: %.1f%% (weight: 30%%)") % completion_data.get("latest_visual_match", 0.0)
	color_label.text = tr("Color Field: %.1f%% (weight: 70%%)") % completion_data.get("latest_color_distribution", 0.0)
	visual_label.visible = true
	color_label.visible = true

	# Load saved heatmap (always latest)
	var heatmap_path = completion_data.get("latest_heatmap_path", "")
	if heatmap_path != "" and FileAccess.file_exists(heatmap_path):
		var img = Image.load_from_file(heatmap_path)
		if img:
			heatmap_image.texture = ImageTexture.create_from_image(img)
			heatmap_panel.visible = true
		else:
			heatmap_panel.visible = false
	else:
		heatmap_panel.visible = false

	# Load saved player swatch (always latest)
	var player_swatch_path = completion_data.get("latest_player_swatch_path", "")
	if player_swatch_path != "" and FileAccess.file_exists(player_swatch_path):
		var img = Image.load_from_file(player_swatch_path)
		if img:
			player_swatch_display.texture = ImageTexture.create_from_image(img)
			player_swatch_display.visible = true
		else:
			player_swatch_display.visible = false
	else:
		player_swatch_display.visible = false

	# Load saved reference swatch (same for all attempts)
	var ref_swatch_path = completion_data.get("ref_swatch_path", "")
	if ref_swatch_path != "" and FileAccess.file_exists(ref_swatch_path):
		var img = Image.load_from_file(ref_swatch_path)
		if img:
			reference_swatch_display.texture = ImageTexture.create_from_image(img)
			reference_swatch_display.visible = true
		else:
			reference_swatch_display.visible = false
	else:
		reference_swatch_display.visible = false

func _display_live_comparison(mission: PaintingMission, painting_system: PaintingSystem2D):
	if not mission or not painting_system:
		comparison_container.visible = false
		return

	var player_texture: ImageTexture = null
	var reference_texture: Texture2D = null

	if painting_system.canvas_viewport:
		var viewport_texture = painting_system.canvas_viewport.get_texture()
		if viewport_texture:
			var current_image = viewport_texture.get_image()
			if current_image:
				if current_image.get_width() <= current_image.get_height():
					current_image.rotate_90(CLOCKWISE)
				player_texture = ImageTexture.create_from_image(current_image)

	if mission.reference_image_path and mission.reference_image_path != "":
		reference_texture = load(mission.reference_image_path) as Texture2D

	if player_texture and reference_texture:
		player_image.texture = player_texture
		target_image.texture = reference_texture
		comparison_container.visible = true
	else:
		comparison_container.visible = false
		if not player_texture:
			push_warning("MissionResultsDisplay: Could not capture player's painting")
		if not reference_texture:
			push_warning("MissionResultsDisplay: Could not load reference image from '%s'" % mission.reference_image_path)

func _display_analysis(result: ValidationResult):
	if not result or result.debug_data.is_empty():
		heatmap_panel.visible = false
		player_swatch_display.visible = false
		reference_swatch_display.visible = false
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
		player_swatch_display.visible = true
		reference_swatch_display.visible = true
	else:
		player_swatch_display.visible = false
		reference_swatch_display.visible = false

func _load_saved_painting(completion_data: Dictionary):
	var painting_path = completion_data.get("latest_painting_path", "")
	if painting_path != "" and FileAccess.file_exists(painting_path):
		var image = Image.load_from_file(painting_path)
		if image:
			player_image.texture = ImageTexture.create_from_image(image)
			return
	player_image.texture = null
