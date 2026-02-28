extends Node3D  # or whatever your world root extends

@onready var painting_root_3d = $PaintingRoot
@onready var painting_root_2d = $PaintingRoot2d
@onready var mission_authoring_ui = $DevTools_Layer/MissionAuthoringUi
var camera_zone_switch: Node = null

func _ready():
	# Register both painting systems with the mode manager
	PaintingModeManager.register_3d_system(painting_root_3d, painting_root_3d)
	PaintingModeManager.register_2d_system(painting_root_2d.get_node("CanvasViewport/CanvasRoot"), painting_root_2d)

	# Register 3D painting system with WorldStateManager for persistence
	if WorldStateManager and painting_root_3d:
		WorldStateManager.register_painting_system_3d(painting_root_3d)

	# Connect mission authoring UI to 2D system
	var painting_system_2d = painting_root_2d.get_node("CanvasViewport/CanvasRoot")
	if mission_authoring_ui and painting_system_2d:
		mission_authoring_ui.set_painting_system(painting_system_2d)

	# Connect lightswitch3 for "Let There Be Light" achievement
	var lightswitch3 = find_child("lightswitch3", true, false)
	if lightswitch3:
		for child in lightswitch3.get_children():
			if child is LightSwitchInteraction:
				child.lights_toggled.connect(_on_lightswitch3_toggled)
				break

	# Connect lightswitch4 to toggle camera zones
	var lightwitch4 = find_child("lightwitch4", true, false)
	if lightwitch4:
		for child in lightwitch4.get_children():
			if child is LightSwitchInteraction:
				camera_zone_switch = child
				break
	if camera_zone_switch:
		camera_zone_switch.lights_toggled.connect(_on_camera_zone_switch_toggled)

	# Wait one frame for scene tree to fully initialize
	await get_tree().process_frame

	# Hide all shop-gated props before loading (purchased ones are revealed by ShopManager
	# inside load_world_state via WorldStateManager.reveal_purchased_items)
	_hide_all_shop_props()

	# Load saved world state (spawn saved carryable paintings, reveal purchased shop items)
	if WorldStateManager:
		WorldStateManager.load_world_state(self)

func _hide_all_shop_props() -> void:
	"""Hide and freeze all shop-gated props. ShopManager reveals purchased ones after load."""
	for node in get_tree().get_nodes_in_group("shop_prop"):
		node.visible = false
		if node is RigidBody3D:
			node.freeze = true
		# Disable all descendant collision shapes so StaticBody3D children (e.g. the
		# mirror's palette stack, phone GLB body, sticker button base) don't block the player
		for shape in node.find_children("*", "CollisionShape3D", true, false):
			shape.disabled = true

func _on_lightswitch3_toggled(_switch_id: String, is_on: bool) -> void:
	if is_on and SteamManager:
		SteamManager.unlock_achievement("ACH_LET_THERE_BE_LIGHT")

func _on_camera_zone_switch_toggled(_switch_id: String, is_on: bool) -> void:
	if CameraManager:
		CameraManager.toggle_zones(is_on)
