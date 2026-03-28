extends Control
class_name MissionSelectionUI

## UI for browsing and selecting painting missions
## Embedded inside PauseMenu (CommissionsContent)

@export_group("Completion Colors")
@export var completed_color: Color = Color(0.4, 1.0, 0.4)
@export var not_completed_color: Color = Color(0.8, 0.8, 0.8)

# Preload the mission card scene
const MissionCardScene = preload("res://scenes/UI/MissionCard.tscn")


@onready var scroll_container = $MarginContainer/HBoxContainer/LeftPanel/ScrollContainer
@onready var mission_list_container = $MarginContainer/HBoxContainer/LeftPanel/ScrollContainer/MissionList
@onready var preview_image = $MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/PreviewImage
@onready var mission_title = $MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/MissionTitle
@onready var mission_description = $MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var difficulty_label = $MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/DifficultyLabel
@onready var completion_label = $MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/CompletionLabel
@onready var view_results_button = $MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ButtonContainer/ViewResultsButton
@onready var start_button = $MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ButtonContainer/StartButton
@onready var completed_missions_label = $MarginContainer/HBoxContainer/LeftPanel/StatsPanel/MarginContainer/VBoxContainer/CompletedMissionsLabel

# Preview content container (the normal mission detail view)
@onready var preview_content = $MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer

# Results display component
@onready var results_display: MissionResultsDisplay = $MarginContainer/HBoxContainer/RightPanel/PreviewPanel/MarginContainer/MissionResultsDisplay

var selected_mission: PaintingMission = null
var selected_index: int = 0
var mission_cards: Array[MissionCard] = []

# Navigation state
enum NavMode { MISSION_LIST, PREVIEW_BUTTONS }
var nav_mode: NavMode = NavMode.MISSION_LIST
var preview_buttons: Array[Button] = []
var preview_button_index: int = 0
var keyboard_nav_enabled: bool = false
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15

# Results view state
var showing_results: bool = false
var is_showing_live_results: bool = false

# Sound (reuse parent PauseMenu sounds)
var button_nav_sound: AudioStreamPlayer = null
var button_hit_sound: AudioStreamPlayer = null

func _ready():
	# Connect button signals
	view_results_button.pressed.connect(_on_view_results)
	start_button.pressed.connect(_on_start_or_abort_mission)

	# Connect results display signals
	results_display.retry_pressed.connect(_on_results_retry)

	# Setup preview button navigation array (View Results, Start)
	preview_buttons = [view_results_button, start_button]

	# Set up focus navigation
	_setup_focus_navigation()

	# Update stats display
	_update_stats_display()

	# Find sounds from parent PauseMenu
	var pause_menu = _find_parent_pause_menu()
	if pause_menu:
		button_nav_sound = pause_menu.get_node_or_null("ButtonNavSound")
		button_hit_sound = pause_menu.get_node_or_null("ButtonHitSound")

	if LocaleManager:
		LocaleManager.locale_changed.connect(_on_locale_changed)

	# Remove unused Difficulty label (feature not implemented)
	difficulty_label.queue_free()

	# Disable input processing by default (PauseMenu manages activation via process_mode)
	process_mode = Node.PROCESS_MODE_DISABLED

func _process(delta):
	if not visible:
		return

	# Update input cooldown
	if input_cooldown > 0:
		input_cooldown -= delta

func _input(event):
	# Only handle input when visible
	if not visible:
		return

	# Only process keyboard/gamepad input when enabled (mouse works via gui_input signals)
	if not keyboard_nav_enabled:
		return

	var viewport = get_viewport()
	if not viewport:
		return

	# If showing results, handle results-specific input
	if showing_results:
		_handle_results_input(event, viewport)
		return

	# go_back navigates back through nav modes; stop at MISSION_LIST and let PauseMenu handle it
	if event.is_action_pressed("go_back"):
		if nav_mode == NavMode.PREVIEW_BUTTONS:
			_exit_preview_mode()
			viewport.set_input_as_handled()
		# When in MISSION_LIST, don't consume - let PauseMenu handle it (return to tab bar)
		return

	# Handle input based on navigation mode
	if nav_mode == NavMode.MISSION_LIST:
		_handle_mission_list_input(event, viewport)
	elif nav_mode == NavMode.PREVIEW_BUTTONS:
		_handle_preview_buttons_input(event, viewport)

func _handle_results_input(event, viewport):
	"""Handle input when results view is shown"""
	if event.is_action_pressed("go_back"):
		_on_results_back()
		viewport.set_input_as_handled()
		return

