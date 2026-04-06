@tool
extends Control
class_name InventoryTab

## Inventory tab content for viewing and naming paintings
## Layout mirrors MissionSelectionUI: left sidebar with painting cards, right detail panel
## Supports full controller navigation

const PaintingCardScene = preload("res://scenes/UI/PaintingCard.tscn")
const VirtualKeyboardScene = preload("res://scenes/UI/VirtualKeyboard.tscn")

@onready var scroll_container: ScrollContainer = $HBoxContainer/LeftPanel/ScrollContainer
@onready var painting_list_container: VBoxContainer = $HBoxContainer/LeftPanel/ScrollContainer/PaintingList
@onready var stats_label: Label = $HBoxContainer/LeftPanel/StatsLabel
@onready var preview_image: TextureRect = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/PaintingImage
@onready var status_label: Label = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/LeftVBox/StatusLabel
@onready var name_input: LineEdit = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/LeftVBox/NameContainer/NameInput
@onready var statement_label: Label = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/LeftVBox/StatementLabel
@onready var statement_input: TextEdit = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/LeftVBox/StatementInput
@onready var empty_label: Label = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/EmptyLabel

# Navigation
enum NavMode { PAINTING_LIST, DETAIL_PANEL }
var nav_mode: NavMode = NavMode.PAINTING_LIST
var selected_index: int = 0
var painting_cards: Array[PaintingCard] = []
var painting_entries: Array = []  # Array of dicts from WorldStateManager
var detail_focus_index: int = 0  # 0=name, 1=statement
var is_editing_text: bool = false
var keyboard_nav_enabled: bool = false
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15
var _last_input_was_gamepad: bool = false
var _steam_editing_field: Control = null  # tracks which field the Steam/virtual keyboard is editing
var _virtual_keyboard: VirtualKeyboard = null
var _current_is_shipped: bool = false
var _detail_col: int = 0  # 0=left (statement), 1=right (critique) — shipped only

@onready var _critique_panel: VBoxContainer = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox
@onready var _critique_display: TextEdit = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/CritiqueDisplay
@onready var _detail_vbox: VBoxContainer = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer

# Social stats
const _STATS_BASE = "HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/StatsSection"
@onready var _stats_section: VBoxContainer = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/StatsSection
@onready var _stats_hbox: HBoxContainer = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/StatsSection/StatsHBox
@onready var _stats_status_label: Label = $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/StatsSection/StatsStatusLabel
@onready var _platform_labels: Dictionary = {
	"bluesky": $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/StatsSection/StatsHBox/BlueskyLabel,
	"instagram": $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/StatsSection/StatsHBox/InstagramLabel,
	"deviantart": $HBoxContainer/RightPanel/PreviewPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/StatsSection/StatsHBox/DeviantArtLabel,
}
var _stats_http: HTTPRequest = null
var _stats_cache: Dictionary = {}     # painting_id -> stats dict (session cache)
var _stats_fetching_id: String = ""   # painting_id currently being fetched

# Sound (reuse parent PauseMenu sounds)
var button_nav_sound: AudioStreamPlayer = null
var button_hit_sound: AudioStreamPlayer = null

func _ready():
	if Engine.is_editor_hint():
		_populate_editor_preview()
		return

	# Instantiate virtual keyboard for controller users on non-Steam-Deck
	_virtual_keyboard = VirtualKeyboardScene.instantiate() as VirtualKeyboard
	if _virtual_keyboard == null:
		push_error("InventoryTab: Failed to instantiate VirtualKeyboard — check script UID in tscn")
	else:
		add_child(_virtual_keyboard)
		_virtual_keyboard.text_confirmed.connect(_on_virtual_keyboard_confirmed)
		_virtual_keyboard.cancelled.connect(_on_virtual_keyboard_cancelled)

	# Auto-enter text editing when mouse clicks a text field
	name_input.gui_input.connect(_on_text_gui_input.bind(name_input))
	statement_input.gui_input.connect(_on_text_gui_input.bind(statement_input))

	# Auto-save on every keystroke so navigation/close never loses data
	name_input.text_changed.connect(func(_new_text): _save_current_painting())
	statement_input.text_changed.connect(func(): _save_current_painting())


	# Find sounds from parent PauseMenu
	var pause_menu = _find_parent_pause_menu()
	if pause_menu:
		button_nav_sound = pause_menu.get_node_or_null("ButtonNavSound")
		button_hit_sound = pause_menu.get_node_or_null("ButtonHitSound")

	if LocaleManager:
		LocaleManager.locale_changed.connect(_on_locale_changed)

	# Disable input processing by default (PauseMenu manages activation via process_mode)
	process_mode = Node.PROCESS_MODE_DISABLED

	_setup_stats_http()

