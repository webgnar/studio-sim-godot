extends Control
class_name MissionSelectionUI

## UI for browsing and selecting painting missions
## Opens with F7 key in 3D mode, displays mission list and details

# Preload the mission card scene
const MissionCardScene = preload("res://scenes/UI/MissionCard.tscn")

# Preload button icons
const StartMissionIcon = preload("res://sprites/ui/startmission.png")
const AbortMissionIcon = preload("res://sprites/ui/abortmission.png")

@onready var dialog = $Dialog
@onready var scroll_container = $Dialog/MarginContainer/HBoxContainer/LeftPanel/ScrollContainer
@onready var mission_list_container = $Dialog/MarginContainer/HBoxContainer/LeftPanel/ScrollContainer/MissionList
@onready var preview_image = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/PreviewImage
@onready var mission_title = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/MissionTitle
@onready var mission_description = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var difficulty_label = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/DifficultyLabel
@onready var completion_label = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/CompletionLabel
@onready var view_results_button = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ButtonContainer/ViewResultsButton
@onready var start_button = $Dialog/MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ButtonContainer/StartButton
@onready var completed_missions_label = $Dialog/MarginContainer/HBoxContainer/LeftPanel/StatsPanel/MarginContainer/VBoxContainer/CompletedMissionsLabel
@onready var paintings_created_label = $Dialog/MarginContainer/HBoxContainer/LeftPanel/StatsPanel/MarginContainer/VBoxContainer/PaintingsCreatedLabel
@onready var confirmation_dialog = $ConfirmationDialog

var results_viewer = null  # MissionResultsViewer (dynamic typing to avoid circular dependency)
var selected_mission: PaintingMission = null
var selected_index: int = 0
var mission_cards: Array[MissionCard] = []

# Navigation state
enum NavMode { MISSION_LIST, PREVIEW_BUTTONS }
var nav_mode: NavMode = NavMode.MISSION_LIST
var preview_buttons: Array[Button] = []
var preview_button_index: int = 0

func _ready():
	# Connect button signals
	view_results_button.pressed.connect(_on_view_results)
	start_button.pressed.connect(_on_start_or_abort_mission)


	# Connect confirmation dialog
	confirmation_dialog.confirmed.connect(_on_abort_confirmed)

	# Setup preview button navigation array (View Results, Start)
	preview_buttons = [view_results_button, start_button]

	# Hide dialog initially
	dialog.visible = false

	# Register with UIManager
	if UIManager:
		UIManager.register_screen("mission_selection", self)

	# Connect to PaintingSpawner
	if PaintingSpawner:
		PaintingSpawner.painting_created.connect(_on_painting_created)

	# Find results viewer
	_find_results_viewer()

	# Update stats display
	_update_stats_display()

func _find_results_viewer():
	"""Find the MissionResultsViewer in the scene tree"""
	var root = get_tree().root
	results_viewer = _search_for_results_viewer(root)

	if not results_viewer:
		push_error("MissionSelectionUI: Could not find MissionResultsViewer in scene!")

func _search_for_results_viewer(node: Node):
	"""Recursively search for MissionResultsViewer"""
	if node.get_script() and node.get_script().get_global_name() == "MissionResultsViewer":
		return node

	for child in node.get_children():
		var result = _search_for_results_viewer(child)
		if result:
			return result

	return null

func _input(event):
	# Only handle input when dialog is visible
	if not dialog.visible:
		return

	var viewport = get_viewport()
	if not viewport:
		return

	# Start button or go_back to close dialog (works in both modes)
	if event.is_action_pressed("start") or event.is_action_pressed("go_back"):
		if nav_mode == NavMode.PREVIEW_BUTTONS:
			_exit_preview_mode()
		else:
			_close_dialog()
		viewport.set_input_as_handled()
		return

	# Handle input based on navigation mode
	if nav_mode == NavMode.MISSION_LIST:
		_handle_mission_list_input(event, viewport)
	elif nav_mode == NavMode.PREVIEW_BUTTONS:
		_handle_preview_buttons_input(event, viewport)

func _handle_mission_list_input(event, viewport):
	"""Handle input when navigating the mission list"""
	# WASD / stick to navigate mission list
	if event.is_action_pressed("move_back"):
		_select_next_mission()
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("move_forward"):
		_select_previous_mission()
		viewport.set_input_as_handled()
		return

	# Jump (A button / Space) or move_right to enter preview button mode
	if event.is_action_pressed("jump") or event.is_action_pressed("move_right"):
		_enter_preview_mode()
		viewport.set_input_as_handled()
		return