func _handle_mission_list_input(event, viewport):
	"""Handle input when navigating the mission list"""
	# Up - clamp at top; don't consume at boundary so PauseMenu returns to tab bar
	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		if input_cooldown <= 0:
			if selected_index > 0:
				_select_previous_mission()
				input_cooldown = input_cooldown_time
				viewport.set_input_as_handled()
			# At top: don't consume → PauseMenu catches and enters tab bar
		else:
			viewport.set_input_as_handled()
		return

	# Down - clamp at bottom, always consume
	if event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		if input_cooldown <= 0:
			if selected_index < MissionManager.available_missions.size() - 1:
				_select_next_mission()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# Jump (A button / Space) or move_right or ui_right or ui_accept to enter preview button mode
	if event.is_action_pressed("jump") or event.is_action_pressed("move_right") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		if input_cooldown <= 0:
			_enter_preview_mode()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

func _handle_preview_buttons_input(event, viewport):
	"""Handle input when navigating preview buttons"""
	# Up - exit preview mode, don't consume so PauseMenu enters tab bar
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		if input_cooldown <= 0:
			_exit_preview_mode()
			input_cooldown = input_cooldown_time
		# Don't consume → falls through to PauseMenu → enters tab bar
		return

	# Down - nowhere to go, just consume
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		viewport.set_input_as_handled()
		return

	# Left / D-pad left to navigate buttons or exit to mission list
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		if input_cooldown <= 0:
			# If at the first button, exit back to mission list
			if _is_at_first_button():
				_exit_preview_mode()
				# Play navigation sound when exiting
				if button_nav_sound:
					button_nav_sound.play()
			else:
				_select_previous_button()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# Right / D-pad right to navigate buttons
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

func _enter_preview_mode():
	"""Enter preview button navigation mode"""
	nav_mode = NavMode.PREVIEW_BUTTONS
	preview_button_index = 0
	_update_button_focus()

	# Play navigation sound when entering preview mode
	if button_nav_sound:
		button_nav_sound.play()

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
		if preview_buttons[i] and preview_buttons[i].visible and not preview_buttons[i].disabled:
			return preview_button_index == i
	return true

func _select_next_button():
	"""Navigate to the next visible button"""
	var start_index = preview_button_index
	var attempts = 0

	while attempts < preview_buttons.size():
		preview_button_index = (preview_button_index + 1) % preview_buttons.size()

		# Skip invisible, disabled, or null buttons
		var button = preview_buttons[preview_button_index]
		if button and button.visible and not button.disabled:
			_update_button_focus()

			# Play navigation sound
			if button_nav_sound:
				button_nav_sound.play()
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

		# Skip invisible, disabled, or null buttons
		var button = preview_buttons[preview_button_index]
		if button and button.visible and not button.disabled:
			_update_button_focus()

			# Play navigation sound
			if button_nav_sound:
				button_nav_sound.play()
			return

		attempts += 1

	# If no valid button found, stay on current
	preview_button_index = start_index

func _update_button_focus():
	"""Update which button has focus highlight"""
	# Find first visible enabled button if current is invalid
	var current_button = preview_buttons[preview_button_index] if preview_button_index < preview_buttons.size() else null
	if preview_button_index >= preview_buttons.size() or \
	   not current_button or \
	   not current_button.visible or \
	   current_button.disabled:
		for i in range(preview_buttons.size()):
			if preview_buttons[i] and preview_buttons[i].visible and not preview_buttons[i].disabled:
				preview_button_index = i
				break

	# Focus the selected button
	if preview_button_index < preview_buttons.size():
		var button = preview_buttons[preview_button_index]
		if button:
			button.grab_focus()

func _clear_button_focus():
	"""Clear button focus when exiting preview mode"""
	for button in preview_buttons:
		if button:
			button.release_focus()

func _activate_focused_button():
	"""Activate the currently focused button"""
	if preview_button_index < preview_buttons.size():
		var button = preview_buttons[preview_button_index]
		if button and button.visible and not button.disabled:
			# Play button hit sound
			if button_hit_sound:
				button_hit_sound.play()

			button.pressed.emit()
			print("MissionSelectionUI: Activated button: ", button.name)

func _setup_focus_navigation():
	"""Set up gamepad/keyboard focus navigation for buttons"""
	# Enable focus mode for all buttons
	view_results_button.focus_mode = Control.FOCUS_ALL
	start_button.focus_mode = Control.FOCUS_ALL

	# Set up focus neighbors (horizontal navigation)
	view_results_button.focus_neighbor_right = view_results_button.get_path_to(start_button)
	view_results_button.focus_next = view_results_button.get_path_to(start_button)

	start_button.focus_neighbor_left = start_button.get_path_to(view_results_button)
	start_button.focus_previous = start_button.get_path_to(view_results_button)

