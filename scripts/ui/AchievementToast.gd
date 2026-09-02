extends CanvasLayer

const UI_THEME: Theme = preload("res://themes/ui_theme.tres")
const STEAM_ICON: Texture2D = preload("res://sprites/steam icon.png")

enum _State { IDLE, SLIDING_IN, HOLDING, SLIDING_OUT }

var _panel: PanelContainer
var _icon: TextureRect
var _steam_badge: TextureRect
var _title_label: Label
var _desc_label: Label
var _state: _State = _State.IDLE
var _current_tween: Tween
var _hold_timer: Timer

const SLIDE_DURATION := 0.5
const DISPLAY_DURATION := 4.0
const EDGE_MARGIN := 16.0

func _ready() -> void:
	layer = 90
	_build_ui()
	_panel.visible = false

	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = DISPLAY_DURATION
	_hold_timer.timeout.connect(_slide_out)
	add_child(_hold_timer)

## Shows a toast. If one is already visible (or mid-exit), the newest call
## always takes precedence immediately: content refreshes in place and the
## display timer resets, rather than queuing behind whatever came before
## (e.g. rapidly cycling boombox tracks would otherwise lag behind reality).
## show_steam_badge adds a small Steam logo next to the title, for toasts
## meant to read as a fake Steam achievement popup (e.g. the Cyclone win).
func show_toast(title: String, description: String, icon: Texture2D = null, show_steam_badge: bool = false) -> void:
	_title_label.text = title
	_desc_label.text = description
	_icon.texture = icon
	_icon.visible = icon != null
	_steam_badge.visible = show_steam_badge
	_panel.reset_size()  # shrink/grow to fit the new content (e.g. short "Song 1" vs a longer sentence)
	# Keep the panel pinned to the bottom-right regardless of how its height
	# changed (e.g. hiding the icon shrinks it vertically too).
	_panel.position.y = get_viewport().get_visible_rect().size.y - _panel.size.y - EDGE_MARGIN

	match _state:
		_State.IDLE:
			_slide_in()
		_State.SLIDING_IN, _State.HOLDING:
			# Already visible — snap the (possibly resized) panel back to its
			# right-aligned resting spot and restart the hold timer.
			_panel.position.x = _resting_x()
			_hold_timer.start()
		_State.SLIDING_OUT:
			_slide_in()  # reverse course back into view with the new content

func _resting_x() -> float:
	return get_viewport().get_visible_rect().size.x - _panel.size.x - EDGE_MARGIN

func _slide_in() -> void:
	# Only jump to the off-screen starting position when coming from a fully
	# hidden state. A SLIDING_OUT reversal should continue smoothly from
	# wherever it currently is, not snap back off-screen first.
	var was_idle := _state == _State.IDLE
	_state = _State.SLIDING_IN
	if _current_tween:
		_current_tween.kill()
	_panel.visible = true

	if was_idle:
		_panel.position.x = get_viewport().get_visible_rect().size.x

	_current_tween = create_tween()
	_current_tween.tween_property(_panel, "position:x", _resting_x(), SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.finished.connect(func():
		_state = _State.HOLDING
		_hold_timer.start()
	)

func _slide_out() -> void:
	_state = _State.SLIDING_OUT
	if _current_tween:
		_current_tween.kill()

	var offscreen_x: float = get_viewport().get_visible_rect().size.x + 10
	_current_tween = create_tween()
	_current_tween.tween_property(_panel, "position:x", offscreen_x, SLIDE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_current_tween.finished.connect(func():
		_panel.visible = false
		_state = _State.IDLE
	)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.theme = UI_THEME  # Uses the game's own PanelContainer style (themes/ui_theme.tres) instead of a bespoke Steam-achievement look
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No custom_minimum_size/size here — the panel shrink-wraps to whatever
	# content show_toast() sets (via _panel.reset_size()), so a short "Song 1"
	# toast is small and a longer sentence still gets the room it needs.

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(56, 56)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_icon)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 5)

	_steam_badge = TextureRect.new()
	_steam_badge.texture = STEAM_ICON
	_steam_badge.custom_minimum_size = Vector2(14, 14)
	_steam_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_steam_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_steam_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steam_badge.visible = false  # only shown when show_toast() is called with show_steam_badge = true
	title_row.add_child(_steam_badge)

	_title_label = Label.new()
	_title_label.add_theme_font_override("font", UI_THEME.default_font)
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_title_label)

	vbox.add_child(title_row)

	_desc_label = Label.new()
	_desc_label.add_theme_font_override("font", UI_THEME.default_font)
	_desc_label.add_theme_font_size_override("font_size", 40)
	_desc_label.add_theme_color_override("font_color", Color.WHITE)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_desc_label)

	hbox.add_child(vbox)
	margin.add_child(hbox)
	_panel.add_child(margin)
	add_child(_panel)

	_panel.reset_size()
	var viewport_h: float = get_viewport().get_visible_rect().size.y
	_panel.position = Vector2(get_viewport().get_visible_rect().size.x, viewport_h - _panel.size.y - EDGE_MARGIN)
