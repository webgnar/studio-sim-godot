extends PanelContainer
class_name MissionCard

## Reusable mission card component for mission selection UI
## Displays mission thumbnail, title, difficulty, and completion status

@export var selected_style: StyleBoxFlat

@onready var thumbnail: TextureRect = $MarginContainer/HBoxContainer/Thumbnail
@onready var title_label: Label = $MarginContainer/HBoxContainer/InfoContainer/TitleLabel
@onready var completion_label: Label = $MarginContainer/HBoxContainer/InfoContainer/CompletionLabel

var mission: PaintingMission = null
var card_index: int = 0
var is_selected: bool = false

signal card_clicked(index: int)

func _ready():
	gui_input.connect(_on_gui_input)

func setup(mission_data: PaintingMission, index: int):
	"""Configure the card with mission data"""
	# Ensure nodes are available
	if not title_label:
		thumbnail = $MarginContainer/HBoxContainer/Thumbnail
		title_label = $MarginContainer/HBoxContainer/InfoContainer/TitleLabel
		completion_label = $MarginContainer/HBoxContainer/InfoContainer/CompletionLabel

	mission = mission_data
	card_index = index

	# Set title
	title_label.text = mission.title

	# Load thumbnail if available
	if mission.reference_image_path and mission.reference_image_path != "":
		var texture = load(mission.reference_image_path) as Texture2D
		if texture:
			thumbnail.texture = texture
			thumbnail.visible = true
		else:
			thumbnail.visible = false
	else:
		thumbnail.visible = false

	# Update completion status
	if MissionManager:
		var completion_data = MissionManager.get_mission_completion(mission.mission_id)
		if completion_data["completed"]:
			completion_label.text = tr("Completed - Grade: %s") % completion_data["grade"]
			completion_label.visible = true
		else:
			completion_label.visible = false

func set_selected(selected: bool):
	"""Update visual state based on selection"""
	is_selected = selected
	if selected and selected_style:
		add_theme_stylebox_override("panel", selected_style)
	else:
		remove_theme_stylebox_override("panel")

func _on_gui_input(event: InputEvent):
	"""Handle mouse clicks"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(card_index)