func activate():
	"""Called when the commissions tab becomes active (called by PauseMenu)"""
	if not MissionManager:
		push_error("MissionSelectionUI: MissionManager not found!")
		return

	# Reset navigation mode to mission list
	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()
	is_showing_live_results = false

	# Make sure we're showing the preview, not results
	_hide_results_view()

	# Reset input cooldown
	input_cooldown = 0.0

	# Populate mission list
	_populate_mission_list()

	# Update stats
	_update_stats_display()

	# Select current mission if there is one, otherwise select first mission
	if MissionManager.available_missions.size() > 0:
		if MissionManager.current_mission:
			for i in range(MissionManager.available_missions.size()):
				if MissionManager.available_missions[i] == MissionManager.current_mission:
					selected_index = i
					break
		else:
			selected_index = 0
		_update_selection()

func show_screen():
	"""Show the mission selection screen (called by UIManager or PauseMenu)"""
	activate()

func hide_screen():
	"""Hide the mission selection screen (called by UIManager)"""
	# Re-enable painting system input
	var painting_system = PaintingModeManager.painting_system_2d
	if painting_system:
		painting_system.set_input_enabled(true)

func _populate_mission_list():
	"""Create mission cards for all available missions"""
	# Clear existing cards (including any placeholder cards from the editor)
	for child in mission_list_container.get_children():
		child.queue_free()
	mission_cards.clear()

	# add_child before setup so @onready vars are resolved when setup() runs
	for i in range(MissionManager.available_missions.size()):
		var mission = MissionManager.available_missions[i]
		var card = MissionCardScene.instantiate() as MissionCard
		mission_list_container.add_child(card)
		card.setup(mission, i)
		card.card_clicked.connect(_on_card_clicked)
		mission_cards.append(card)

func _on_card_clicked(index: int):
	"""Handle mission card click"""
	selected_index = index
	_update_selection()

	# If we were showing results, go back to preview
	if showing_results:
		_hide_results_view()

	# Notify parent PauseMenu to enter TAB_CONTENT mode (mouse entry)
	var pause_menu = _find_parent_pause_menu()
	if pause_menu and pause_menu.nav_mode == PauseMenuUI.NavMode.TAB_BAR:
		pause_menu._enter_tab_content_mode(true)

func _select_next_mission():
	"""Select the next mission in the list (clamped, no wrapping)"""
	if MissionManager.available_missions.size() == 0:
		return

	selected_index = mini(selected_index + 1, MissionManager.available_missions.size() - 1)
	_update_selection()

	# If we were showing results, go back to preview
	if showing_results:
		_hide_results_view()

	# Play navigation sound
	if button_nav_sound:
		button_nav_sound.play()

func _select_previous_mission():
	"""Select the previous mission in the list (clamped, no wrapping)"""
	if MissionManager.available_missions.size() == 0:
		return

	selected_index = maxi(selected_index - 1, 0)
	_update_selection()

	# If we were showing results, go back to preview
	if showing_results:
		_hide_results_view()

	# Play navigation sound
	if button_nav_sound:
		button_nav_sound.play()

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
	mission_title.text = tr(selected_mission.title)

	# Update description
	mission_description.text = tr(selected_mission.description)

	# Check if this is the current mission
	var is_current_mission = (MissionManager and MissionManager.current_mission == selected_mission)

	if is_current_mission:
		start_button.text = "Abort Mission"
	else:
		start_button.text = "Start Mission"

	# Update completion status and buttons
	var completion_data = MissionManager.get_mission_completion(selected_mission.mission_id)
	var has_any_attempt = MissionManager.progression.has(selected_mission.mission_id) \
		and (completion_data.get("latest_painting_path", "") != "" \
			or completion_data.get("best_painting_path", "") != "")

	if completion_data["completed"]:
		completion_label.text = tr("Completed - Grade: %s (%.1f%%)") % [
			completion_data["grade"],
			completion_data["best_score"]
		]
		completion_label.modulate = completed_color
	elif has_any_attempt:
		completion_label.text = tr("Attempted - Latest: %s (%.1f%%)") % [
			completion_data["latest_grade"],
			completion_data["latest_score"]
		]
		completion_label.modulate = not_completed_color
	else:
		completion_label.text = tr("Not attempted")
		completion_label.modulate = not_completed_color
	completion_label.visible = true

	# Show View Results button for any mission with a stored attempt
	view_results_button.visible = has_any_attempt
	view_results_button.disabled = not has_any_attempt
	view_results_button.tooltip_text = "" if has_any_attempt else tr("No saved attempt available")

	# Update preview image
	if selected_mission.reference_image_path and selected_mission.reference_image_path != "":
		var texture = load(selected_mission.reference_image_path) as Texture2D
		if texture:
			preview_image.texture = texture
		else:
			preview_image.texture = null
	else:
		preview_image.texture = null

