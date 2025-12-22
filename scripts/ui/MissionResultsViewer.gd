extends Control
class_name MissionResultsViewer

## Mission Results Viewer - Display saved paintings and scores
## Shows latest/best attempts alongside target painting
## Allows retrying missions or returning to mission selection

@onready var dialog = $Dialog
@onready var grade_label = $Dialog/MarginContainer/VBoxContainer/ScoreContainer/GradeLabel
@onready var best_score_label = $Dialog/MarginContainer/VBoxContainer/ScoreContainer/BestScoreLabel
@onready var back_button = $Dialog/MarginContainer/VBoxContainer/ToggleContainer/back
@onready var show_latest_button = $Dialog/MarginContainer/VBoxContainer/ToggleContainer/ShowLatestButton
@onready var show_best_button = $Dialog/MarginContainer/VBoxContainer/ToggleContainer/ShowBestButton
@onready var player_image = $Dialog/MarginContainer/VBoxContainer/ImageComparison/PlayerPaintingPanel/VBoxContainer/PlayerImage
@onready var player_score_label = $Dialog/MarginContainer/VBoxContainer/ImageComparison/PlayerPaintingPanel/VBoxContainer/ScoreLabel
@onready var target_image = $Dialog/MarginContainer/VBoxContainer/ImageComparison/TargetPaintingPanel/VBoxContainer/TargetImage
@onready var button_nav_sound = $ButtonNavSound
@onready var button_hit_sound = $ButtonHitSound

var current_mission: PaintingMission = null
var showing_latest: bool = true

# Styling for toggle buttons
var active_button_style: StyleBoxFlat
var inactive_button_style: StyleBoxFlat

# Navigation
var buttons: Array[Button] = []
var focused_button_index: int = 0
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15  # Cooldown between navigation inputs

func _ready():
	# Hide dialog initially
	dialog.visible = false

	# Connect button signals
	back_button.pressed.connect(_on_back_pressed)
	show_latest_button.pressed.connect(_on_show_latest_pressed)
	show_best_button.pressed.connect(_on_show_best_pressed)

	# Setup navigation array (Back, Show Latest, Show Best)
	buttons = [back_button, show_latest_button, show_best_button]

	# Set up focus navigation
	_setup_focus_navigation()

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

func _setup_focus_navigation():
	"""Set up gamepad/keyboard focus navigation for buttons"""
	# Enable focus mode for all buttons
	back_button.focus_mode = Control.FOCUS_ALL
	show_latest_button.focus_mode = Control.FOCUS_ALL
	show_best_button.focus_mode = Control.FOCUS_ALL

	# Set up focus neighbors (horizontal navigation)
	back_button.focus_neighbor_right = back_button.get_path_to(show_latest_button)
	back_button.focus_next = back_button.get_path_to(show_latest_button)

	show_latest_button.focus_neighbor_left = show_latest_button.get_path_to(back_button)
	show_latest_button.focus_neighbor_right = show_latest_button.get_path_to(show_best_button)
	show_latest_button.focus_previous = show_latest_button.get_path_to(back_button)
	show_latest_button.focus_next = show_latest_button.get_path_to(show_best_button)

	show_best_button.focus_neighbor_left = show_best_button.get_path_to(show_latest_button)
	show_best_button.focus_previous = show_best_button.get_path_to(show_latest_button)

func _process(delta):
	if not dialog.visible:
		return

	# Update input cooldown
	if input_cooldown > 0:
		input_cooldown -= delta

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

	# Reset input cooldown
	input_cooldown = 0.0

	# Focus first button
	focused_button_index = 0
	_update_button_focus()

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
	if not dialog.visible:
		return

	var viewport = get_viewport()
	if not viewport:
		return

	# Go back to close (B button or ESC)
	if event.is_action_pressed("go_back") or event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		viewport.set_input_as_handled()
		return

	# Left/Right or A/D or D-pad to navigate buttons
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		if input_cooldown <= 0:
			_select_previous_button()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		if input_cooldown <= 0:
			_select_next_button()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# Jump (A button / Space) or ui_accept to activate focused button
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if input_cooldown <= 0:
			_activate_focused_button()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

func _select_next_button():
	"""Navigate to the next visible button"""
	var start_index = focused_button_index
	var attempts = 0

	while attempts < buttons.size():
		focused_button_index = (focused_button_index + 1) % buttons.size()

		# Skip invisible or disabled buttons
		if buttons[focused_button_index].visible and not buttons[focused_button_index].disabled:
			_update_button_focus()

			# Play navigation sound
			if button_nav_sound:
				button_nav_sound.play()
			return

		attempts += 1

	# If no valid button found, stay on current
	focused_button_index = start_index

func _select_previous_button():
	"""Navigate to the previous visible button"""
	var start_index = focused_button_index
	var attempts = 0

	while attempts < buttons.size():
		focused_button_index = (focused_button_index - 1) % buttons.size()
		if focused_button_index < 0:
			focused_button_index = buttons.size() - 1

		# Skip invisible or disabled buttons
		if buttons[focused_button_index].visible and not buttons[focused_button_index].disabled:
			_update_button_focus()

			# Play navigation sound
			if button_nav_sound:
				button_nav_sound.play()
			return

		attempts += 1

	# If no valid button found, stay on current
	focused_button_index = start_index

func _update_button_focus():
	"""Update which button has focus highlight"""
	# Find first visible enabled button if current is invalid
	if focused_button_index >= buttons.size() or \
	   not buttons[focused_button_index].visible or \
	   buttons[focused_button_index].disabled:
		for i in range(buttons.size()):
			if buttons[i].visible and not buttons[i].disabled:
				focused_button_index = i
				break

	# Focus the selected button
	if focused_button_index < buttons.size():
		buttons[focused_button_index].grab_focus()

func _activate_focused_button():
	"""Activate the currently focused button"""
	if focused_button_index < buttons.size():
		var button = buttons[focused_button_index]
		if button.visible and not button.disabled:
			# Play button hit sound
			if button_hit_sound:
				button_hit_sound.play()

			button.pressed.emit()
			print("MissionResultsViewer: Activated button: ", button.name)
