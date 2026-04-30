extends Control
class_name StickerMarketplaceTab

## Sticker Marketplace pause menu tab.
## Browse sub-tab: fetch + buy stickers from other players.
## Sell sub-tab: list your custom stickers for sale.

const LISTING_CARD_SCENE = preload("res://scenes/UI/StickerListingCard.tscn")
const STICKER_SELECT_CARD_SCENE = preload("res://scenes/UI/StickerSelectCard.tscn")

enum SubTab { BROWSE, SELL }
enum NavMode { SUB_TAB_BAR, LISTING_LIST, PRICE_INPUT, ACTION_BUTTON }

@onready var browse_button: Button = $HBoxContainer/LeftPanel/SubTabBar/BrowseButton
@onready var sell_button: Button = $HBoxContainer/LeftPanel/SubTabBar/SellButton

@onready var browse_container: Control = $HBoxContainer/LeftPanel/BrowseContainer
@onready var browse_status_label: Label = $HBoxContainer/LeftPanel/BrowseContainer/StatusLabel
@onready var listing_list: VBoxContainer = $HBoxContainer/LeftPanel/BrowseContainer/ScrollContainer/ListMargin/ListingList

@onready var sell_container: Control = $HBoxContainer/LeftPanel/SellContainer
@onready var sell_status_label: Label = $HBoxContainer/LeftPanel/SellContainer/StatusLabel
@onready var sticker_grid: GridContainer = $HBoxContainer/LeftPanel/SellContainer/ScrollContainer/ListMargin/StickerGrid

@onready var preview_image: TextureRect = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/PreviewImage
@onready var item_name_label: Label = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/ItemNameLabel
@onready var price_text_label: Label = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/PriceRow/PriceTextLabel
@onready var display_price_label: Label = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/PriceRow/DisplayPriceLabel
@onready var price_input: LineEdit = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/PriceRow/PriceInput
@onready var seller_label: Label = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/SellerLabel
@onready var action_button: Button = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/ActionButton
@onready var feedback_label: Label = $HBoxContainer/RightPanel/DetailPanel/MarginContainer/VBoxContainer/FeedbackLabel

var current_sub_tab: SubTab = SubTab.BROWSE
var nav_mode: NavMode = NavMode.SUB_TAB_BAR
var keyboard_nav_enabled: bool = false
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15

var _listings: Array = []
var _selected_listing_index: int = -1
var _listing_cards: Array = []

var _custom_stickers: Array[PaintingLayerDefinition] = []
var _selected_sticker_index: int = -1
var _sticker_cards: Array = []

var button_nav_sound: AudioStreamPlayer = null
var button_hit_sound: AudioStreamPlayer = null

var _preview_request: HTTPRequest = null
var _preview_cache: Dictionary = {}   # url -> ImageTexture
var _preview_pending_url: String = ""
var _preview_queue: Array[String] = []  # urls waiting to download


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

	_preview_request = HTTPRequest.new()
	_preview_request.timeout = 15.0
	add_child(_preview_request)
	_preview_request.request_completed.connect(_on_preview_downloaded)

	browse_button.pressed.connect(func(): _switch_sub_tab(SubTab.BROWSE))
	sell_button.pressed.connect(func(): _switch_sub_tab(SubTab.SELL))
	action_button.pressed.connect(_on_action_pressed)
	action_button.focus_mode = Control.FOCUS_ALL

	price_input.text = "100"
	price_input.focus_mode = Control.FOCUS_ALL
	price_input.text_changed.connect(_on_price_input_changed)

	StickerMarketplaceManager.marketplace_loaded.connect(_on_marketplace_loaded)
	StickerMarketplaceManager.listing_step.connect(_on_listing_step)
	StickerMarketplaceManager.purchase_complete.connect(_on_purchase_complete)
	StickerMarketplaceManager.purchase_failed.connect(_on_purchase_failed)
	StickerMarketplaceManager.listing_complete.connect(_on_listing_complete)
	StickerMarketplaceManager.listing_failed.connect(_on_listing_failed)
	StickerMarketplaceManager.credits_received.connect(_on_credits_received)

	var pause_menu = _find_parent_pause_menu()
	if pause_menu:
		button_nav_sound = pause_menu.get_node_or_null("ButtonNavSound")
		button_hit_sound = pause_menu.get_node_or_null("ButtonHitSound")


