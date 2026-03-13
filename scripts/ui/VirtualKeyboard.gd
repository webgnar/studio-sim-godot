extends CanvasLayer
class_name VirtualKeyboard

## Controller-navigable on-screen keyboard for painting name / artist statement entry.
## Shown for non-Steam-Deck gamepad users instead of the Steam overlay keyboard.
## Navigation is driven manually by InventoryTab forwarding events via handle_nav_input().

signal text_confirmed(text: String)
signal cancelled()

# Canonical key values — these never change (signal bindings capture these at connect time)
const KEY_ROWS: Array = [
	["A","B","C","D","E","F","G","H","I","J","K","L","M"],  # row 0
	["N","O","P","Q","R","S","T","U","V","W","X","Y","Z"],  # row 1
	["0","1","2","3","4","5","6","7","8","9"],               # row 2
	["CAPS","SPACE","DEL","OK"],                             # row 3
]

@onready var title_label: Label = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var current_text_label: Label = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CurrentTextLabel
@onready var key_area: VBoxContainer = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/KeyArea
@onready var hint_label: Label = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HintLabel

var _button_rows: Array = []  # Array of Array[Button], built in _ready()
var _focus_row: int = 0
var _focus_col: int = 0
var _caps_on: bool = true
var _current_text: String = ""
var _max_length: int = 50
var _nav_cooldown: float = 0.0
const NAV_COOLDOWN_TIME: float = 0.15


func _ready() -> void:
	visible = false
	# Build _button_rows from scene children and wire signal connections
	var row_containers := key_area.get_children()
	for row_idx in range(row_containers.size()):
		var container := row_containers[row_idx] as HBoxContainer
		if container == null:
			continue
		var button_row: Array[Button] = []
		var btn_children := container.get_children()
		for col_idx in range(btn_children.size()):
			var btn := btn_children[col_idx] as Button
			if btn == null:
				continue
			button_row.append(btn)
			if row_idx < KEY_ROWS.size() and col_idx < KEY_ROWS[row_idx].size():
				# Bind canonical key value at connection time — safe to mutate btn.text later
				btn.pressed.connect(_on_key_pressed.bind(KEY_ROWS[row_idx][col_idx]))
		_button_rows.append(button_row)


func _process(delta: float) -> void:
	if _nav_cooldown > 0.0:
		_nav_cooldown -= delta


func open(initial_text: String, title: String, max_length: int = 50) -> void:
	"""Show the virtual keyboard pre-filled with initial_text."""
	_current_text = initial_text
	_max_length = max_length
	_nav_cooldown = 0.0
	_focus_row = 0
	_focus_col = 0
	title_label.text = title
	var a_glyph: String = InputDeviceManager.get_formatted_prompt("jump", "Confirm")
	var b_glyph: String = InputDeviceManager.get_formatted_prompt("go_back", "Cancel")
	hint_label.text = "%s    %s" % [a_glyph, b_glyph]
	_update_display()
	_update_focus_visual()
	visible = true


func handle_nav_input(event: InputEvent) -> void:
	"""Called by InventoryTab's _input() guard before consuming the event.
	Drives D-pad/stick navigation and key activation without relying on Godot's focus system."""
	if event.is_action_pressed("go_back"):
		visible = false
		cancelled.emit()
		return

	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		_activate_focused()
		return

	if _nav_cooldown > 0.0:
		return

	var moved := false
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		moved = _move_h(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		moved = _move_h(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		moved = _move_v(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		moved = _move_v(-1)

	if moved:
		_nav_cooldown = NAV_COOLDOWN_TIME


func _move_h(delta: int) -> bool:
	var new_col := _focus_col + delta
	if new_col < 0 or new_col >= KEY_ROWS[_focus_row].size():
		return false
	_focus_col = new_col
	_update_focus_visual()
	return true


func _move_v(delta: int) -> bool:
	var new_row := _focus_row + delta
	if new_row < 0 or new_row >= KEY_ROWS.size():
		return false
	_focus_row = new_row
	# Clamp col when entering a shorter row (e.g. from "9" col=9 into ActionRow col=3=OK)
	_focus_col = mini(_focus_col, KEY_ROWS[_focus_row].size() - 1)
	_update_focus_visual()
	return true


func _update_focus_visual() -> void:
	for row in _button_rows:
		for btn in row:
			(btn as Button).modulate = Color.WHITE
	if _focus_row < _button_rows.size() and _focus_col < _button_rows[_focus_row].size():
		(_button_rows[_focus_row][_focus_col] as Button).modulate = Color(1.2, 1.2, 1.0, 1.0)


func _activate_focused() -> void:
	if _focus_row < KEY_ROWS.size() and _focus_col < KEY_ROWS[_focus_row].size():
		_on_key_pressed(KEY_ROWS[_focus_row][_focus_col])


func _on_key_pressed(key: String) -> void:
	match key:
		"CAPS":
			_caps_on = not _caps_on
			_update_letter_case()
		"DEL":
			if _current_text.length() > 0:
				_current_text = _current_text.left(_current_text.length() - 1)
			_update_display()
		"SPACE":
			if _current_text.length() < _max_length:
				_current_text += " "
			_update_display()
		"OK":
			visible = false
			text_confirmed.emit(_current_text)
		_:
			if _current_text.length() < _max_length:
				_current_text += key if _caps_on else key.to_lower()
			_update_display()


func _update_letter_case() -> void:
	"""Update A-Z button display text to match current caps state."""
	for row_idx in [0, 1]:
		if row_idx >= _button_rows.size():
			continue
		for col_idx in range(_button_rows[row_idx].size()):
			var btn := _button_rows[row_idx][col_idx] as Button
			var key: String = KEY_ROWS[row_idx][col_idx]
			btn.text = key if _caps_on else key.to_lower()
	_update_focus_visual()  # re-apply highlight after text changes


func _update_display() -> void:
	current_text_label.text = _current_text if _current_text != "" else " "


func _input(event: InputEvent) -> void:
	# Fallback safety: handle go_back in case event propagation delivers it here
	if not visible:
		return
	if event is InputEventJoypadButton and event.is_action_pressed("go_back"):
		visible = false
		cancelled.emit()
		get_viewport().set_input_as_handled()
