extends CanvasLayer
class_name PaintingPromptDialog

## Modal dialog prompting the player to add a title/artist statement before shipping

signal dismissed()
signal open_inventory(painting: CarryablePainting)

@onready var dismiss_button: Button = $Overlay/CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonBox/DismissButton
@onready var add_button: Button = $Overlay/CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonBox/AddButton

var painting: CarryablePainting
var _previous_mouse_mode: Input.MouseMode

func setup(target_painting: CarryablePainting) -> void:
	painting = target_painting

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	dismiss_button.pressed.connect(_on_dismiss)
	add_button.pressed.connect(_on_open_inventory)
	add_button.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.pressed.emit()
	elif event.is_action_pressed("go_back"):
		get_viewport().set_input_as_handled()
		_on_dismiss()

func _on_dismiss() -> void:
	Input.mouse_mode = _previous_mouse_mode
	dismissed.emit()
	queue_free()

func _on_open_inventory() -> void:
	Input.mouse_mode = _previous_mouse_mode
	open_inventory.emit(painting)
	queue_free()