func _process(delta: float) -> void:
	if not visible:
		return
	if input_cooldown > 0:
		input_cooldown -= delta


func _input(event: InputEvent) -> void:
	if not visible or not keyboard_nav_enabled:
		return

	var viewport = get_viewport()

	if nav_mode == NavMode.SUB_TAB_BAR:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
			_switch_sub_tab(SubTab.BROWSE)
			viewport.set_input_as_handled()
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
			_switch_sub_tab(SubTab.SELL)
			viewport.set_input_as_handled()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back") \
				or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			if input_cooldown <= 0:
				nav_mode = NavMode.LISTING_LIST
				input_cooldown = input_cooldown_time
				_focus_first_item()
			viewport.set_input_as_handled()

	elif nav_mode == NavMode.LISTING_LIST:
		if current_sub_tab == SubTab.BROWSE:
			_handle_browse_list_input(event, viewport)
		else:
			_handle_sell_grid_input(event, viewport)

	elif nav_mode == NavMode.PRICE_INPUT:
		_handle_price_input_nav(event, viewport)

	elif nav_mode == NavMode.ACTION_BUTTON:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward") \
				or event.is_action_pressed("ui_left") or event.is_action_pressed("move_left") \
				or event.is_action_pressed("go_back"):
			action_button.release_focus()
			_apply_hover_style(action_button, false)
			if current_sub_tab == SubTab.SELL:
				nav_mode = NavMode.PRICE_INPUT
				_set_price_input_highlight(true)
			else:
				nav_mode = NavMode.LISTING_LIST
			viewport.set_input_as_handled()
		elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			_on_action_pressed()
			viewport.set_input_as_handled()


func _handle_browse_list_input(event: InputEvent, viewport: Viewport) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		if _selected_listing_index <= 0:
			nav_mode = NavMode.SUB_TAB_BAR
			viewport.set_input_as_handled()
			return
		if input_cooldown <= 0:
			_select_listing(_selected_listing_index - 1)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()

	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		if input_cooldown <= 0:
			_select_listing(mini(_selected_listing_index + 1, _listing_cards.size() - 1))
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()

	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		if input_cooldown <= 0 and _selected_listing_index >= 0:
			nav_mode = NavMode.ACTION_BUTTON
			action_button.grab_focus()
			_apply_hover_style(action_button, true)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()

	elif event.is_action_pressed("go_back"):
		nav_mode = NavMode.SUB_TAB_BAR
		viewport.set_input_as_handled()


func _handle_sell_grid_input(event: InputEvent, viewport: Viewport) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		if _selected_sticker_index < 4:
			nav_mode = NavMode.SUB_TAB_BAR
			viewport.set_input_as_handled()
			return
		if input_cooldown <= 0:
			_select_sticker(_selected_sticker_index - 4)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()

	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		if input_cooldown <= 0:
			_select_sticker(mini(_selected_sticker_index + 4, _sticker_cards.size() - 1))
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()

	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		if input_cooldown <= 0 and _selected_sticker_index > 0:
			_select_sticker(_selected_sticker_index - 1)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()

	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		if input_cooldown <= 0 and _selected_sticker_index >= 0:
			var at_last = _selected_sticker_index == _sticker_cards.size() - 1
			var at_row_end = _selected_sticker_index % 4 == 3
			if at_last or at_row_end:
				nav_mode = NavMode.PRICE_INPUT
				_set_price_input_highlight(true)
			else:
				_select_sticker(_selected_sticker_index + 1)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()

	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if input_cooldown <= 0 and _selected_sticker_index >= 0:
			nav_mode = NavMode.PRICE_INPUT
			_set_price_input_highlight(true)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()

	elif event.is_action_pressed("go_back"):
		nav_mode = NavMode.SUB_TAB_BAR
		viewport.set_input_as_handled()