func _handle_preview_buttons_input(event, viewport):
	"""Handle input when navigating preview buttons"""
	# Left to navigate buttons or exit to mission list
	if event.is_action_pressed("move_left"):
		# If at the first button, exit back to mission list
		if _is_at_first_button():
			_exit_preview_mode()
		else:
			_select_previous_button()
		viewport.set_input_as_handled()
		return

	# Right to navigate buttons
	if event.is_action_pressed("move_right"):
		_select_next_button()
		viewport.set_input_as_handled()
		return

	# Jump (A button / Space) to activate focused button
	if event.is_action_pressed("jump"):
		_activate_focused_button()
		viewport.set_input_as_handled()
		return

func _enter_preview_mode():
	"""Enter preview button navigation mode"""
	nav_mode = NavMode.PREVIEW_BUTTONS
	preview_button_index = 0
	_update_button_focus()
	print("MissionSelectionUI: Entered preview button mode")

func _exit_preview_mode():
	"""Exit preview button mode and return to mission list"""
	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()
	print("MissionSelectionUI: Exited preview button mode")

func _is_at_first_button() -> bool:
	"""Check if we're at the first visible/enabled button"""
	# Find the first visible enabled button
	for i in range(preview_buttons.size()):
		if preview_buttons[i].visible and not preview_buttons[i].disabled:
			return preview_button_index == i
	return true

func _select_next_button():
	"""Navigate to the next visible button"""
	var start_index = preview_button_index
	var attempts = 0

	while attempts < preview_buttons.size():
		preview_button_index = (preview_button_index + 1) % preview_buttons.size()

		# Skip invisible or disabled buttons
		if preview_buttons[preview_button_index].visible and not preview_buttons[preview_button_index].disabled:
			_update_button_focus()
			return

		attempts += 1

	# If no valid button found, stay on current
	preview_button_index = start_index

func _select_previous_button():
	"""Navigate to the previous visible button"""
	var start_index = preview_button_index
	var attempts = 0

	while attempts < preview_buttons.size():
		preview_button_index = (preview_button_index - 1) % preview_buttons.size()
		if preview_button_index < 0:
			preview_button_index = preview_buttons.size() - 1

		# Skip invisible or disabled buttons
		if preview_buttons[preview_button_index].visible and not preview_buttons[preview_button_index].disabled:
			_update_button_focus()
			return

		attempts += 1

	# If no valid button found, stay on current
	preview_button_index = start_index

func _update_button_focus():
	"""Update which button has focus highlight"""
	# Find first visible enabled button if current is invalid
	if preview_button_index >= preview_buttons.size() or \
	   not preview_buttons[preview_button_index].visible or \
	   preview_buttons[preview_button_index].disabled:
		for i in range(preview_buttons.size()):
			if preview_buttons[i].visible and not preview_buttons[i].disabled:
				preview_button_index = i
				break

	# Focus the selected button
	if preview_button_index < preview_buttons.size():
		preview_buttons[preview_button_index].grab_focus()

func _clear_button_focus():
	"""Clear button focus when exiting preview mode"""
	for button in preview_buttons:
		if button:
			button.release_focus()

func _activate_focused_button():
	"""Activate the currently focused button"""
	if preview_button_index < preview_buttons.size():
		var button = preview_buttons[preview_button_index]
		if button.visible and not button.disabled:
			button.pressed.emit()
			print("MissionSelectionUI: Activated button: ", button.name)

func _open_dialog():
	"""Show the mission selection dialog"""
	if not MissionManager:
		push_error("MissionSelectionUI: MissionManager not found!")
		return

	# Disable painting system input while dialog is open
	var painting_system = PaintingModeManager.painting_system_2d
	if painting_system:
		painting_system.set_input_enabled(false)

	# Reset navigation mode to mission list
	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()

	# Populate mission list
	_populate_mission_list()

	# Show dialog
	dialog.visible = true

	# Disable player input
	if CameraManager:
		CameraManager.set_player_input(false)

	# Select current mission if there is one, otherwise select first mission
	if MissionManager.available_missions.size() > 0:
		if MissionManager.current_mission:
			# Find the index of the current mission
			for i in range(MissionManager.available_missions.size()):
				if MissionManager.available_missions[i] == MissionManager.current_mission:
					selected_index = i
					break
		else:
			selected_index = 0
		_update_selection()

func show_screen():
	"""Show the mission selection screen (called by UIManager)"""
	_open_dialog()
	_update_stats_display()

func hide_screen():
	"""Hide the mission selection screen (called by UIManager)"""
	dialog.visible = false

	# Re-enable painting system input
	var painting_system = PaintingModeManager.painting_system_2d
	if painting_system:
		painting_system.set_input_enabled(true)

func _close_dialog():
	"""Hide the dialog and return to gameplay"""
	# Reset navigation mode
	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()

	if UIManager:
		UIManager.change_state(UIManager.GameState.GAMEPLAY)

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

	# Scroll to the selected card
	_scroll_to_selected_card()

	# Update preview panel
	selected_mission = MissionManager.available_missions[selected_index]
	_update_preview_panel()

