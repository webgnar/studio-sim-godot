@tool
extends PanelContainer
class_name PaintingCard

## A card in the Inventory sidebar representing a painting
## Displays a thumbnail and the painting's name

signal card_clicked(index: int)

@onready var thumbnail: TextureRect = $MarginContainer/HBoxContainer/Thumbnail

var card_index: int = 0
var painting_data: Dictionary = {}
var is_selected: bool = false

var default_style: StyleBoxFlat
var selected_style: StyleBoxFlat

func _ready():
	# Create styles
	default_style = StyleBoxFlat.new()
	default_style.bg_color = Color(0.15, 0.15, 0.15, 0.8)

	selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.95, 0.9, 0.6, 0.9)

	add_theme_stylebox_override("panel", default_style)

	if Engine.is_editor_hint():
		var img = Image.create(64, 64, false, Image.FORMAT_RGB8)
		img.fill(Color(0.35, 0.35, 0.35))
		thumbnail.texture = ImageTexture.create_from_image(img)
		return

	# Connect click
	gui_input.connect(_on_gui_input)

func setup(data: Dictionary, index: int):
	"""Initialize the card with painting data"""
	painting_data = data
	card_index = index

	# Set status
	update_status(data.get("status", "WIP"))

	# Load thumbnail
	_load_thumbnail(data.get("texture_path", ""))

func set_selected(selected: bool):
	"""Update selection visual state"""
	is_selected = selected
	add_theme_stylebox_override("panel", selected_style if selected else default_style)

func update_name(_new_name: String):
	pass

func update_status(_status: String):
	pass

func _load_thumbnail(texture_path: String):
	"""Load and display the painting thumbnail"""
	if texture_path == "" or not FileAccess.file_exists(texture_path):
		thumbnail.texture = null
		return

	var image = Image.new()
	var error = image.load(texture_path)
	if error != OK:
		thumbnail.texture = null
		return

	# Rotate to correct orientation (same as PaintingExporter)
	image.rotate_90(CLOCKWISE)

	var texture = ImageTexture.create_from_image(image)
	thumbnail.texture = texture

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(card_index)