func _process(delta):
	if not visible:
		return

	if input_cooldown > 0:
		input_cooldown -= delta

func _input(event):
	if not visible:
		return

	# Track whether last input came from a gamepad (for Steam keyboard routing)
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_input_was_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_last_input_was_gamepad = false

	# Only process keyboard/gamepad input when enabled (mouse works via gui_input signals)
	if not keyboard_nav_enabled:
		return

	# Block navigation while virtual keyboard is open; forward event so VK can handle it
	if _virtual_keyboard != null and _virtual_keyboard.visible:
		_virtual_keyboard.handle_nav_input(event)
		get_viewport().set_input_as_handled()
		return

	# Don't process navigation if text is being edited — let keys reach the text field
	if is_editing_text:
		# Exit editing on Escape key or gamepad B button (not keyboard B, which should type 'B')
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_exit_text_editing()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.is_action_pressed("go_back"):
			_exit_text_editing()
			get_viewport().set_input_as_handled()
		# Enter in LineEdit exits editing (submit)
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
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

	# Up - clamp at top; don't consume at boundary so PauseMenu returns to tab bar
	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		if input_cooldown <= 0:
			if selected_index > 0:
				_select_previous_painting()
				input_cooldown = input_cooldown_time
				viewport.set_input_as_handled()
			# At top: don't consume → PauseMenu catches and enters tab bar
		else:
			viewport.set_input_as_handled()
		return

	# Down - clamp at bottom, always consume
	if event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		if input_cooldown <= 0:
			if selected_index < painting_entries.size() - 1:
				_select_next_painting()
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
	if _current_is_shipped:
		_handle_shipped_detail_input(event)
		return

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

func _handle_shipped_detail_input(event):
	"""Handle input for shipped (read-only) paintings.
	Left/right switches between statement (left) and critique (right).
	Up/down scrolls the focused TextEdit if its content overflows."""
	var viewport = get_viewport()
	var has_right_col = _critique_panel != null and _critique_panel.visible

	# Right: switch to critique column
	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		if input_cooldown <= 0 and has_right_col and _detail_col == 0:
			_detail_col = 1
			_update_detail_focus()
			input_cooldown = input_cooldown_time
			if button_nav_sound:
				button_nav_sound.play()
		viewport.set_input_as_handled()
		return

	# Left: switch to statement column, or exit back to painting list
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		if input_cooldown <= 0:
			if _detail_col == 1:
				_detail_col = 0
				_update_detail_focus()
				if button_nav_sound:
					button_nav_sound.play()
			else:
				_exit_detail_mode()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("go_back"):
		_exit_detail_mode()
		viewport.set_input_as_handled()
		return

	# Up/down: scroll the focused TextEdit (only if it actually overflows)
	var focused_te: TextEdit = statement_input if _detail_col == 0 else _critique_display
	if focused_te == null or not _text_overflows(focused_te):
		return

	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		if input_cooldown <= 0:
			focused_te.scroll_vertical += 1
			input_cooldown = input_cooldown_time * 0.5
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		if input_cooldown <= 0:
			focused_te.scroll_vertical -= 1
			input_cooldown = input_cooldown_time * 0.5
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
		if child is PaintingCard and child.card_clicked.is_connected(_on_card_clicked):
			child.card_clicked.disconnect(_on_card_clicked)
		child.queue_free()
	painting_cards.clear()
	painting_entries.clear()

	# Get all paintings
	painting_entries = WorldStateManager.get_all_paintings()
	painting_entries.reverse()

	# Create cards
	for i in range(painting_entries.size()):
		var card = PaintingCardScene.instantiate() as PaintingCard
		painting_list_container.add_child(card)
		card.setup(painting_entries[i], i)
		card.card_clicked.connect(_on_card_clicked)
		painting_cards.append(card)

	# Update stats
	stats_label.text = tr("Paintings: %d") % painting_entries.size()

func _show_detail_panel(should_show: bool):
	"""Show or hide the detail panel content"""
	preview_image.visible = should_show
	if status_label:
		status_label.visible = should_show
	name_input.visible = should_show
	name_input.get_parent().visible = should_show  # NameContainer
	if statement_label:
		statement_label.visible = should_show
	statement_input.visible = should_show

	# Show/hide empty label
	if empty_label:
		empty_label.visible = not should_show

	# Always hide critique panel when hiding the detail; _update_preview handles showing it
	if not should_show and _critique_panel:
		_critique_panel.visible = false

# ============================================================================
# Navigation
# ============================================================================

