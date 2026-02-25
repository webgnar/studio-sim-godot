extends PanelContainer
class_name MissionCard

## A card in the Commissions sidebar representing a mission
## Displays the reference image thumbnail

signal card_clicked(index: int)

@onready var thumbnail: TextureRect = $MarginContainer/HBoxContainer/Thumbnail

var card_index: int = 0
var mission: PaintingMission = null
var is_selected: bool = false

var default_style: StyleBoxFlat
var selected_style: StyleBoxFlat

func _ready():
	# Create styles
	default_style = StyleBoxFlat.new()
	default_style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	default_style.corner_radius_top_left = 4
	default_style.corner_radius_top_right = 4
	default_style.corner_radius_bottom_right = 4
	default_style.corner_radius_bottom_left = 4

	selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.95, 0.9, 0.6, 0.9)
	selected_style.corner_radius_top_left = 4
	selected_style.corner_radius_top_right = 4
	selected_style.corner_radius_bottom_right = 4
	selected_style.corner_radius_bottom_left = 4

	add_theme_stylebox_override("panel", default_style)

	# Connect click
	gui_input.connect(_on_gui_input)

func setup(mission_data: PaintingMission, index: int):
	"""Initialize the card with mission data"""
	mission = mission_data
	card_index = index

	# Load thumbnail
	if mission.reference_image_path and mission.reference_image_path != "":
		var texture = load(mission.reference_image_path) as Texture2D
		if texture:
			thumbnail.texture = texture
			return

	thumbnail.texture = null

func set_selected(selected: bool):
	"""Update selection visual state"""
	is_selected = selected
	add_theme_stylebox_override("panel", selected_style if selected else default_style)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(card_index)
