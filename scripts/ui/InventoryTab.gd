extends Control
class_name InventoryTab

## Inventory tab content for viewing and naming paintings
## Layout mirrors MissionSelectionUI: left sidebar with painting cards, right detail panel
## Supports full controller navigation

const PaintingCardScene = preload("res://scenes/UI/PaintingCard.tscn")

@onready var scroll_container: ScrollContainer = $HBoxContainer/LeftPanel/ScrollContainer
@onready var painting_list_container: VBoxContainer = $HBoxContainer/LeftPanel/ScrollContainer/PaintingList
@onready var stats_label: Label = $HBoxContainer/LeftPanel/StatsLabel
@onready var preview_image: TextureRect = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/PaintingImage
@onready var name_input: LineEdit = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/NameContainer/NameInput
@onready var statement_label: Label = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/StatementLabel
@onready var statement_input: TextEdit = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/StatementInput
@onready var save_button: Button = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/SaveButton
@onready var empty_label: Label = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/EmptyLabel

# Navigation
enum NavMode { PAINTING_LIST, DETAIL_PANEL }
var nav_mode: NavMode = NavMode.PAINTING_LIST
var selected_index: int = 0
var painting_cards: Array[PaintingCard] = []
var painting_entries: Array = []  # Array of dicts from WorldStateManager
var detail_focus_index: int = 0  # 0=name, 1=statement, 2=save
var is_editing_text: bool = false
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15

# Sound (reuse parent PauseMenu sounds)
var button_nav_sound: AudioStreamPlayer = null
var button_hit_sound: AudioStreamPlayer = null

func _ready():
	# Connect save button
	save_button.pressed.connect(_on_save_pressed)
	save_button.focus_mode = Control.FOCUS_ALL

	# Find sounds from parent PauseMenu
	var pause_menu = _find_parent_pause_menu()
	if pause_menu:
		button_nav_sound = pause_menu.get_node_or_null("ButtonNavSound")
		button_hit_sound = pause_menu.get_node_or_null("ButtonHitSound")

	# Disable input processing by default (PauseMenu manages activation via process_mode)
	process_mode = Node.PROCESS_MODE_DISABLED

func _process(delta):
	if not visible:
		return

	if input_cooldown > 0:
		input_cooldown -= delta

func _input(event):
	if not visible:
		return

	# Don't process if text is being edited
	if is_editing_text:
		if event.is_action_pressed("go_back") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			_exit_text_editing()
			get_viewport().set_input_as_handled()
		# Also handle Enter in LineEdit to exit editing
		if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			var focused = get_viewport().gui_get_focus_owner()
			if focused is LineEdit:
				_exit_text_editing()
				get_viewport().set_input_as_handled()
		return

	if nav_mode == NavMode.PAINTING_LIST:
		_handle_painting_list_input(event)
	elif nav_mode == NavMode.DETAIL_PANEL:
		_handle_detail_panel_input(event)

func _handle_painting_list_input(event):
	"""Handle input when navigating the painting list"""
	var viewport = get_viewport()

	if event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		if input_cooldown <= 0:
			_select_next_painting()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		if input_cooldown <= 0:
			_select_previous_painting()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# Enter detail panel
	if event.is_action_pressed("jump") or event.is_action_pressed("move_right") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		if input_cooldown <= 0 and painting_entries.size() > 0:
			_enter_detail_mode()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# go_back not consumed here - let PauseMenu handle it for tab bar return

func _handle_detail_panel_input(event):
	"""Handle input when navigating the detail panel"""
	var viewport = get_viewport()

	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		if input_cooldown <= 0:
			_navigate_detail(1)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		if input_cooldown <= 0:
			_navigate_detail(-1)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# Accept/A button - activate focused item
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if input_cooldown <= 0:
			_activate_detail_item()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# Left or B to go back to painting list
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		if input_cooldown <= 0:
			_exit_detail_mode()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("go_back"):
		_exit_detail_mode()
		viewport.set_input_as_handled()
		return

# ============================================================================
# Activation / Population
# ============================================================================

func activate():
	"""Called when the inventory tab becomes active"""
	_populate_painting_list()
	nav_mode = NavMode.PAINTING_LIST
	is_editing_text = false
	input_cooldown = 0.0

	if painting_entries.size() > 0:
		selected_index = 0
		_update_selection()
		_show_detail_panel(true)
	else:
		_show_detail_panel(false)

func _populate_painting_list():
	"""Populate the painting list from WorldStateManager"""
	# Clear existing cards
	for child in painting_list_container.get_children():
		child.queue_free()
	painting_cards.clear()
	painting_entries.clear()

	# Get all paintings
	painting_entries = WorldStateManager.get_all_paintings()

	# Create cards
	for i in range(painting_entries.size()):
		var card = PaintingCardScene.instantiate() as PaintingCard
		painting_list_container.add_child(card)
		card.setup(painting_entries[i], i)
		card.card_clicked.connect(_on_card_clicked)
		painting_cards.append(card)

	# Update stats
	stats_label.text = "Paintings: %d" % painting_entries.size()

func _show_detail_panel(show: bool):
	"""Show or hide the detail panel content"""
	preview_image.visible = show
	name_input.visible = show
	name_input.get_parent().visible = show  # NameContainer
	if statement_label:
		statement_label.visible = show
	statement_input.visible = show
	save_button.visible = show

	# Show/hide empty label
	if empty_label:
		empty_label.visible = not show

# ============================================================================
# Navigation
# ============================================================================

func _select_next_painting():
	"""Select the next painting in the list"""
	if painting_entries.size() == 0:
		return
	selected_index = (selected_index + 1) % painting_entries.size()
	_update_selection()
	if button_nav_sound:
		button_nav_sound.play()

