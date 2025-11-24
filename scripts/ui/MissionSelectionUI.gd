extends Control
class_name MissionSelectionUI

## UI for browsing and selecting painting missions
## Opens with F7 key in 3D mode, displays mission list and details

# Preload the mission card scene
const MissionCardScene = preload("res://scenes/UI/MissionCard.tscn")

@onready var dialog = $Dialog
@onready var mission_list_container = $Dialog/MarginContainer/HBoxContainer/LeftPanel/ScrollContainer/MissionList
@onready var preview_image = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/PreviewImage
@onready var mission_title = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/MissionTitle
@onready var mission_description = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var difficulty_label = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/DifficultyLabel
@onready var completion_label = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/CompletionLabel
@onready var start_button = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ButtonContainer/StartButton
@onready var back_button = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ButtonContainer/BackButton

var painting_system_2d: PaintingSystem2D = null
var selected_mission: PaintingMission = null
var selected_index: int = 0
var mission_cards: Array[MissionCard] = []

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_mission)
	back_button.pressed.connect(_close_dialog)

	# Hide dialog initially
	dialog.visible = false

	# Find painting system
	_find_painting_system()

func _find_painting_system():
	"""Find the PaintingSystem2D in the scene tree"""
	var root = get_tree().root
	painting_system_2d = _search_for_painting_system(root)

	if not painting_system_2d:
		push_error("MissionSelectionUI: Could not find PaintingSystem2D in scene!")

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
	# F7 to open mission selection dialog (only in 2D painting mode)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F7 and not dialog.visible:
		if PaintingModeManager and PaintingModeManager.current_mode == PaintingModeManager.Mode.MODE_2D:
			_open_dialog()
			get_viewport().set_input_as_handled()
			return

	# When dialog is visible, handle input
	if dialog.visible:
		# Escape to close
		if event.is_action_pressed("ui_cancel"):
			_close_dialog()
			get_viewport().set_input_as_handled()
			return

		# Arrow keys to navigate mission list
		if event.is_action_pressed("ui_down"):
			_select_next_mission()
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("ui_up"):
			_select_previous_mission()
			get_viewport().set_input_as_handled()
			return

		# Enter to start mission
		if event.is_action_pressed("ui_accept"):
			_on_start_mission()
			get_viewport().set_input_as_handled()
			return

func _open_dialog():
	"""Show the mission selection dialog"""
	if not MissionManager:
		push_error("MissionSelectionUI: MissionManager not found!")
		return

	# Disable painting system input while dialog is open
	if painting_system_2d:
		painting_system_2d.set_input_enabled(false)

	# Populate mission list
	_populate_mission_list()

	# Show dialog
	dialog.visible = true

	# Disable player input
	if CameraManager:
		CameraManager.set_player_input(false)

	# Select first mission
	if MissionManager.available_missions.size() > 0:
		selected_index = 0
		_update_selection()

	# Focus start button
	start_button.grab_focus()

func _close_dialog():
	"""Hide the dialog"""
	dialog.visible = false

	# Re-enable painting system input
	if painting_system_2d:
		painting_system_2d.set_input_enabled(true)

	# Re-enable player input
	if CameraManager:
		CameraManager.set_player_input(true)

func _populate_mission_list():
	"""Create mission cards for all available missions"""
	# Clear existing cards
	for card in mission_cards:
		card.queue_free()
	mission_cards.clear()

	# Create a card for each mission
	for i in range(MissionManager.available_missions.size()):
		var mission = MissionManager.available_missions[i]
		var card = _create_mission_card(mission, i)
		mission_list_container.add_child(card)
		mission_cards.append(card)

func _create_mission_card(mission: PaintingMission, index: int) -> MissionCard:
	"""Create a visual card for a mission"""
	var card = MissionCardScene.instantiate() as MissionCard
	card.setup(mission, index)
	card.card_clicked.connect(_on_card_clicked)
	return card

func _on_card_clicked(index: int):
	"""Handle mission card click"""
	selected_index = index
	_update_selection()

func _select_next_mission():
	"""Select the next mission in the list"""
	if MissionManager.available_missions.size() == 0:
		return

	selected_index = (selected_index + 1) % MissionManager.available_missions.size()
	_update_selection()

func _select_previous_mission():
	"""Select the previous mission in the list"""
	if MissionManager.available_missions.size() == 0:
		return

	selected_index = (selected_index - 1) % MissionManager.available_missions.size()
	if selected_index < 0:
		selected_index = MissionManager.available_missions.size() - 1
	_update_selection()

func _update_selection():
	"""Update UI to show currently selected mission"""
	if selected_index < 0 or selected_index >= MissionManager.available_missions.size():
		return

	# Update card selection state
	for i in range(mission_cards.size()):
		mission_cards[i].set_selected(i == selected_index)

	# Update preview panel
	selected_mission = MissionManager.available_missions[selected_index]
	_update_preview_panel()

func _update_preview_panel():
	"""Update the right-side preview panel with selected mission details"""
	if not selected_mission:
		return

	# Update title
	mission_title.text = selected_mission.title

	# Update description
	mission_description.text = selected_mission.description

	# Update difficulty
	difficulty_label.text = "Difficulty: %d/10" % selected_mission.difficulty

	# Update completion status
	var completion_data = MissionManager.get_mission_completion(selected_mission.mission_id)
	if completion_data["completed"]:
		completion_label.text = "Completed - Grade: %s (%.1f%%)" % [
			completion_data["grade"],
			completion_data["best_score"]
		]
		completion_label.modulate = Color(0.4, 1.0, 0.4)  # Green
		completion_label.visible = true
	else:
		completion_label.text = "Not completed"
		completion_label.modulate = Color(0.8, 0.8, 0.8)
		completion_label.visible = true

	# Update preview image
	if selected_mission.reference_image_path and selected_mission.reference_image_path != "":
		var texture = load(selected_mission.reference_image_path) as Texture2D
		if texture:
			preview_image.texture = texture
		else:
			preview_image.texture = null
	else:
		preview_image.texture = null

func _on_start_mission():
	"""Start the selected mission"""
	if not selected_mission:
		push_error("MissionSelectionUI: No mission selected!")
		return

	if not painting_system_2d:
		push_error("MissionSelectionUI: No painting system found!")
		return

	# Start the mission
	MissionManager.start_mission(selected_mission)
	painting_system_2d.start_mission(selected_mission)

	# Close dialog
	_close_dialog()

	print("MissionSelectionUI: Starting mission '%s'" % selected_mission.title)