func _select_next_painting():
	"""Select the next painting in the list (clamped, no wrapping)"""
	if painting_entries.size() == 0:
		return
	_save_current_painting()
	selected_index = mini(selected_index + 1, painting_entries.size() - 1)
	_update_selection()
	if button_nav_sound:
		button_nav_sound.play()

func _select_previous_painting():
	"""Select the previous painting in the list (clamped, no wrapping)"""
	if painting_entries.size() == 0:
		return
	_save_current_painting()
	selected_index = maxi(selected_index - 1, 0)
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
			if image.get_width() <= image.get_height():
				image.rotate_90(CLOCKWISE)
			preview_image.texture = ImageTexture.create_from_image(image)
		else:
			preview_image.texture = null
	else:
		preview_image.texture = null

	# Update status display
	var status = data.get("status", "WIP")
	if status_label:
		status_label.text = tr("Status: %s") % tr(status)
		match status:
			"WIP":
				status_label.modulate = Color(1.0, 0.9, 0.3)
			"DONE":
				status_label.modulate = Color(0.4, 1.0, 0.4)
			"SHIPPED":
				status_label.modulate = Color(0.4, 0.8, 1.0)

	# For SHIPPED paintings, make fields read-only
	var is_shipped = (status == "SHIPPED")
	_current_is_shipped = is_shipped
	_detail_col = 0
	name_input.editable = not is_shipped
	statement_input.editable = not is_shipped

	# Set name and statement fields
	name_input.text = data.get("name", "")
	statement_input.text = data.get("artist_statement", "")

	# Show right column for SHIPPED paintings that have a critique and/or social stats
	var critique = data.get("critique", "")
	var gallery_id = data.get("gallery_id", "")
	if _critique_panel:
		var show_right = is_shipped and (critique != "" or gallery_id != "")
		_critique_panel.visible = show_right
		if _critique_display:
			_critique_display.text = critique
			_critique_display.visible = critique != ""
			# Hide critique header too if no critique
			var critique_header = _critique_panel.get_node_or_null("CritiqueHeader")
			if critique_header:
				critique_header.visible = critique != ""
	if _stats_section:
		if is_shipped and gallery_id != "":
			_stats_section.visible = true
			var painting_id = data.get("id", "")
			if painting_id in _stats_cache:
				_display_stats(_stats_cache[painting_id])
			else:
				_stats_hbox.visible = false
				_stats_status_label.visible = true
				_stats_status_label.text = "Fetching..."
				_fetch_social_stats(painting_id, gallery_id)
		else:
			_stats_section.visible = false

# ============================================================================
# Detail Panel Navigation
# ============================================================================

func _enter_detail_mode():
	"""Enter the detail panel navigation mode"""
	nav_mode = NavMode.DETAIL_PANEL
	detail_focus_index = 0
	_detail_col = 0
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
	new_index = clampi(new_index, 0, 1)  # 0=name, 1=statement
	if new_index != detail_focus_index:
		detail_focus_index = new_index
		_update_detail_focus()
		if button_nav_sound:
			button_nav_sound.play()

func _update_detail_focus():
	"""Update visual highlight on the detail panel item.
	Text fields are NOT given focus during navigation (that would let stray keys type into them).
	Focus is only granted when entering editing mode via _enter_text_editing()."""
	_clear_detail_focus()
	if _current_is_shipped:
		if _detail_col == 0:
			statement_input.modulate = Color(1.2, 1.2, 1.0, 1.0)
		elif _critique_display:
			_critique_display.modulate = Color(1.2, 1.2, 1.0, 1.0)
		return
	match detail_focus_index:
		0:
			name_input.modulate = Color(1.2, 1.2, 1.0, 1.0)
		1:
			statement_input.modulate = Color(1.2, 1.2, 1.0, 1.0)

func _clear_detail_focus():
	"""Clear focus and highlight from all detail panel items"""
	name_input.release_focus()
	name_input.modulate = Color.WHITE
	statement_input.release_focus()
	statement_input.modulate = Color.WHITE
	if _critique_display:
		_critique_display.modulate = Color.WHITE

func _text_overflows(te: TextEdit) -> bool:
	"""Returns true if the TextEdit content is tall enough to require scrolling"""
	var bar = te.get_v_scroll_bar()
	return bar.max_value > bar.page

func _should_use_virtual_keyboard() -> bool:
	"""True when a controller is active and we're NOT on Steam Deck.
	Steam Deck has its own native keyboard via the Steam overlay."""
	if not _last_input_was_gamepad:
		return false
	if SteamManager.is_steam_available and Steam.isSteamRunningOnSteamDeck():
		return false
	return true