func _handle_price_input_nav(event: InputEvent, viewport: Viewport) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left") \
			or event.is_action_pressed("go_back"):
		_set_price_input_highlight(false)
		nav_mode = NavMode.LISTING_LIST
		viewport.set_input_as_handled()
	elif event.is_action_pressed("cycle_prev"):
		if input_cooldown <= 0:
			price_input.text = str(maxi(1, int(price_input.text) - 50))
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
	elif event.is_action_pressed("cycle_next"):
		if input_cooldown <= 0:
			price_input.text = str(int(price_input.text) + 50)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_set_price_input_highlight(false)
		nav_mode = NavMode.LISTING_LIST
		viewport.set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right") \
			or event.is_action_pressed("ui_down") or event.is_action_pressed("move_back") \
			or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if input_cooldown <= 0:
			_set_price_input_highlight(false)
			nav_mode = NavMode.ACTION_BUTTON
			action_button.grab_focus()
			_apply_hover_style(action_button, true)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()


func _on_price_input_changed(new_text: String) -> void:
	var digits := ""
	for ch in new_text:
		if ch >= "0" and ch <= "9":
			digits += ch
	digits = digits.lstrip("0")
	if not digits.is_empty() and digits.to_int() > 99999:
		digits = "99999"
	if digits != new_text:
		price_input.text = digits
		price_input.caret_column = digits.length()


func _set_price_input_highlight(on: bool) -> void:
	price_input.modulate = Color(1.3, 1.3, 0.5, 1.0) if on else Color(1, 1, 1, 1)


func _apply_hover_style(button: Button, on: bool) -> void:
	if on:
		button.add_theme_stylebox_override("normal", button.get_theme_stylebox("hover", "Button"))
	else:
		button.remove_theme_stylebox_override("normal")


# ============================================================================
# Activation contract (called by PauseMenu)
# ============================================================================

func activate() -> void:
	nav_mode = NavMode.SUB_TAB_BAR
	input_cooldown = 0.0
	action_button.release_focus()
	_apply_hover_style(action_button, false)
	_set_price_input_highlight(false)
	_switch_sub_tab(SubTab.BROWSE)
	StickerMarketplaceManager.fetch_pending_credits()
	StickerMarketplaceManager.fetch_marketplace()
	_set_browse_status("Loading marketplace...")
	_clear_right_panel()


# ============================================================================
# Sub-tab switching
# ============================================================================

func _switch_sub_tab(tab: SubTab) -> void:
	current_sub_tab = tab
	browse_container.visible = (tab == SubTab.BROWSE)
	sell_container.visible = (tab == SubTab.SELL)
	browse_button.modulate = Color(1, 1, 1, 1) if tab == SubTab.BROWSE else Color(0.6, 0.6, 0.6, 1)
	sell_button.modulate = Color(1, 1, 1, 1) if tab == SubTab.SELL else Color(0.6, 0.6, 0.6, 1)
	_apply_hover_style(browse_button, tab == SubTab.BROWSE)
	_apply_hover_style(sell_button, tab == SubTab.SELL)

	if tab == SubTab.SELL:
		StickerLibrary.reload()
		_populate_sticker_grid()
	else:
		_set_browse_status("Loading marketplace...")
		_clear_right_panel()
		StickerMarketplaceManager.fetch_marketplace()
	if button_nav_sound:
		button_nav_sound.play()


# ============================================================================
# Browse panel
# ============================================================================