# --- Results View ---

func _on_view_results():
	"""Show inline results for the selected mission"""
	if not selected_mission:
		return

	var completion_data = MissionManager.get_mission_completion(selected_mission.mission_id)

	is_showing_live_results = false
	showing_results = true
	preview_content.visible = false
	results_display.show_saved_results(selected_mission, completion_data)

	print("MissionSelectionUI: Viewing results for mission '%s'" % selected_mission.title)

func show_live_results_for_mission(result: ValidationResult, mission: PaintingMission) -> void:
	"""Show live results immediately after submission (called by PauseMenu)"""
	# Clear current_mission — painting has been submitted, mission is no longer active
	if MissionManager:
		MissionManager.current_mission = null

	# Select the submitted mission in the list
	for i in range(MissionManager.available_missions.size()):
		if MissionManager.available_missions[i] == mission:
			selected_index = i
			break
	_update_selection()

	# Show live results
	is_showing_live_results = true
	showing_results = true
	preview_content.visible = false
	results_display.show_live_results(result, mission)

func _hide_results_view():
	"""Switch back to normal preview content"""
	showing_results = false
	preview_content.visible = true
	results_display.visible = false

func _on_results_retry(mission: PaintingMission):
	"""Retry the mission from results view"""
	if not mission:
		return

	var painting_system = PaintingModeManager.painting_system_2d
	if not painting_system:
		push_error("MissionSelectionUI: No painting system found!")
		return

	MissionManager.start_mission(mission)
	painting_system.start_mission(mission)

	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()
	_hide_results_view()

	# Close the pause menu
	var pause_menu = _find_parent_pause_menu()
	if pause_menu:
		pause_menu._close_menu()

func _on_results_back():
	"""Return to mission preview from results view"""
	is_showing_live_results = false
	_hide_results_view()
	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()

# --- Other ---

func _on_start_or_abort_mission():
	"""Start the selected mission or abort if it's the current mission"""
	if not selected_mission:
		push_error("MissionSelectionUI: No mission selected!")
		return

	# Check if this is the current mission (abort case)
	if MissionManager and MissionManager.current_mission == selected_mission:
		# Abort the mission immediately
		_abort_mission_immediate()
		return

	# Get the current painting system (always fresh reference)
	var painting_system = PaintingModeManager.painting_system_2d
	if not painting_system:
		push_error("MissionSelectionUI: No painting system found!")
		return

	# Start the mission (MissionManager will set state to IN_MISSION)
	MissionManager.start_mission(selected_mission)
	painting_system.start_mission(selected_mission)

	# Reset navigation mode
	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()

	# Close the pause menu
	var pause_menu = _find_parent_pause_menu()
	if pause_menu:
		pause_menu._close_menu()

	print("MissionSelectionUI: Starting mission '%s'" % selected_mission.title)

func _abort_mission_immediate():
	"""Abort the current mission immediately without confirmation"""
	if not MissionManager or not MissionManager.current_mission:
		return

	# Abort the mission (this will emit mission_aborted signal and clear current_mission)
	MissionManager.abort_mission()

	# Reset navigation mode and close menu
	nav_mode = NavMode.MISSION_LIST
	_clear_button_focus()

	# Return to GAMEPLAY state
	if UIManager:
		UIManager.change_state(UIManager.GameState.GAMEPLAY)

	print("MissionSelectionUI: Mission aborted")

func _update_stats_display():
	"""Update commission completion statistics"""
	if UIManager and completed_missions_label:
		completed_missions_label.text = tr("Commissions Completed: %d") % UIManager.missions_completed

func _on_locale_changed(_locale: String) -> void:
	if visible:
		_update_stats_display()
		if selected_mission:
			_update_preview_panel()

func _find_parent_pause_menu() -> Node:
	"""Find the PauseMenu parent node"""
	var node = get_parent()
	while node:
		if node.get_script() and node.get_script().get_global_name() == "PauseMenuUI":
			return node
		node = node.get_parent()
	return null
