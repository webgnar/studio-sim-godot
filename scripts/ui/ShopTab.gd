extends Control
class_name ShopTab

## Shop tab content for purchasing studio props.
## Left panel: scrollable list of purchasable items (scene-instanced ShopItemCard).
## Right panel: item name, image + description side by side, price, and BUY button.
## Follows the same input/activation contract as InventoryTab and MissionSelectionUI.

const ITEM_CARD_SCENE = preload("res://scenes/UI/ShopItemCard.tscn")
## Drop hand-drawn PNGs here named after the catalog item id, e.g. nail_gun.png
const PREVIEW_IMAGE_DIR = "res://sprites/shop_previews/%s.png"
const DESC_SCROLL_STEP := 60.0
const PREVIEW_PLACEHOLDER = preload("res://sprites/shop_previews/nail_gun.png")

@onready var item_list_container: VBoxContainer = $HBoxContainer/LeftPanel/ScrollContainer/ListMargin/ItemList
@onready var scroll_container: ScrollContainer = $HBoxContainer/LeftPanel/ScrollContainer
@onready var item_name_label: Label = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/ItemName
@onready var item_image: TextureRect = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/MediaRow/ItemImage
@onready var desc_scroll: ScrollContainer = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/MediaRow/DescriptionScroll
@onready var item_desc_label: Label = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/MediaRow/DescriptionScroll/ItemDescription
@onready var item_price_label: Label = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/ItemPrice
@onready var buy_button: Button = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/BuyButton
@onready var status_label: Label = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/StatusLabel

enum NavMode { ITEM_LIST, BUY_BUTTON }
var nav_mode: NavMode = NavMode.ITEM_LIST
var selected_index: int = 0
var item_cards: Array[ShopItemCard] = []
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

	# Bumpers scroll the description text
	if event.is_action_pressed("cycle_prev"):
		desc_scroll.scroll_vertical = max(0, desc_scroll.scroll_vertical - int(DESC_SCROLL_STEP))
		viewport.set_input_as_handled()
		return
	if event.is_action_pressed("cycle_next"):
		desc_scroll.scroll_vertical += int(DESC_SCROLL_STEP)
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
		var card: ShopItemCard = ITEM_CARD_SCENE.instantiate()
		card.setup(item["display_name"])
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
	item_name_label.text = item.get("title", item["display_name"])
	item_desc_label.text = item["description"]
	desc_scroll.scroll_vertical = 0

	var path := PREVIEW_IMAGE_DIR % item["id"]
	item_image.texture = load(path) if ResourceLoader.exists(path) else PREVIEW_PLACEHOLDER

	item_price_label.text = "$%d" % item["price"]
	var purchased := ShopManager.is_purchased(item["id"])
	if purchased:
		buy_button.visible = true
		buy_button.disabled = true
		buy_button.text = "OWNED"
		status_label.visible = false
	else:
		var can_afford := EconomyManager.can_afford(item["price"])
		if can_afford:
			buy_button.visible = true
			buy_button.disabled = false
			buy_button.text = "BUY"
			status_label.visible = false
		else:
			buy_button.visible = false
			status_label.text = "Not enough money"
			status_label.visible = true

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
	if ShopManager.is_player_blocking_spawn(item["id"]):
		status_label.text = "Move out of the item's spawn zone first"
		status_label.visible = true
		return
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
