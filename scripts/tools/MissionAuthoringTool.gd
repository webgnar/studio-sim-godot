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

	# Convert PlacedLayer2D to PaintingLayerDefinition
	for layer in sorted_layers:
		# Find the definition in the library that matches this ID
		for definition in painting_system_2d.sticker_library:
			if definition.id == layer.id:
				mission.target_layers.append(definition)
				break

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

	# Save the resource
	var error = ResourceSaver.save(mission, file_path)
	if error != OK:
		push_error("MissionAuthoringTool: Failed to save mission to %s (error: %d)" % [file_path, error])
		return false

	print("MissionAuthoringTool: Saved mission '%s' to %s" % [mission.title, file_path])
	mission_saved.emit(file_path)
	return true

func create_and_save_mission(mission_id: String, title: String, description: String, reward: int, difficulty: int, file_path: String) -> bool:
	"""Convenience function to capture and save in one call"""
	var mission = capture_current_canvas(mission_id, title, description, reward, difficulty)
	if not mission:
		return false

	return save_mission(mission, file_path)
