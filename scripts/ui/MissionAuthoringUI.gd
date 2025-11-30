extends Control

## UI for creating missions from the current 2D painting canvas
## Keyboard-driven - press F6 to open dialog

@onready var dialog = $Dialog
@onready var id_input = $Dialog/MarginContainer/VBoxContainer/IDInput
@onready var title_input = $Dialog/MarginContainer/VBoxContainer/TitleInput
@onready var desc_input = $Dialog/MarginContainer/VBoxContainer/DescInput
@onready var reward_input = $Dialog/MarginContainer/VBoxContainer/HBoxContainer/RewardInput
@onready var difficulty_input = $Dialog/MarginContainer/VBoxContainer/HBoxContainer/DifficultyInput
@onready var save_button = $Dialog/MarginContainer/VBoxContainer/ButtonContainer/SaveButton
@onready var cancel_button = $Dialog/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

var authoring_tool: MissionAuthoringTool = null
var painting_system_2d: PaintingSystem2D = null

func _ready():
	# Hide dialog initially
	dialog.visible = false

	# Disable mouse filtering to not interfere with camera
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_painting_system(system_2d: PaintingSystem2D):
	"""Set the 2D painting system to capture from"""
	painting_system_2d = system_2d
	authoring_tool = MissionAuthoringTool.new(system_2d)

func _input(event):
	"""Handle keyboard shortcuts"""

	# F6 to open mission authoring dialog
	if event is InputEventKey and event.pressed and event.keycode == KEY_F6 and not dialog.visible:
		_open_dialog()
		get_viewport().set_input_as_handled()
		return

	# When dialog is visible, handle specific inputs
	if dialog.visible:
		# Ctrl+S or Ctrl+Enter to save
		if event is InputEventKey and event.pressed and event.ctrl_pressed:
			if event.keycode == KEY_S or event.keycode == KEY_ENTER:
				_save_mission()
				get_viewport().set_input_as_handled()
				return

		# Escape to close dialog
		if event.is_action_pressed("ui_cancel"):
			_close_dialog()
			get_viewport().set_input_as_handled()
			return

		# Backtick (`) key to navigate to next field (controller-friendly)
		if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
			_focus_next_field()
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

	# Disable painting system input while dialog is open
	painting_system_2d.set_input_enabled(false)

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
	var success = await authoring_tool.create_and_save_mission(
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

	# Re-enable painting system input
	if painting_system_2d:
		painting_system_2d.set_input_enabled(true)

func _focus_next_field():
	"""Move focus to the next input field (backtick key navigation)"""
	var focused = get_viewport().gui_get_focus_owner()

	if focused == id_input:
		title_input.grab_focus()
	elif focused == title_input:
		desc_input.grab_focus()
	elif focused == desc_input:
		reward_input.get_line_edit().grab_focus()
	elif focused == reward_input.get_line_edit():
		difficulty_input.get_line_edit().grab_focus()
	elif focused == difficulty_input.get_line_edit():
		save_button.grab_focus()
	elif focused == save_button:
		cancel_button.grab_focus()
	elif focused == cancel_button:
		id_input.grab_focus()  # Loop back to start
	else:
		id_input.grab_focus()  # Default to first field

func _focus_previous_field():
	"""Move focus to the previous input field (not currently used)"""
	var focused = get_viewport().gui_get_focus_owner()

	if focused == id_input:
		cancel_button.grab_focus()  # Loop to end
	elif focused == cancel_button:
		save_button.grab_focus()
	elif focused == save_button:
		difficulty_input.get_line_edit().grab_focus()
	elif focused == difficulty_input.get_line_edit():
		reward_input.get_line_edit().grab_focus()
	elif focused == reward_input.get_line_edit():
		desc_input.grab_focus()
	elif focused == desc_input:
		title_input.grab_focus()
	elif focused == title_input:
		id_input.grab_focus()
	else:
		id_input.grab_focus()  # Default to first field