func _select_previous_painting():
	"""Select the previous painting in the list"""
	if painting_entries.size() == 0:
		return
	selected_index = (selected_index - 1) % painting_entries.size()
	if selected_index < 0:
		selected_index = painting_entries.size() - 1
	_update_selection()
	if button_nav_sound:
		button_nav_sound.play()

func _update_selection():
	"""Update UI to show currently selected painting"""
	if selected_index < 0 or selected_index >= painting_entries.size():
		return

	# Update card selection state
	for i in range(painting_cards.size()):
		painting_cards[i].set_selected(i == selected_index)

	# Scroll to selected card
	_scroll_to_selected_card()

	# Update preview panel
	var data = painting_entries[selected_index]
	_update_preview(data)

func _scroll_to_selected_card():
	"""Scroll the ScrollContainer to make the selected card visible"""
	if not scroll_container or selected_index >= painting_cards.size():
		return

	var selected_card = painting_cards[selected_index]
	if not selected_card:
		return

	var card_top = selected_card.position.y
	var card_bottom = card_top + selected_card.size.y
	var scroll_pos = scroll_container.scroll_vertical
	var viewport_height = scroll_container.size.y
	var visible_top = scroll_pos
	var visible_bottom = scroll_pos + viewport_height

	if card_top < visible_top:
		scroll_container.scroll_vertical = int(card_top)
	elif card_bottom > visible_bottom:
		scroll_container.scroll_vertical = int(card_bottom - viewport_height)

func _update_preview(data: Dictionary):
	"""Update the right-side preview with painting details"""
	# Load painting texture
	var texture_path = data.get("texture_path", "")
	if texture_path != "" and FileAccess.file_exists(texture_path):
		var image = Image.new()
		var error = image.load(texture_path)
		if error == OK:
			image.rotate_90(CLOCKWISE)
			preview_image.texture = ImageTexture.create_from_image(image)
		else:
			preview_image.texture = null
	else:
		preview_image.texture = null

	# Set name and statement fields
	name_input.text = data.get("name", "")
	statement_input.text = data.get("artist_statement", "")

# ============================================================================
# Detail Panel Navigation
# ============================================================================

func _enter_detail_mode():
	"""Enter the detail panel navigation mode"""
	nav_mode = NavMode.DETAIL_PANEL
	detail_focus_index = 0
	_update_detail_focus()
	if button_hit_sound:
		button_hit_sound.play()

func _exit_detail_mode():
	"""Exit detail panel and return to painting list"""
	nav_mode = NavMode.PAINTING_LIST
	_clear_detail_focus()
	if button_nav_sound:
		button_nav_sound.play()

func _navigate_detail(direction: int):
	"""Navigate up/down through detail panel items"""
	var new_index = detail_focus_index + direction
	new_index = clampi(new_index, 0, 2)  # 0=name, 1=statement, 2=save
	if new_index != detail_focus_index:
		detail_focus_index = new_index
		_update_detail_focus()
		if button_nav_sound:
			button_nav_sound.play()

func _update_detail_focus():
	"""Update visual focus on the detail panel item"""
	_clear_detail_focus()
	match detail_focus_index:
		0:
			name_input.grab_focus()
		1:
			statement_input.grab_focus()
		2:
			save_button.grab_focus()

func _clear_detail_focus():
	"""Clear focus from all detail panel items"""
	name_input.release_focus()
	statement_input.release_focus()
	save_button.release_focus()

func _activate_detail_item():
	"""Activate the currently focused detail item"""
	match detail_focus_index:
		0:
			# Enter text editing for name
			_enter_text_editing(name_input)
		1:
			# Enter text editing for statement
			_enter_text_editing(statement_input)
		2:
			# Save
			_on_save_pressed()
			if button_hit_sound:
				button_hit_sound.play()

func _enter_text_editing(control: Control):
	"""Enter text editing mode for a LineEdit or TextEdit"""
	is_editing_text = true
	control.grab_focus()
	if control is LineEdit:
		control.caret_column = control.text.length()
	elif control is TextEdit:
		control.set_caret_column(control.get_line(control.get_caret_line()).length())

func _exit_text_editing():
	"""Exit text editing mode"""
	is_editing_text = false
	# Keep focus on the control but prevent text input
	_update_detail_focus()

# ============================================================================
# Actions
# ============================================================================

func _on_save_pressed():
	"""Save the painting name and artist statement"""
	if selected_index < 0 or selected_index >= painting_entries.size():
		return

	var data = painting_entries[selected_index]
	var painting_node = data["node"]

	if not is_instance_valid(painting_node):
		push_warning("InventoryTab: Painting node no longer valid")
		return

	var new_name = name_input.text.strip_edges()
	var new_statement = statement_input.text.strip_edges()

	# Update through WorldStateManager
	WorldStateManager.update_painting_metadata(painting_node, new_name, new_statement)

	# Update local data
	painting_entries[selected_index]["name"] = new_name
	painting_entries[selected_index]["artist_statement"] = new_statement

	# Update the card in the sidebar
	if selected_index < painting_cards.size():
		painting_cards[selected_index].update_name(new_name)

	print("InventoryTab: Saved painting '%s'" % new_name)

func _on_card_clicked(index: int):
	"""Handle painting card click"""
	selected_index = index
	_update_selection()

# ============================================================================
# Helpers
# ============================================================================

func _find_parent_pause_menu() -> Node:
	"""Find the PauseMenu parent node"""
	var node = get_parent()
	while node:
		if node.get_script() and node.get_script().get_global_name() == "PauseMenuUI":
			return node
		node = node.get_parent()
	return null
