extends Control
class_name MissionHUD

## Always-visible HUD in bottom-right corner showing current mission name and target thumbnail

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

	# Position in bottom-right corner
	_setup_anchors()

func _setup_anchors():
	"""Position HUD in bottom-right corner"""
	# Anchor to bottom-right
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0

	# Offset from corner (left, top, right, bottom)
	# Negative values to pull inward from anchors
	offset_left = -260  # Width of HUD + margin
	offset_top = -80    # Height of HUD + margin
	offset_right = -10  # Margin from right edge
	offset_bottom = -10 # Margin from bottom edge

	grow_horizontal = 0
	grow_vertical = 0

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
