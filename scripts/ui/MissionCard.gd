extends PanelContainer
class_name MissionCard

## Reusable mission card component for mission selection UI
## Displays mission thumbnail, title, difficulty, and completion status

var thumbnail: TextureRect
var title_label: Label
var completion_label: Label

var mission: PaintingMission = null
var card_index: int = 0
var is_selected: bool = false

# Styling
var default_style: StyleBoxFlat
var selected_style: StyleBoxFlat

signal card_clicked(index: int)

func _ready():
	# Get child nodes
	thumbnail = $MarginContainer/HBoxContainer/Thumbnail
	title_label = $MarginContainer/HBoxContainer/InfoContainer/TitleLabel
	completion_label = $MarginContainer/HBoxContainer/InfoContainer/CompletionLabel

	# Check if there's already a theme stylebox override (from scene file)
	# If not, create default styles
	var existing_panel = get_theme_stylebox("panel")
	if existing_panel:
		# Clone the existing style for default and selected states
		default_style = existing_panel.duplicate() as StyleBoxFlat
		selected_style = existing_panel.duplicate() as StyleBoxFlat

		# Modify selected style to have blue border
		if selected_style is StyleBoxFlat:
			selected_style.border_color = Color(0.2, 0.6, 1.0)  # Bright blue
			selected_style.set_border_width_all(3)
	else:
		# No theme override, create default styles
		default_style = StyleBoxFlat.new()
		default_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
		default_style.border_color = Color(0.4, 0.4, 0.4)
		default_style.set_border_width_all(2)
		default_style.set_corner_radius_all(4)

		selected_style = StyleBoxFlat.new()
		selected_style.bg_color = Color(0.2, 0.3, 0.4, 0.9)
		selected_style.border_color = Color(0.2, 0.6, 1.0)  # Bright blue
		selected_style.set_border_width_all(3)
		selected_style.set_corner_radius_all(4)

		# Set initial style
		add_theme_stylebox_override("panel", default_style)

	# Connect click event
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
			completion_label.text = "Completed - Grade: %s" % completion_data["grade"]
			completion_label.visible = true
		else:
			completion_label.visible = false

func set_selected(selected: bool):
	"""Update visual state based on selection"""
	is_selected = selected
	if selected:
		add_theme_stylebox_override("panel", selected_style)
	else:
		add_theme_stylebox_override("panel", default_style)

func _on_gui_input(event: InputEvent):
	"""Handle mouse clicks"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(card_index)
