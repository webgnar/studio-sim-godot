extends Control
class_name ShopTab

## Shop tab content for purchasing studio props.
## Left panel: scrollable list of purchasable items.
## Right panel: item name, description, price, and BUY button.
## Follows the same input/activation contract as InventoryTab and MissionSelectionUI.

@onready var item_list_container: VBoxContainer = $HBoxContainer/LeftPanel/ScrollContainer/ItemList
@onready var scroll_container: ScrollContainer = $HBoxContainer/LeftPanel/ScrollContainer
@onready var item_name_label: Label = $HBoxContainer/RightPanel/ItemName
@onready var item_desc_label: Label = $HBoxContainer/RightPanel/ItemDescription
@onready var item_price_label: Label = $HBoxContainer/RightPanel/ItemPrice
@onready var buy_button: Button = $HBoxContainer/RightPanel/BuyButton
@onready var status_label: Label = $HBoxContainer/RightPanel/StatusLabel

enum NavMode { ITEM_LIST, BUY_BUTTON }
var nav_mode: NavMode = NavMode.ITEM_LIST
var selected_index: int = 0
var item_cards: Array[Button] = []
var keyboard_nav_enabled: bool = false
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15

# Sound (reuse parent PauseMenu sounds)
var button_nav_sound: AudioStreamPlayer = null
var button_hit_sound: AudioStreamPlayer = null


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)
	buy_button.focus_mode = Control.FOCUS_ALL

	var pause_menu = _find_parent_pause_menu()
	if pause_menu:
		button_nav_sound = pause_menu.get_node_or_null("ButtonNavSound")
		button_hit_sound = pause_menu.get_node_or_null("ButtonHitSound")

	# PauseMenu enables us via process_mode
	process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	if not visible:
		return
	if input_cooldown > 0:
		input_cooldown -= delta


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not keyboard_nav_enabled:
		return

	if nav_mode == NavMode.ITEM_LIST:
		_handle_item_list_input(event)
	elif nav_mode == NavMode.BUY_BUTTON:
		_handle_buy_button_input(event)


# ============================================================================
# Activation contract (called by PauseMenu)
# ============================================================================

func activate() -> void:
	"""Called when this tab becomes the active tab."""
	_populate_item_list()
	nav_mode = NavMode.ITEM_LIST
	input_cooldown = 0.0
	if item_cards.size() > 0:
		selected_index = 0
		_update_selection()


# ============================================================================
# Input handlers
# ============================================================================

func _handle_item_list_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	var catalog := ShopManager.get_catalog()

	# Up: clamp at top; don't consume at boundary so PauseMenu returns to tab bar
	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		if input_cooldown <= 0:
			if selected_index > 0:
				selected_index -= 1
				_update_selection()
				_play_nav_sound()
				input_cooldown = input_cooldown_time
				viewport.set_input_as_handled()
			# At top: don't consume — PauseMenu catches and goes to tab bar
		else:
			viewport.set_input_as_handled()
		return

	# Down: clamp at bottom, always consume
	if event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		if input_cooldown <= 0:
			if selected_index < catalog.size() - 1:
				selected_index += 1
				_update_selection()
				_play_nav_sound()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# Right / Accept: move to buy button
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_right") or \
			event.is_action_pressed("move_right") or event.is_action_pressed("ui_accept"):
		if input_cooldown <= 0 and catalog.size() > 0:
			_enter_buy_mode()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# go_back not consumed here — PauseMenu handles tab bar return


func _handle_buy_button_input(event: InputEvent) -> void:
	var viewport := get_viewport()

	# Accept / A button: purchase
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if input_cooldown <= 0:
			_on_buy_pressed()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# Left / B / go_back: return to item list
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left") or \
			event.is_action_pressed("go_back"):
		if input_cooldown <= 0:
			_exit_buy_mode()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return


# ============================================================================
# UI population
# ============================================================================

