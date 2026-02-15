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

func _on_dismiss() -> void:
	Input.mouse_mode = _previous_mouse_mode
	dismissed.emit()
	queue_free()

func _on_open_inventory() -> void:
	Input.mouse_mode = _previous_mouse_mode
	open_inventory.emit(painting)
	queue_free()