func _on_marketplace_loaded(listings: Array) -> void:
	_listings = listings
	_listing_cards.clear()
	_preview_cache.clear()
	_preview_pending_url = ""
	_preview_queue.clear()
	_preview_request.cancel_request()

	for child in listing_list.get_children():
		child.queue_free()

	if listings.is_empty():
		_set_browse_status("No stickers for sale yet.\nBe the first to list one!")
		return

	_set_browse_status("")

	for i in range(listings.size()):
		var listing = listings[i]
		var card = LISTING_CARD_SCENE.instantiate()
		listing_list.add_child(card)
		card.setup(listing.get("name", "Sticker"), listing.get("price", 0), listing.get("seller_id", ""))
		var url = listing.get("png_url", "")
		if not url.is_empty() and _preview_cache.has(url):
			card.set_preview(_preview_cache[url])
		elif not url.is_empty():
			_load_preview(url)
		var idx = i
		card.pressed.connect(func(): _select_listing(idx))
		_listing_cards.append(card)

	if _listing_cards.size() > 0:
		_select_listing(0)


func _select_listing(index: int) -> void:
	_selected_listing_index = index

	for i in range(_listing_cards.size()):
		_listing_cards[i].modulate = Color(1, 1, 1, 1) if i == index else Color(0.7, 0.7, 0.7, 1)
		_apply_hover_style(_listing_cards[i], i == index)

	if index < 0 or index >= _listings.size():
		_clear_right_panel()
		return

	var listing = _listings[index]
	var price = int(listing.get("price", 0))
	var sticker_name = listing.get("name", "Sticker")
	var seller_id = listing.get("seller_id", "???")
	var png_url = listing.get("png_url", "")

	item_name_label.text = sticker_name
	display_price_label.text = "$%d" % price
	price_text_label.visible = true
	display_price_label.visible = true
	price_input.visible = false
	seller_label.text = "by %s" % seller_id.substr(0, 8)
	seller_label.visible = true

	_load_preview(png_url)

	var own_listing = seller_id == WorldStateManager.get_player_id()
	if own_listing:
		action_button.text = "YOUR LISTING"
		action_button.disabled = true
		action_button.modulate = Color(0.5, 0.5, 0.5, 1)
		feedback_label.text = "You can't buy your own sticker."
		feedback_label.modulate = Color(0.7, 0.7, 0.7, 1)
	else:
		action_button.text = "BUY  $%d" % price
		action_button.disabled = not EconomyManager.can_afford(price)
		action_button.modulate = Color(1, 1, 1, 1) if EconomyManager.can_afford(price) else Color(0.5, 0.5, 0.5, 1)
		feedback_label.text = ""

	if button_nav_sound:
		button_nav_sound.play()


func _load_preview(url: String) -> void:
	if url.is_empty():
		return
	if _preview_cache.has(url):
		return
	if _preview_pending_url == url or url in _preview_queue:
		return
	if _preview_pending_url.is_empty():
		_preview_pending_url = url
		_preview_request.request(url)
	else:
		_preview_queue.append(url)


func _on_preview_downloaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var url = _preview_pending_url
	_preview_pending_url = ""

	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var image = Image.new()
		if image.load_png_from_buffer(body) == OK:
			var texture = ImageTexture.create_from_image(image)
			_preview_cache[url] = texture
			for i in range(_listings.size()):
				if _listings[i].get("png_url", "") == url and i < _listing_cards.size():
					_listing_cards[i].set_preview(texture)
			if _selected_listing_index >= 0 and _selected_listing_index < _listings.size():
				if _listings[_selected_listing_index].get("png_url", "") == url:
					preview_image.texture = texture

	# Drain the queue — start the next download
	while not _preview_queue.is_empty():
		var next_url = _preview_queue.pop_front()
		if not _preview_cache.has(next_url):
			_preview_pending_url = next_url
			_preview_request.request(next_url)
			break


