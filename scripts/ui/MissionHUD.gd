extends Control
class_name MissionHUD

## Always-visible HUD in bottom-left corner showing current mission name and target thumbnail

@onready var thumbnail_rect = $VBoxContainer/ThumbnailRect
@onready var mission_name_label = $VBoxContainer/MissionNameLabel

var mission_active := false

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
	mission_active = true
	visible = true

func _on_mission_ended(_mission: PaintingMission, _result = null):
	"""Hide HUD when mission ends"""
	mission_active = false
	visible = false
