extends CanvasLayer
class_name VirtualKeyboard

## Controller-navigable on-screen keyboard for painting name / artist statement entry.
## Shown for non-Steam-Deck gamepad users instead of the Steam overlay keyboard.

signal text_confirmed(text: String)
signal cancelled()

# Key layout — order matches KeyGrid children (8 columns, 5 rows = 40 keys)
const KEY_LAYOUT: Array[String] = [
	"Q","W","E","R","T","Y","U","I",
	"O","P","A","S","D","F","G","H",
	"J","K","L","Z","X","C","V","B",
	"N","M","1","2","3","4","5","6",
	"7","8","9","0","SPACE","DEL",".","-",
]

@onready var title_label: Label = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var current_text_label: Label = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CurrentTextLabel
@onready var key_grid: GridContainer = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/KeyGrid
@onready var ok_button: Button = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/OKButton
@onready var hint_label: Label = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HintLabel

var _current_text: String = ""
var _max_length: int = 50
var _first_key_button: Button = null


func _ready() -> void:
	visible = false

	# Wire up each key button by index matching KEY_LAYOUT
	var children = key_grid.get_children()
	for i in range(children.size()):
		var btn := children[i] as Button
		if btn == null:
			continue
		if i == 0:
			_first_key_button = btn
		var key_value: String = KEY_LAYOUT[i] if i < KEY_LAYOUT.size() else ""
		btn.pressed.connect(_on_key_pressed.bind(key_value))

	# Wire bottom row keys to navigate down into OK button
	var bottom_row_start: int = KEY_LAYOUT.size() - 8
	for i in range(bottom_row_start, mini(KEY_LAYOUT.size(), children.size())):
		var btn := children[i] as Button
		if btn:
			btn.focus_neighbor_bottom = ok_button.get_path()
	if children.size() > bottom_row_start:
		ok_button.focus_neighbor_top = children[bottom_row_start].get_path()

	ok_button.pressed.connect(_on_ok_pressed)


func open(initial_text: String, title: String, max_length: int = 50) -> void:
	"""Show the virtual keyboard pre-filled with initial_text."""
	_current_text = initial_text
	_max_length = max_length
	title_label.text = title
	var a_glyph: String = InputDeviceManager.get_formatted_prompt("jump", "Confirm")
	var b_glyph: String = InputDeviceManager.get_formatted_prompt("go_back", "Cancel")
	hint_label.text = "%s    %s" % [a_glyph, b_glyph]
	_update_display()
	visible = true
	if _first_key_button:
		_first_key_button.grab_focus()


func _update_display() -> void:
	current_text_label.text = _current_text if _current_text != "" else " "


func _on_key_pressed(key: String) -> void:
	match key:
		"DEL":
			if _current_text.length() > 0:
				_current_text = _current_text.left(_current_text.length() - 1)
		"SPACE":
			if _current_text.length() < _max_length:
				_current_text += " "
		_:
			if _current_text.length() < _max_length:
				_current_text += key
	_update_display()


func _on_ok_pressed() -> void:
	visible = false
	text_confirmed.emit(_current_text)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# B button cancels without saving
	if event is InputEventJoypadButton and event.is_action_pressed("go_back"):
		visible = false
		cancelled.emit()
		get_viewport().set_input_as_handled()
