extends Control

## UI for creating missions from the current 2D painting canvas
## Keyboard-driven - press F6 to open dialog
## Only functional in 2D mode

@onready var dialog = $Dialog
@onready var id_input = $Dialog/MarginContainer/VBoxContainer/IDInput
@onready var title_input = $Dialog/MarginContainer/VBoxContainer/TitleInput
@onready var desc_input = $Dialog/MarginContainer/VBoxContainer/DescInput
@onready var reward_input = $Dialog/MarginContainer/VBoxContainer/HBoxContainer/RewardInput
@onready var difficulty_input = $Dialog/MarginContainer/VBoxContainer/HBoxContainer/DifficultyInput

var authoring_tool: MissionAuthoringTool = null
var painting_system_2d: PaintingSystem2D = null
var is_2d_mode: bool = false

func _ready():
	# Connect to mode manager
	if PaintingModeManager:
		PaintingModeManager.mode_changed.connect(_on_mode_changed)
		is_2d_mode = (PaintingModeManager.current_mode == PaintingModeManager.Mode.MODE_2D)

	# Hide dialog initially
	dialog.visible = false

	# Disable mouse filtering to not interfere with camera
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_painting_system(system_2d: PaintingSystem2D):
	"""Set the 2D painting system to capture from"""
	painting_system_2d = system_2d
	authoring_tool = MissionAuthoringTool.new(system_2d)

func _on_mode_changed(new_mode):
	"""Track current mode"""
	is_2d_mode = (new_mode == PaintingModeManager.Mode.MODE_2D)

	# Close dialog if switching away from 2D mode
	if not is_2d_mode and dialog.visible:
		_close_dialog()

func _input(event):
	"""Handle keyboard shortcuts"""
	# Only process input in 2D mode
	if not is_2d_mode:
		return

	# F6 to open mission authoring dialog
	if event is InputEventKey and event.pressed and event.keycode == KEY_F6 and not dialog.visible:
		_open_dialog()
		get_viewport().set_input_as_handled()
		return

	# Escape to close dialog
	if dialog.visible and event.is_action_pressed("ui_cancel"):
		_close_dialog()
		get_viewport().set_input_as_handled()
		return

	# Enter to save (when dialog is open)
	if dialog.visible and event.is_action_pressed("ui_accept"):
		_save_mission()
		get_viewport().set_input_as_handled()
		return

func _open_dialog():
	"""Show the mission creation dialog"""
	if not painting_system_2d:
		push_error("MissionAuthoringUI: No painting system assigned!")
		return

	if painting_system_2d.placed_layers.is_empty():
		push_error("MissionAuthoringUI: Canvas is empty, cannot create mission")
		return

	# Show dialog
	dialog.visible = true

	# Auto-generate mission ID
	var timestamp = Time.get_unix_time_from_system()
	id_input.text = "mission_%d" % int(timestamp)

	# Focus first input
	id_input.grab_focus()

func _save_mission():
	"""Save the mission"""
	if not authoring_tool:
		push_error("MissionAuthoringUI: Authoring tool not initialized!")
		return

	var mission_id = id_input.text
	var title = title_input.text
	var description = desc_input.text
	var reward = int(reward_input.value)
	var difficulty = int(difficulty_input.value)

	# Validate inputs
	if mission_id.is_empty():
		push_error("MissionAuthoringUI: Mission ID is required!")
		return

	if title.is_empty():
		push_error("MissionAuthoringUI: Title is required!")
		return

	# Create file path
	var file_path = "res://resources/missions/%s.tres" % mission_id

	# Save mission
	var success = authoring_tool.create_and_save_mission(
		mission_id,
		title,
		description,
		reward,
		difficulty,
		file_path
	)

	if success:
		print("Mission saved successfully: %s" % file_path)
		_close_dialog()
	else:
		push_error("Failed to save mission!")

func _close_dialog():
	"""Hide the dialog and clear inputs"""
	dialog.visible = false
	id_input.text = ""
	title_input.text = ""
	desc_input.text = ""
	reward_input.value = 100
	difficulty_input.value = 1
