extends Control
class_name ValidationResultUI

## UI for displaying painting validation results
## Shows grade, score, and allows retry or return to mission selection

@onready var dialog = $Dialog
@onready var grade_label = $Dialog/MarginContainer/VBoxContainer/GradeLabel
@onready var score_label = $Dialog/MarginContainer/VBoxContainer/ScoreLabel
@onready var status_label = $Dialog/MarginContainer/VBoxContainer/StatusLabel
@onready var message_label = $Dialog/MarginContainer/VBoxContainer/MessageLabel
@onready var retry_button = $Dialog/MarginContainer/VBoxContainer/ButtonContainer/RetryButton
@onready var back_button = $Dialog/MarginContainer/VBoxContainer/ButtonContainer/BackButton

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

	# Escape to go back to missions
	if event.is_action_pressed("ui_cancel"):
		_on_back_to_missions()
		get_viewport().set_input_as_handled()
		return

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

	# Show pass/fail status
	if result.success:
		status_label.text = "PASSED!"
		status_label.modulate = Color(0.4, 1.0, 0.4)
	else:
		status_label.text = "Failed"
		status_label.modulate = Color(1.0, 0.4, 0.4)

	# Show message
	if result.errors.is_empty():
		message_label.text = "Great work! Mission completed."
	else:
		message_label.text = "\n".join(result.errors)

	# Show dialog
	dialog.visible = true

	# Disable painting input
	if painting_system_2d:
		painting_system_2d.set_input_enabled(false)

	# Disable player input
	if CameraManager:
		CameraManager.set_player_input(false)

	# Focus retry button
	retry_button.grab_focus()

func _close_dialog():
	"""Hide the results dialog"""
	dialog.visible = false

	# Re-enable painting input
	if painting_system_2d:
		painting_system_2d.set_input_enabled(true)

	# Re-enable player input
	if CameraManager:
		CameraManager.set_player_input(true)

func _on_retry_mission():
	"""Retry the current mission"""
	_close_dialog()

	if not current_mission:
		push_error("ValidationResultUI: No mission to retry!")
		return

	if not painting_system_2d:
		push_error("ValidationResultUI: No painting system found!")
		return

	# Restart the mission (clear canvas)
	painting_system_2d.start_mission(current_mission)
	MissionManager.start_mission(current_mission)

	print("ValidationResultUI: Retrying mission '%s'" % current_mission.title)

func _on_back_to_missions():
	"""Return to mission selection"""
	_close_dialog()

	# Clear current mission
	MissionManager.current_mission = null

	# Open mission selection UI
	if mission_selection_ui:
		# The mission selection UI will handle opening itself
		# We just need to make sure we're in 2D mode
		if PaintingModeManager and PaintingModeManager.current_mode == PaintingModeManager.Mode.MODE_2D:
			# Trigger F7 key press to open mission selection
			var event = InputEventKey.new()
			event.keycode = KEY_F7
			event.pressed = true
			Input.parse_input_event(event)
