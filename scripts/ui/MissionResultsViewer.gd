extends Control
class_name MissionResultsViewer

## Mission Results Viewer - Display saved paintings and scores
## Shows latest/best attempts alongside target painting
## Allows retrying missions or returning to mission selection

@onready var dialog = $Dialog
@onready var title_label = $Dialog/MarginContainer/VBoxContainer/TitleLabel
@onready var grade_label = $Dialog/MarginContainer/VBoxContainer/ScoreContainer/GradeLabel
@onready var best_score_label = $Dialog/MarginContainer/VBoxContainer/ScoreContainer/BestScoreLabel
@onready var show_latest_button = $Dialog/MarginContainer/VBoxContainer/ToggleContainer/ShowLatestButton
@onready var show_best_button = $Dialog/MarginContainer/VBoxContainer/ToggleContainer/ShowBestButton
@onready var player_image = $Dialog/MarginContainer/VBoxContainer/ImageComparison/PlayerPaintingPanel/VBoxContainer/PlayerImage
@onready var player_score_label = $Dialog/MarginContainer/VBoxContainer/ImageComparison/PlayerPaintingPanel/VBoxContainer/ScoreLabel
@onready var target_image = $Dialog/MarginContainer/VBoxContainer/ImageComparison/TargetPaintingPanel/VBoxContainer/TargetImage
@onready var retry_button = $Dialog/MarginContainer/VBoxContainer/ButtonContainer/RetryButton
@onready var back_button = $Dialog/MarginContainer/VBoxContainer/ButtonContainer/BackButton

var current_mission: PaintingMission = null
var showing_latest: bool = true

# Styling for toggle buttons
var active_button_style: StyleBoxFlat
var inactive_button_style: StyleBoxFlat

