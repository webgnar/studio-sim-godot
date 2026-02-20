@tool
extends PanelContainer
class_name PaintingCard

## A card in the Inventory sidebar representing a painting
## Displays a thumbnail and the painting's name

signal card_clicked(index: int)

@onready var thumbnail: TextureRect = $MarginContainer/HBoxContainer/Thumbnail
@onready var title_label: Label = $MarginContainer/HBoxContainer/InfoContainer/TitleLabel
@onready var info_container: VBoxContainer = $MarginContainer/HBoxContainer/InfoContainer

var status_label: Label = null
var card_index: int = 0
var painting_data: Dictionary = {}
var is_selected: bool = false

var default_style: StyleBoxFlat
var selected_style: StyleBoxFlat

func _ready():
	# Create styles
	default_style = StyleBoxFlat.new()
	default_style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	default_style.set_corner_radius_all(4)

	selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.3, 0.5, 0.7, 0.9)
	selected_style.set_corner_radius_all(4)

	add_theme_stylebox_override("panel", default_style)

	# Create status label
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 48)
	info_container.add_child(status_label)

	if Engine.is_editor_hint():
		title_label.text = "Example Painting"
		status_label.text = "WIP"
		status_label.modulate = Color(1.0, 0.9, 0.3)
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

	# Set title
	var display_name = data.get("name", "")
	if display_name == "":
		display_name = "Untitled"
	title_label.text = display_name

	# Set status
	update_status(data.get("status", "WIP"))

	# Load thumbnail
	_load_thumbnail(data.get("texture_path", ""))

func set_selected(selected: bool):
	"""Update selection visual state"""
	is_selected = selected
	add_theme_stylebox_override("panel", selected_style if selected else default_style)

func update_name(new_name: String):
	"""Update the displayed name"""
	title_label.text = new_name if new_name != "" else "Untitled"

func update_status(status: String):
	"""Update the displayed status with color coding"""
	if not status_label:
		return
	status_label.text = status
	match status:
		"WIP":
			status_label.modulate = Color(1.0, 0.9, 0.3)  # Yellow
		"DONE":
			status_label.modulate = Color(0.4, 1.0, 0.4)  # Green
		"SHIPPED":
			status_label.modulate = Color(0.4, 0.8, 1.0)  # Cyan
		_:
			status_label.modulate = Color.WHITE

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