func _set_browse_status(text: String) -> void:
	browse_status_label.text = text
	browse_status_label.visible = not text.is_empty()


# ============================================================================
# Sell panel
# ============================================================================

func _populate_sticker_grid() -> void:
	_sticker_cards.clear()
	for child in sticker_grid.get_children():
		child.queue_free()

	_custom_stickers = StickerLibrary.get_custom_stickers_for_marketplace()

	if _custom_stickers.is_empty():
		sell_status_label.text = "No custom stickers to sell.\nAdd PNGs to your custom stickers folder first."
		sell_status_label.visible = true
		_clear_right_panel()
		return

	sell_status_label.visible = false

	for i in range(_custom_stickers.size()):
		var sticker = _custom_stickers[i]
		var card = STICKER_SELECT_CARD_SCENE.instantiate()
		sticker_grid.add_child(card)
		card.setup(sticker.texture, sticker.id.replace("custom_", ""))
		var idx = i
		card.pressed.connect(func(): _select_sticker(idx))
		_sticker_cards.append(card)

	if _sticker_cards.size() > 0:
		_select_sticker(0)


func _select_sticker(index: int) -> void:
	_selected_sticker_index = index

	for i in range(_sticker_cards.size()):
		_sticker_cards[i].set_selected(i == index)
		_apply_hover_style(_sticker_cards[i], i == index)

	if index < 0 or index >= _custom_stickers.size():
		_clear_right_panel()
		return

	var sticker = _custom_stickers[index]
	preview_image.texture = sticker.texture
	item_name_label.text = sticker.id.replace("custom_", "")
	price_text_label.visible = true
	display_price_label.visible = false
	price_input.visible = true
	seller_label.visible = false

	if StickerMarketplaceManager.is_listing:
		action_button.text = "Listing..."
		action_button.disabled = true
		action_button.modulate = Color(0.7, 0.7, 0.7, 1)
		feedback_label.text = "Upload in progress..."
		feedback_label.modulate = Color(0.7, 0.9, 1.0, 1)
	else:
		action_button.text = "LIST FOR SALE"
		action_button.disabled = false
		action_button.modulate = Color(1, 1, 1, 1)
		feedback_label.text = ""

	if button_nav_sound:
		button_nav_sound.play()


# ============================================================================
# Action button handler
# ============================================================================

func _on_action_pressed() -> void:
	if button_hit_sound:
		button_hit_sound.play()

	if current_sub_tab == SubTab.BROWSE:
		_execute_buy()
	else:
		_execute_list()


func _execute_buy() -> void:
	if _selected_listing_index < 0 or _selected_listing_index >= _listings.size():
		return

	var listing = _listings[_selected_listing_index]
	var price = int(listing.get("price", 0))

	if listing.get("seller_id", "") == WorldStateManager.get_player_id():
		return

	if not EconomyManager.can_afford(price):
		feedback_label.text = "Not enough money!"
		feedback_label.modulate = Color(1, 0.3, 0.3, 1)
		return

	action_button.disabled = true
	action_button.text = "Buying..."
	feedback_label.text = ""

	StickerMarketplaceManager.buy_sticker(
		listing.get("id", ""),
		price,
		listing.get("png_url", ""),
		listing.get("name", "sticker")
	)