func _activate_detail_item():
	"""Activate the currently focused detail item"""
	match detail_focus_index:
		0:
			if _should_use_virtual_keyboard():
				_show_virtual_keyboard(name_input, false)
			else:
				_enter_text_editing(name_input)
				_show_floating_steam_keyboard(name_input, false)
		1:
			if _should_use_virtual_keyboard():
				_show_virtual_keyboard(statement_input, true)
			else:
				_enter_text_editing(statement_input)
				_show_floating_steam_keyboard(statement_input, true)

func _show_floating_steam_keyboard(control: Control, multiline: bool) -> void:
	"""Show the Steam floating keyboard (same as Steam+X) positioned near the text field.
	Keyboard types directly into the focused control — no callback needed."""
	if not SteamManager.is_steam_available:
		return
	if not Steam.isSteamRunningOnSteamDeck():
		return
	var mode := 1 if multiline else 0
	var rect := control.get_global_rect()
	Steam.showFloatingGamepadTextInput(mode, int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y))

func _enter_text_editing(control: Control):
	"""Enter text editing mode for a LineEdit or TextEdit"""
	is_editing_text = true
	control.grab_focus()
	if control is LineEdit:
		control.caret_column = control.text.length()
	elif control is TextEdit:
		control.set_caret_column(control.get_line(control.get_caret_line()).length())

func _exit_text_editing():
	"""Exit text editing mode and release text field focus"""
	is_editing_text = false
	# Release focus from text fields so stray keys don't type into them
	_clear_detail_focus()
	_update_detail_focus()


func _show_virtual_keyboard(control: Control, multiline: bool) -> void:
	"""Show the in-game virtual keyboard for controller users on PC."""
	if _virtual_keyboard == null:
		return
	var initial_text: String = control.text if control is LineEdit else (control as TextEdit).text
	var title: String = tr("Artist Statement") if multiline else tr("Painting Name")
	var max_len: int = 500 if multiline else 50
	_steam_editing_field = control
	_virtual_keyboard.open(initial_text, title, max_len)

func _on_virtual_keyboard_confirmed(text: String) -> void:
	"""Called when the player presses OK on the virtual keyboard."""
	if _steam_editing_field == null:
		return
	if _steam_editing_field is LineEdit:
		(_steam_editing_field as LineEdit).text = text
	elif _steam_editing_field is TextEdit:
		(_steam_editing_field as TextEdit).text = text
	_steam_editing_field = null

func _on_virtual_keyboard_cancelled() -> void:
	"""Called when the player presses B to dismiss without saving."""
	_steam_editing_field = null
	_update_detail_focus()


# ============================================================================
# Actions
# ============================================================================

func _on_text_gui_input(event: InputEvent, control: Control):
	"""Auto-enter text editing when mouse clicks a text field"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_editing_text:
			is_editing_text = true
			keyboard_nav_enabled = true
			nav_mode = NavMode.DETAIL_PANEL
			if control == name_input:
				detail_focus_index = 0
			elif control == statement_input:
				detail_focus_index = 1
			# Notify parent PauseMenu to enter TAB_CONTENT mode
			var pause_menu = _find_parent_pause_menu()
			if pause_menu and pause_menu.nav_mode == PauseMenuUI.NavMode.TAB_BAR:
				pause_menu._enter_tab_content_mode(true)

func _save_current_painting():
	"""Auto-save the current painting's name and artist statement"""
	if selected_index < 0 or selected_index >= painting_entries.size():
		return

	var data = painting_entries[selected_index]
	var painting_node = data.get("node")

	# Can't save shipped paintings (no node, read-only)
	if painting_node == null or not is_instance_valid(painting_node):
		return

	var new_name = name_input.text.strip_edges()
	var new_statement = statement_input.text.strip_edges()
	var new_status = "DONE" if new_name != "" else data.get("status", "WIP")

	WorldStateManager.update_painting_metadata(painting_node, new_name, new_statement, new_status)

	painting_entries[selected_index]["name"] = new_name
	painting_entries[selected_index]["artist_statement"] = new_statement
	painting_entries[selected_index]["status"] = new_status

	if selected_index < painting_cards.size():
		painting_cards[selected_index].update_name(new_name)
		painting_cards[selected_index].update_status(new_status)

	if status_label:
		status_label.text = tr("Status: %s") % tr(new_status)
		match new_status:
			"WIP":
				status_label.modulate = Color(1.0, 0.9, 0.3)
			"DONE":
				status_label.modulate = Color(0.4, 1.0, 0.4)