func _scroll_to_selected_card():
	"""Scroll the ScrollContainer to make the selected card visible"""
	if not scroll_container or selected_index >= mission_cards.size():
		return
	
	var selected_card = mission_cards[selected_index]
	if not selected_card:
		return
	
	# Get the card's position and size
	var card_top = selected_card.position.y
	var card_bottom = card_top + selected_card.size.y
	
	# Get the visible area of the scroll container
	var scroll_pos = scroll_container.scroll_vertical
	var viewport_height = scroll_container.size.y
	var visible_top = scroll_pos
	var visible_bottom = scroll_pos + viewport_height
	
	# Check if card is above visible area
	if card_top < visible_top:
		scroll_container.scroll_vertical = int(card_top)
	# Check if card is below visible area
	elif card_bottom > visible_bottom:
		scroll_container.scroll_vertical = int(card_bottom - viewport_height)

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

	# Check if this is the current mission
	var is_current_mission = (MissionManager and MissionManager.current_mission == selected_mission)

	# Update button icon based on whether this is the current mission
	# (No text needed - icons have text baked in)
	if is_current_mission:
		start_button.icon = AbortMissionIcon
	else:
		start_button.icon = StartMissionIcon

	# Update completion status and buttons
	var completion_data = MissionManager.get_mission_completion(selected_mission.mission_id)
	if completion_data["completed"]:
		completion_label.text = "Completed - Grade: %s (%.1f%%)" % [
			completion_data["grade"],
			completion_data["best_score"]
		]
		completion_label.modulate = Color(0.4, 1.0, 0.4)  # Green
		completion_label.visible = true

		# Show View Results button
		view_results_button.visible = true

		# Enable/disable View Results based on saved painting availability
		var has_saved_painting = completion_data.get("latest_painting_path", "") != "" or completion_data.get("best_painting_path", "") != ""
		view_results_button.disabled = not has_saved_painting

		if not has_saved_painting:
			view_results_button.tooltip_text = "No saved painting available"
		else:
			view_results_button.tooltip_text = ""
	else:
		completion_label.text = "Not completed"
		completion_label.modulate = Color(0.8, 0.8, 0.8)
		completion_label.visible = true

		# Hide View Results button
		view_results_button.visible = false

	# Update preview image
	if selected_mission.reference_image_path and selected_mission.reference_image_path != "":
		var texture = load(selected_mission.reference_image_path) as Texture2D
		if texture:
			preview_image.texture = texture
		else:
			preview_image.texture = null
	else:
		preview_image.texture = null

func _on_start_or_abort_mission():
	"""Start the selected mission or abort if it's the current mission"""
	if not selected_mission:
		push_error("MissionSelectionUI: No mission selected!")
		return

	# Check if this is the current mission (abort case)
	if MissionManager and MissionManager.current_mission == selected_mission:
		# Show confirmation dialog
		confirmation_dialog.popup_centered()
		return

	# Get the current painting system (always fresh reference)
	var painting_system = PaintingModeManager.painting_system_2d
	if not painting_system:
		push_error("MissionSelectionUI: No painting system found!")
		return

	# Start the mission (MissionManager will set state to IN_MISSION)
	MissionManager.start_mission(selected_mission)
	painting_system.start_mission(selected_mission)

	# Reset navigation mode and hide dialog
	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()
	dialog.visible = false

	print("MissionSelectionUI: Starting mission '%s'" % selected_mission.title)

func _on_abort_confirmed():
	"""Abort the current mission after confirmation"""
	if not MissionManager or not MissionManager.current_mission:
		return

	# Abort the mission (this will emit mission_aborted signal and clear current_mission)
	MissionManager.abort_mission()

	# Reset navigation mode and close dialog
	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()

	# Return to GAMEPLAY state
	if UIManager:
		UIManager.change_state(UIManager.GameState.GAMEPLAY)

func _on_view_results():
	"""Show results viewer for the selected mission"""
	if not selected_mission:
		push_error("MissionSelectionUI: No mission selected!")
		return

	if not results_viewer:
		push_error("MissionSelectionUI: Results viewer not found!")
		return

	# Reset navigation mode
	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()

	# Hide mission selection
	dialog.visible = false

	# Show results viewer
	results_viewer.show_results_for_mission(selected_mission)

	print("MissionSelectionUI: Viewing results for mission '%s'" % selected_mission.title)

func _on_painting_created(count: int):
	"""Update stats display when a painting is created"""
	_update_stats_display()

func _update_stats_display():
	"""Update mission completion statistics"""
	if UIManager and completed_missions_label:
		completed_missions_label.text = "Missions Completed: %d" % UIManager.missions_completed

	if PaintingSpawner and paintings_created_label:
		paintings_created_label.text = "Paintings Created: %d" % PaintingSpawner.paintings_created