func _ready():
	# Hide dialog initially
	dialog.visible = false

	# Connect button signals
	show_latest_button.pressed.connect(_on_show_latest_pressed)
	show_best_button.pressed.connect(_on_show_best_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Load theme
	theme = load("res://themes/ui_theme.tres")

	# Create toggle button styles
	_create_toggle_styles()

	# Set initial toggle state
	_update_toggle_buttons()

func _create_toggle_styles():
	"""Create visual styles for toggle buttons"""
	active_button_style = StyleBoxFlat.new()
	active_button_style.bg_color = Color(0.2, 0.6, 1.0, 0.3)  # Blue tint
	active_button_style.border_color = Color(0.2, 0.6, 1.0)
	active_button_style.set_border_width_all(2)
	active_button_style.set_corner_radius_all(4)

	inactive_button_style = StyleBoxFlat.new()
	inactive_button_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	inactive_button_style.border_color = Color(0.4, 0.4, 0.4)
	inactive_button_style.set_border_width_all(1)
	inactive_button_style.set_corner_radius_all(4)

func show_results_for_mission(mission: PaintingMission):
	"""Display results for the specified mission"""
	if not mission:
		push_error("MissionResultsViewer: No mission provided!")
		return

	current_mission = mission

	# Get completion data
	var completion_data = MissionManager.get_mission_completion(mission.mission_id)
	if not completion_data["completed"]:
		push_error("MissionResultsViewer: Mission not completed, cannot show results!")
		return

	# Update title
	title_label.text = "Mission Results - %s" % mission.title

	# Update grade
	grade_label.text = completion_data["grade"]
	_set_grade_color(completion_data["grade"])

	# Update best score
	best_score_label.text = "Best Score: %.1f%%" % completion_data["best_score"]

	# Load target image
	_load_target_image()

	# Show latest attempt by default
	showing_latest = true
	_update_toggle_buttons()
	_load_player_painting()

	# Show dialog
	dialog.visible = true
	back_button.grab_focus()

func _set_grade_color(grade: String):
	"""Set grade label color based on grade"""
	match grade:
		"S":
			grade_label.modulate = Color(1.0, 0.84, 0.0)  # Gold
		"A":
			grade_label.modulate = Color(0.2, 1.0, 0.2)  # Bright green
		"B":
			grade_label.modulate = Color(0.4, 0.8, 1.0)  # Light blue
		"C":
			grade_label.modulate = Color(1.0, 0.8, 0.4)  # Orange
		"D":
			grade_label.modulate = Color(1.0, 0.5, 0.2)  # Dark orange
		"F":
			grade_label.modulate = Color(1.0, 0.3, 0.3)  # Red
		_:
			grade_label.modulate = Color(1.0, 1.0, 1.0)  # White

func _load_target_image():
	"""Load the target reference image"""
	if not current_mission:
		return

	if current_mission.reference_image_path and current_mission.reference_image_path != "":
		var texture = load(current_mission.reference_image_path) as Texture2D
		if texture:
			target_image.texture = texture
		else:
			target_image.texture = null
			push_error("Failed to load target image: %s" % current_mission.reference_image_path)
	else:
		target_image.texture = null

func _load_player_painting():
	"""Load the player's painting (latest or best based on current view)"""
	if not current_mission:
		return

	var completion_data = MissionManager.get_mission_completion(current_mission.mission_id)
	var painting_path = ""
	var score = 0.0

	if showing_latest:
		painting_path = completion_data.get("latest_painting_path", "")
		score = completion_data.get("latest_score", 0.0)
	else:
		painting_path = completion_data.get("best_painting_path", "")
		score = completion_data.get("best_score", 0.0)

	# Update score label
	player_score_label.text = "Score: %.1f%%" % score

	# Load painting image
	var texture = _load_painting_from_path(painting_path)
	if texture:
		player_image.texture = texture
	else:
		player_image.texture = null
		# Show placeholder or error message
		if painting_path == "":
			player_score_label.text = "No saved painting available"
		else:
			player_score_label.text = "Failed to load painting"

func _load_painting_from_path(path: String) -> ImageTexture:
	"""Load a saved painting image from user:// path"""
	if path == "" or not FileAccess.file_exists(path):
		return null

	var image = Image.load_from_file(path)
	if image:
		return ImageTexture.create_from_image(image)
	else:
		push_error("Failed to load painting from: %s" % path)
		return null

func _update_toggle_buttons():
	"""Update toggle button visual states"""
	if showing_latest:
		show_latest_button.add_theme_stylebox_override("normal", active_button_style)
		show_best_button.add_theme_stylebox_override("normal", inactive_button_style)
	else:
		show_latest_button.add_theme_stylebox_override("normal", inactive_button_style)
		show_best_button.add_theme_stylebox_override("normal", active_button_style)

func _on_show_latest_pressed():
	"""Switch to showing latest attempt"""
	if showing_latest:
		return  # Already showing latest

	showing_latest = true
	_update_toggle_buttons()
	_load_player_painting()

func _on_show_best_pressed():
	"""Switch to showing best attempt"""
	if not showing_latest:
		return  # Already showing best

	showing_latest = false
	_update_toggle_buttons()
	_load_player_painting()

func _on_retry_pressed():
	"""Retry the current mission"""
	if not current_mission:
		return

	# Hide results viewer
	dialog.visible = false

	# Start the mission via MissionManager and PaintingSystem
	if MissionManager:
		MissionManager.start_mission(current_mission)

	# Find painting system and start mission
	var painting_system = _find_painting_system()
	if painting_system:
		painting_system.start_mission(current_mission)
	else:
		push_error("MissionResultsViewer: Could not find PaintingSystem2D!")

	print("MissionResultsViewer: Retrying mission '%s'" % current_mission.title)

func _on_back_pressed():
	"""Return to mission selection"""
	dialog.visible = false

	if UIManager:
		UIManager.change_state(UIManager.GameState.MISSION_SELECT)

func _find_painting_system() -> PaintingSystem2D:
	"""Find the PaintingSystem2D in the scene tree"""
	var root = get_tree().root
	return _search_for_painting_system(root)

func _search_for_painting_system(node: Node) -> PaintingSystem2D:
	"""Recursively search for PaintingSystem2D"""
	if node is PaintingSystem2D:
		return node

	for child in node.get_children():
		var result = _search_for_painting_system(child)
		if result:
			return result

	return null

func _input(event):
	"""Handle input when dialog is visible"""
	if dialog.visible:
		# Escape to close
		if event.is_action_pressed("ui_cancel"):
			_on_back_pressed()
			get_viewport().set_input_as_handled()
