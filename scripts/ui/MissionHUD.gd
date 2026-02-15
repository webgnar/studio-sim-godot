extends Control
class_name MissionHUD

## Always-visible HUD in bottom-left corner showing current mission name and target thumbnail

@onready var panel_container = $PanelContainer
@onready var thumbnail_rect = $PanelContainer/MarginContainer/HBoxContainer/ThumbnailRect
@onready var mission_name_label = $PanelContainer/MarginContainer/HBoxContainer/MissionNameLabel

func _ready():
	# Initially hidden - will show when mission starts
	visible = false

	# Connect to MissionManager signals
	if MissionManager:
		MissionManager.mission_started.connect(_on_mission_started)
		MissionManager.mission_completed.connect(_on_mission_ended)
		MissionManager.mission_failed.connect(_on_mission_ended)
		MissionManager.mission_aborted.connect(_on_mission_ended)


func _on_mission_started(mission: PaintingMission):
	"""Show HUD when mission starts"""
	if not mission:
		return

	# Update mission name
	mission_name_label.text = mission.title

	# Load thumbnail from reference image
	if mission.reference_image_path and mission.reference_image_path != "":
		var texture = load(mission.reference_image_path) as Texture2D
		if texture:
			thumbnail_rect.texture = texture
		else:
			thumbnail_rect.texture = null
	else:
		thumbnail_rect.texture = null

	# Show the HUD
	visible = true

func _on_mission_ended(_mission: PaintingMission, _result = null):
	"""Hide HUD when mission ends"""
	visible = false
