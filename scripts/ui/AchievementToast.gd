extends CanvasLayer

var _panel: PanelContainer
var _icon: TextureRect
var _title_label: Label
var _desc_label: Label
var _is_showing: bool = false

const SLIDE_DURATION := 0.5
const DISPLAY_DURATION := 4.0
const PANEL_WIDTH := 300
const PANEL_HEIGHT := 72

func _ready() -> void:
	layer = 90
	_build_ui()
	_panel.visible = false

func show_toast(title: String, description: String, icon: Texture2D = null) -> void:
	if _is_showing:
		return
	_is_showing = true

	_title_label.text = title
	_desc_label.text = description
	_icon.texture = icon
	_icon.visible = icon != null

	_panel.visible = true
	_panel.position.x = get_viewport().get_visible_rect().size.x

	var target_x: float = get_viewport().get_visible_rect().size.x - PANEL_WIDTH - 16

	var tween := create_tween()
	tween.tween_property(_panel, "position:x", target_x, SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(_panel, "position:x", get_viewport().get_visible_rect().size.x + 10, SLIDE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		_panel.visible = false
		_is_showing = false
	)

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.55, 0.35, 0.8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport_h: float = get_viewport().get_visible_rect().size.y
	_panel.position = Vector2(0, viewport_h - PANEL_HEIGHT - 16)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(48, 48)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_icon)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 15)
	_desc_label.add_theme_color_override("font_color", Color.WHITE)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_desc_label)

	hbox.add_child(vbox)
	_panel.add_child(hbox)
	add_child(_panel)
