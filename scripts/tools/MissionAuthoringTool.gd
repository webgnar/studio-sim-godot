extends Node
class_name MissionAuthoringTool

## Tool for creating missions from the current 2D painting canvas
## Captures sticker layout and saves as a PaintingMission resource

signal mission_saved(mission_path: String)

var painting_system_2d: PaintingSystem2D = null

func _init(system_2d: PaintingSystem2D = null):
	painting_system_2d = system_2d

func set_painting_system(system_2d: PaintingSystem2D):
	"""Set the 2D painting system to capture from"""
	painting_system_2d = system_2d

func capture_current_canvas(mission_id: String, title: String, description: String, reward: int, difficulty: int) -> PaintingMission:
	"""Capture current canvas state as a mission"""
	if not painting_system_2d:
		push_error("MissionAuthoringTool: No painting system assigned!")
		return null

	if painting_system_2d.placed_layers.is_empty():
		push_error("MissionAuthoringTool: Canvas is empty, cannot create mission")
		return null

	# Create new mission
	var mission = PaintingMission.new()
	mission.mission_id = mission_id
	mission.title = title
	mission.description = description
	mission.reward = reward
	mission.difficulty = difficulty

	# Sort layers by z-order (back to front)
	var sorted_layers = painting_system_2d.placed_layers.duplicate()
	sorted_layers.sort_custom(func(a, b): return a.order < b.order)

	# Convert PlacedLayer2D to PlacedStickerData with full placement info
	for layer in sorted_layers:
		if not layer.node:
			continue

		var sticker_data = PlacedStickerData.new()
		sticker_data.sticker_id = layer.id
		sticker_data.position = layer.node.position
		sticker_data.rotation_deg = layer.rotation_deg
		sticker_data.scale = layer.node.scale.x  # Assume uniform scale
		sticker_data.z_order = layer.order

		mission.target_stickers.append(sticker_data)

	return mission

func save_mission(mission: PaintingMission, file_path: String) -> bool:
	"""Save mission to disk as .tres resource file"""
	if not mission:
		push_error("MissionAuthoringTool: Mission is null!")
		return false

	# Ensure directory exists
	var dir = DirAccess.open("res://")
	var folder = file_path.get_base_dir()
	if not dir.dir_exists(folder):
		dir.make_dir_recursive(folder)

	# Generate and save screenshot
	var screenshot_path = _generate_screenshot(file_path)
	if screenshot_path:
		mission.reference_image_path = screenshot_path

	# Save the resource
	var error = ResourceSaver.save(mission, file_path)
	if error != OK:
		push_error("MissionAuthoringTool: Failed to save mission to %s (error: %d)" % [file_path, error])
		return false

	print("MissionAuthoringTool: Saved mission '%s' to %s" % [mission.title, file_path])

	# Update the manifest to include this new mission
	_update_manifest(file_path)

	mission_saved.emit(file_path)
	return true

func _generate_screenshot(mission_path: String) -> String:
	"""Capture screenshot of the 2D canvas and save as PNG"""
	if not painting_system_2d or not painting_system_2d.canvas_viewport:
		push_error("MissionAuthoringTool: Cannot generate screenshot - no viewport!")
		return ""

	# Get the viewport texture
	var viewport_texture = painting_system_2d.canvas_viewport.get_texture()
	if not viewport_texture:
		push_error("MissionAuthoringTool: Cannot get viewport texture!")
		return ""

	# Get the image from the texture
	var image = viewport_texture.get_image()
	if not image:
		push_error("MissionAuthoringTool: Cannot get image from texture!")
		return ""

	# Rotate image 90 degrees clockwise to match in-game view
	# (The 2D viewport is mapped to a horizontal 3D plane, causing a 90° rotation)
	image.rotate_90(CLOCKWISE)

	# Generate screenshot filename based on mission path
	var base_path = mission_path.get_basename()  # Remove .tres extension
	var screenshot_path = base_path + "_ref.png"

	# Save the image as PNG
	var error = image.save_png(screenshot_path)
	if error != OK:
		push_error("MissionAuthoringTool: Failed to save screenshot to %s (error: %d)" % [screenshot_path, error])
		return ""

	print("MissionAuthoringTool: Saved reference screenshot to %s" % screenshot_path)
	return screenshot_path

func create_and_save_mission(mission_id: String, title: String, description: String, reward: int, difficulty: int, file_path: String) -> bool:
	"""Convenience function to capture and save in one call"""
	var mission = capture_current_canvas(mission_id, title, description, reward, difficulty)
	if not mission:
		return false

	return save_mission(mission, file_path)

func _update_manifest(mission_file_path: String):
	"""Update the missions manifest to include the new mission"""
	var missions_path = "res://resources/missions/"
	var manifest_path = missions_path + "missions_manifest.json"
	var filename = mission_file_path.get_file()

	# Load existing manifest or create new one
	var missions: Array = []
	var manifest = {}

	if FileAccess.file_exists(manifest_path):
		var file = FileAccess.open(manifest_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()

			var json = JSON.new()
			if json.parse(json_string) == OK:
				manifest = json.data
				if manifest.has("missions"):
					missions = manifest["missions"]

	# Add the new mission if not already in list
	if not missions.has(filename):
		missions.append(filename)
		missions.sort()  # Keep alphabetically sorted

	# Update manifest
	manifest["missions"] = missions
	manifest["generated_at"] = Time.get_datetime_string_from_system()

	# Save manifest
	var file = FileAccess.open(manifest_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
		print("MissionAuthoringTool: Updated manifest with %d missions" % missions.size())
	else:
		push_error("MissionAuthoringTool: Failed to update manifest!")