func _on_card_clicked(index: int):
	"""Handle painting card click"""
	if index != selected_index:
		_save_current_painting()
	selected_index = index
	_update_selection()

	# Notify parent PauseMenu to enter TAB_CONTENT mode (mouse entry)
	var pause_menu = _find_parent_pause_menu()
	if pause_menu and pause_menu.nav_mode == PauseMenuUI.NavMode.TAB_BAR:
		pause_menu._enter_tab_content_mode(true)

# ============================================================================
# Helpers
# ============================================================================

func select_painting_by_node(painting_node: CarryablePainting) -> void:
	"""Select a specific painting in the list by its node reference"""
	for i in range(painting_entries.size()):
		if painting_entries[i].get("node") == painting_node:
			selected_index = i
			_update_selection()
			_show_detail_panel(true)
			return

func _populate_editor_preview():
	"""Populate the painting list with placeholder cards for editor visualization"""
	if not painting_list_container:
		return
	for i in range(3):
		var card = PaintingCardScene.instantiate()
		painting_list_container.add_child(card)
	if stats_label:
		stats_label.text = "Paintings: 3"

func _on_locale_changed(_locale: String) -> void:
	if not visible:
		return
	stats_label.text = tr("Paintings: %d") % painting_entries.size()
	if selected_index >= 0 and selected_index < painting_entries.size():
		var data = painting_entries[selected_index]
		var status = data.get("status", "WIP")
		if status_label:
			status_label.text = tr("Status: %s") % tr(status)


func _setup_stats_http() -> void:
	"""Create the HTTPRequest node used to fetch social stats."""
	_stats_http = HTTPRequest.new()
	_stats_http.name = "StatsHTTPRequest"
	_stats_http.timeout = 10.0
	add_child(_stats_http)
	_stats_http.request_completed.connect(_on_stats_response)

func _fetch_social_stats(painting_id: String, gallery_id: String) -> void:
	"""Request social stats for the given gallery_id."""
	if _stats_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return  # A request is already in flight; the result will be checked against selected painting
	_stats_fetching_id = painting_id
	var url = GalleryUploader.API_BASE_URL + "/stats/" + gallery_id
	var headers = ["X-API-Key: " + GalleryUploader.API_KEY]
	print("[InventoryTab] Fetching stats from: ", url)
	var error = _stats_http.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("[InventoryTab] request() failed, error code: ", error)
		_stats_fetching_id = ""
		_stats_hbox.visible = false
		_stats_status_label.visible = true
		_stats_status_label.text = "Could not load stats"

func _on_stats_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Handle the social stats HTTP response."""
	var fetching_id = _stats_fetching_id
	_stats_fetching_id = ""

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[InventoryTab] Stats response failed — result: ", result, " code: ", response_code, " body: ", body.get_string_from_utf8())
		if selected_index >= 0 and selected_index < painting_entries.size():
			if painting_entries[selected_index].get("id", "") == fetching_id:
				_stats_hbox.visible = false
				_stats_status_label.visible = true
				_stats_status_label.text = "Could not load stats"
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json or not json is Dictionary:
		if selected_index >= 0 and selected_index < painting_entries.size():
			if painting_entries[selected_index].get("id", "") == fetching_id:
				_stats_hbox.visible = false
				_stats_status_label.visible = true
				_stats_status_label.text = "Could not load stats"
		return

	_stats_cache[fetching_id] = json
	# Only update display if this is still the selected painting
	if selected_index >= 0 and selected_index < painting_entries.size():
		if painting_entries[selected_index].get("id", "") == fetching_id:
			_display_stats(json)

func _display_stats(stats: Dictionary) -> void:
	"""Update per-platform labels from the stats dict."""
	if stats.is_empty():
		_stats_hbox.visible = false
		_stats_status_label.visible = true
		_stats_status_label.text = "No stats yet"
		return
	_stats_status_label.visible = false
	_stats_hbox.visible = true
	if "instagram" in stats and int(stats["instagram"]) >= 10:
		if SteamManager:
			SteamManager.unlock_achievement("ACH_INSTAGRAM_10")
			SteamManager.store_steam_data()
	for platform in _platform_labels.keys():
		var label: Label = _platform_labels[platform]
		if platform in stats:
			label.visible = true
			label.text = "%s: %d ♥" % [platform.capitalize(), int(stats[platform])]
		else:
			label.visible = false

func _find_parent_pause_menu() -> Node:
	"""Find the PauseMenu parent node"""
	var node = get_parent()
	while node:
		if node.get_script() and node.get_script().get_global_name() == "PauseMenuUI":
			return node
		node = node.get_parent()
	return null