func _populate_item_list() -> void:
	"""Build item cards from ShopManager catalog."""
	for child in item_list_container.get_children():
		child.queue_free()
	item_cards.clear()

	var catalog := ShopManager.get_catalog()
	for i in range(catalog.size()):
		var item = catalog[i]
		var card := Button.new()
		card.text = item["display_name"]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(0, 40)
		# Connect mouse click to select this card
		var idx := i
		card.pressed.connect(func(): _on_card_mouse_pressed(idx))
		item_list_container.add_child(card)
		item_cards.append(card)

	if item_cards.size() > 0:
		_update_selection()


func _update_selection() -> void:
	"""Highlight the selected card and update the right panel."""
	var catalog := ShopManager.get_catalog()
	if catalog.is_empty() or item_cards.is_empty():
		return

	selected_index = clampi(selected_index, 0, item_cards.size() - 1)

	for i in range(item_cards.size()):
		item_cards[i].modulate = Color(1.0, 1.0, 1.0, 1.0) if i == selected_index \
				else Color(0.6, 0.6, 0.6, 1.0)

	var item = catalog[selected_index]
	item_name_label.text = item["display_name"]
	item_desc_label.text = item["description"]

	var purchased := ShopManager.is_purchased(item["id"])
	if purchased:
		item_price_label.text = "Owned"
		buy_button.disabled = true
		buy_button.text = "OWNED"
		status_label.visible = false
	else:
		item_price_label.text = "$%d" % item["price"]
		var can_afford := EconomyManager.can_afford(item["price"])
		buy_button.disabled = not can_afford
		buy_button.text = "BUY"
		if not can_afford:
			status_label.text = "Not enough money"
			status_label.visible = true
		else:
			status_label.visible = false

	# Scroll the list to keep selected card visible
	_scroll_to_selected()


func _scroll_to_selected() -> void:
	if item_cards.is_empty() or selected_index >= item_cards.size():
		return
	var card := item_cards[selected_index]
	# Wait one frame for layout to settle before scrolling
	await get_tree().process_frame
	if not is_instance_valid(card) or not is_instance_valid(scroll_container):
		return
	var card_pos := card.position.y
	var card_height := card.size.y
	var scroll_pos := scroll_container.scroll_vertical
	var visible_height := scroll_container.size.y
	if card_pos < scroll_pos:
		scroll_container.scroll_vertical = int(card_pos)
	elif card_pos + card_height > scroll_pos + visible_height:
		scroll_container.scroll_vertical = int(card_pos + card_height - visible_height)


# ============================================================================
# Buy mode
# ============================================================================

func _enter_buy_mode() -> void:
	nav_mode = NavMode.BUY_BUTTON
	buy_button.grab_focus()
	_play_hit_sound()


func _exit_buy_mode() -> void:
	nav_mode = NavMode.ITEM_LIST
	buy_button.release_focus()
	_play_nav_sound()


func _on_buy_pressed() -> void:
	var catalog := ShopManager.get_catalog()
	if selected_index < 0 or selected_index >= catalog.size():
		return
	var item = catalog[selected_index]
	if ShopManager.purchase(item["id"]):
		_play_hit_sound()
		_update_selection()  # Refresh to show "Owned" state
		# Return to item list after purchase
		_exit_buy_mode()
	else:
		# Flash the status label briefly on failure
		status_label.text = "Can't afford this item"
		status_label.visible = true


func _on_card_mouse_pressed(idx: int) -> void:
	"""Handle mouse click on an item card."""
	selected_index = idx
	_update_selection()
	_enter_buy_mode()


# ============================================================================
# Sound helpers
# ============================================================================

func _play_nav_sound() -> void:
	if button_nav_sound:
		button_nav_sound.play()


func _play_hit_sound() -> void:
	if button_hit_sound:
		button_hit_sound.play()


# ============================================================================
# Parent finding
# ============================================================================

func _find_parent_pause_menu() -> Node:
	var node := get_parent()
	while node:
		if node.get_script() and node.get_script().get_global_name() == "PauseMenuUI":
			return node
		node = node.get_parent()
	return null
