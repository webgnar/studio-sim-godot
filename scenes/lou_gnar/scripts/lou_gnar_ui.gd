class_name LouGnarUI
extends RefCounted
## Small helpers for building the game's Labels / panels.

const LIME := Color("#00FF00")


static func make_label(text: String, font_size: int, color: Color, outline: int = 0, outline_color: Color = Color.BLACK) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", LouGnarAssets.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_outline_color", outline_color)
	return label


## Set text and position so `anchor_pos` is the label's centre.
static func set_text_centered(label: Label, text: String, anchor_pos: Vector2) -> void:
	label.text = text
	label.reset_size()
	label.position = anchor_pos - label.size / 2.0


## Set text and position so `anchor_pos` is the label's right edge (top aligned).
static func set_text_right(label: Label, text: String, anchor_pos: Vector2) -> void:
	label.text = text
	label.reset_size()
	label.position = anchor_pos - Vector2(label.size.x, 0)


## Black box with a lime border (or inverted when `highlighted`), centred on `center`.
static func make_box(center: Vector2, size: Vector2, highlighted: bool = false) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = size
	panel.position = center - size / 2.0
	style_box(panel, highlighted)
	return panel


static func style_box(panel: Panel, highlighted: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = LIME if highlighted else Color.BLACK
	style.border_color = Color.BLACK if highlighted else LIME
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)
