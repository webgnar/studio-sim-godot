class_name ExSkateTitleScreen
extends CanvasLayer
## Title card with a pulsing PLAY button (any jump input starts the game).

var _button: Panel
var _button_text: Label
var _pulse: float = 0.0
var _lit: bool = false


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)

	var background := TextureRect.new()
	background.texture = ExSkateAssets.TITLE_IMAGE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	# Black text with a lime outline.
	var title := ExSkateUI.make_label("Lou    Gnar", 96, Color.BLACK, 8, ExSkateUI.LIME)
	root.add_child(title)
	ExSkateUI.set_text_centered(title, title.text, Vector2(445, 180))

	_button = ExSkateUI.make_box(Vector2(650, 550), Vector2(200, 60))
	root.add_child(_button)
	_button_text = ExSkateUI.make_label("PLAY", 32, ExSkateUI.LIME)
	root.add_child(_button_text)
	ExSkateUI.set_text_centered(_button_text, "PLAY", Vector2(650, 550))


func update(dt: float) -> void:
	_pulse += dt
	var lit := int(_pulse / 0.5) % 2 == 1
	if lit != _lit:
		_lit = lit
		ExSkateUI.style_box(_button, lit)
		_button_text.add_theme_color_override("font_color", Color.BLACK if lit else ExSkateUI.LIME)


func reset() -> void:
	_pulse = 0.0
	_lit = false
	ExSkateUI.style_box(_button, false)
	_button_text.add_theme_color_override("font_color", ExSkateUI.LIME)