func _execute_list() -> void:
	if StickerMarketplaceManager.is_listing:
		feedback_label.text = "Upload in progress, please wait..."
		feedback_label.modulate = Color(0.7, 0.9, 1.0, 1)
		return

	if _selected_sticker_index < 0 or _selected_sticker_index >= _custom_stickers.size():
		return

	var price_text = price_input.text.strip_edges()
	var price = price_text.to_int()
	if price <= 0:
		feedback_label.text = "Enter a price above $0"
		feedback_label.modulate = Color(1, 0.5, 0.2, 1)
		return

	var sticker = _custom_stickers[_selected_sticker_index]
	# sticker.id is like "custom_my_sticker" — filename is "my_sticker.png"
	var base_name = sticker.id.replace("custom_", "")
	if base_name in WorldStateManager.get_listed_sticker_ids():
		feedback_label.text = "Already listed for sale!"
		feedback_label.modulate = Color(1, 0.5, 0.2, 1)
		return
	var filename = base_name + ".png"
	var path = StickerLibrary.CUSTOM_STICKERS_FOLDER + filename
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		# try absolute
		var abs_path = ProjectSettings.globalize_path(path)
		file = FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		feedback_label.text = "Could not read sticker file"
		feedback_label.modulate = Color(1, 0.3, 0.3, 1)
		return

	var png_bytes = file.get_buffer(file.get_length())
	file.close()

	action_button.disabled = true
	action_button.text = "Listing..."
	feedback_label.text = ""

	StickerMarketplaceManager.list_sticker(filename, price, png_bytes)


# ============================================================================
# Manager signal handlers
# ============================================================================

func _on_purchase_complete(sticker_name: String) -> void:
	feedback_label.text = "Bought \"%s\"! Check your sticker carousel." % sticker_name
	feedback_label.modulate = Color(0.4, 1, 0.4, 1)
	action_button.text = "BOUGHT!"
	# Refresh the listing
	StickerMarketplaceManager.fetch_marketplace()


func _on_purchase_failed(error: String) -> void:
	feedback_label.text = "Purchase failed: " + error
	feedback_label.modulate = Color(1, 0.3, 0.3, 1)
	if _selected_listing_index >= 0 and _selected_listing_index < _listings.size():
		var listing = _listings[_selected_listing_index]
		var price = int(listing.get("price", 0))
		action_button.text = "BUY  $%d" % price
		action_button.disabled = not EconomyManager.can_afford(price)


func _on_listing_step(message: String) -> void:
	if current_sub_tab == SubTab.SELL:
		feedback_label.text = message
		feedback_label.modulate = Color(0.7, 0.9, 1.0, 1)


func _on_listing_complete(_listing_id: String) -> void:
	feedback_label.text = "Listed! It will appear in the marketplace."
	feedback_label.modulate = Color(0.4, 1, 0.4, 1)
	action_button.text = "LISTED!"
	action_button.release_focus()
	_apply_hover_style(action_button, false)
	nav_mode = NavMode.LISTING_LIST
	_set_price_input_highlight(false)
	_populate_sticker_grid()
	_clear_right_panel()


func _on_listing_failed(error: String) -> void:
	feedback_label.text = "Listing failed: " + error
	feedback_label.modulate = Color(1, 0.3, 0.3, 1)
	action_button.text = "LIST FOR SALE"
	action_button.disabled = false
	action_button.modulate = Color(1, 1, 1, 1)
	action_button.release_focus()
	_apply_hover_style(action_button, false)
	nav_mode = NavMode.PRICE_INPUT
	_set_price_input_highlight(true)


func _on_credits_received(amount: int) -> void:
	feedback_label.text = "$%d from sticker sales deposited!" % amount
	feedback_label.modulate = Color(1, 0.9, 0.3, 1)


# ============================================================================
# Helpers
# ============================================================================

func _clear_right_panel() -> void:
	preview_image.texture = null
	item_name_label.text = "Select a sticker"
	price_text_label.visible = false
	display_price_label.visible = false
	price_input.visible = false
	seller_label.visible = false
	action_button.text = "..."
	action_button.disabled = true
	feedback_label.text = ""


func _focus_first_item() -> void:
	if current_sub_tab == SubTab.BROWSE and _listing_cards.size() > 0:
		_select_listing(0)
	elif current_sub_tab == SubTab.SELL and _sticker_cards.size() > 0:
		_select_sticker(0)


func _find_parent_pause_menu() -> Node:
	var p = get_parent()
	while p:
		if p is PauseMenuUI:
			return p
		p = p.get_parent()
	return null
