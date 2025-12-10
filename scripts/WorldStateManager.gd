extends Node

# WorldStateManager - Singleton for managing persistent world state (carryable paintings)
# Handles saving/loading painting positions, rotations, and textures to disk

const SAVE_VERSION = 1
const WORLD_STATE_PATH = "user://world_state.json"
const TEXTURES_DIR = "user://world_paintings"

# Preload carryable painting scene for instantiation
var carryable_painting_scene = preload("res://scenes/CarryablePainting.tscn")

# Dictionary mapping painting nodes to their metadata
# Format: { painting_node: {"id": String, "texture_path": String} }
var _registered_paintings: Dictionary = {}

func _ready():
	_ensure_directories()

# ============================================================================
# Registration (paintings auto-register on _ready)
# ============================================================================

func register_painting(painting: Node, painting_id: String, texture_path: String) -> void:
	"""Register a carryable painting with the save system"""
	if not painting:
		push_warning("Attempted to register null painting")
		return

	_registered_paintings[painting] = {
		"id": painting_id,
		"texture_path": texture_path
	}

func unregister_painting(painting: Node) -> void:
	"""Unregister a painting when it's removed from scene"""
	if painting in _registered_paintings:
		_registered_paintings.erase(painting)

# ============================================================================
# Save/Load
# ============================================================================

func save_world_state() -> bool:
	"""
	Save all registered paintings to JSON file
	Returns true on success, false on failure
	"""
	# Force drop all carried paintings to save accurate positions
	_force_drop_carried_paintings()

	# Wait one frame for physics to settle after force drop
	await get_tree().process_frame

	# Build save data
	var save_data = {
		"version": SAVE_VERSION,
		"last_saved": _get_timestamp(),
		"paintings": []
	}

	var valid_painting_ids = []

	for painting in _registered_paintings.keys():
		if not is_instance_valid(painting):
			continue

		var metadata = _registered_paintings[painting]
		var painting_id = metadata["id"]
		var texture_path = metadata["texture_path"]

		# Store painting data
		var painting_data = {
			"id": painting_id,
			"texture_path": texture_path,
			"position": {
				"x": painting.global_position.x,
				"y": painting.global_position.y,
				"z": painting.global_position.z
			},
			"rotation": {
				"x": painting.global_rotation.x,
				"y": painting.global_rotation.y,
				"z": painting.global_rotation.z
			}
		}

		save_data["paintings"].append(painting_data)
		valid_painting_ids.append(painting_id)

	# Write to file
	var file = FileAccess.open(WORLD_STATE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to open world state file for writing: " + str(FileAccess.get_open_error()))
		return false

	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()

	# Clean up orphaned texture files
	_cleanup_orphaned_textures(valid_painting_ids)

	print("World state saved: %d paintings" % save_data["paintings"].size())
	return true

func load_world_state(world_root: Node3D) -> void:
	"""
	Load world state from JSON and spawn paintings in the world
	Silently fails if save file doesn't exist (normal for new games)
	"""
	if not FileAccess.file_exists(WORLD_STATE_PATH):
		return  # No save file, nothing to load

	var file = FileAccess.open(WORLD_STATE_PATH, FileAccess.READ)
	if not file:
		push_warning("Failed to open world state file for reading")
		return

	var json_string = file.get_as_text()
	file.close()

	# Parse JSON
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse world state JSON: " + json.get_error_message())
		return

	var save_data = json.data

	# Validate version
	if not save_data.has("version") or save_data["version"] != SAVE_VERSION:
		push_warning("World state version mismatch, skipping load")
		return

	# Load paintings
	var paintings_array = save_data.get("paintings", [])
	var loaded_count = 0

	for painting_data in paintings_array:
		if _load_painting(world_root, painting_data):
			loaded_count += 1

	print("World state loaded: %d/%d paintings" % [loaded_count, paintings_array.size()])

func clear_world_state() -> void:
	"""
	Clear all world state data (called on New Game)
	Deletes save file and all texture files
	"""
	# Delete save file
	if FileAccess.file_exists(WORLD_STATE_PATH):
		DirAccess.remove_absolute(WORLD_STATE_PATH)

	# Delete textures directory
	if DirAccess.dir_exists_absolute(TEXTURES_DIR):
		_delete_directory_recursive(TEXTURES_DIR)

	# Clear registered paintings (though scene should be reloading anyway)
	_registered_paintings.clear()

	print("World state cleared")

# ============================================================================
# Helpers
# ============================================================================

func _ensure_directories() -> void:
	"""Ensure required directories exist"""
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("Failed to open user:// directory")
		return

	if not dir.dir_exists("world_paintings"):
		var error = dir.make_dir("world_paintings")
		if error != OK:
			push_error("Failed to create world_paintings directory: " + str(error))

func _cleanup_orphaned_textures(valid_painting_ids: Array) -> void:
	"""Delete texture files not referenced in current save data"""
	if not DirAccess.dir_exists_absolute(TEXTURES_DIR):
		return

	var dir = DirAccess.open(TEXTURES_DIR)
	if not dir:
		return

	dir.list_dir_begin()
	var filename = dir.get_next()

	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".png"):
			# Extract painting ID from filename (remove .png extension)
			var painting_id = filename.get_basename()

			# Check if this ID is in the valid list
			if not painting_id in valid_painting_ids:
				var full_path = TEXTURES_DIR + "/" + filename
				DirAccess.remove_absolute(full_path)
				print("Cleaned up orphaned texture: " + filename)

		filename = dir.get_next()

	dir.list_dir_end()

func _force_drop_carried_paintings() -> void:
	"""Force drop all paintings being carried (before saving)"""
	for painting in _registered_paintings.keys():
		if not is_instance_valid(painting):
			continue

		# Find CarryableComponent
		var carryable = painting.get_node_or_null("CarryableComponent")
		if carryable and carryable.has_method("force_drop"):
			carryable.force_drop()

func _get_timestamp() -> String:
	"""Get current timestamp as ISO 8601 string"""
	var time = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		time.year, time.month, time.day,
		time.hour, time.minute, time.second
	]

func _load_painting(world_root: Node3D, painting_data: Dictionary) -> bool:
	"""
	Load a single painting from save data
	Returns true on success, false on failure
	"""
	var painting_id = painting_data.get("id", "")
	var texture_path = painting_data.get("texture_path", "")
	var position_data = painting_data.get("position", {})
	var rotation_data = painting_data.get("rotation", {})

	# Validate data
	if painting_id == "" or texture_path == "":
		push_warning("Invalid painting data, skipping")
		return false

	# Check if texture file exists
	if not FileAccess.file_exists(texture_path):
		push_warning("Texture file missing for painting: " + texture_path)
		return false

	# Instantiate painting
	var painting = carryable_painting_scene.instantiate()

	# Set metadata (must be set before adding to tree so _ready can register)
	painting.painting_id = painting_id
	painting.texture_path = texture_path

	# Add to world
	world_root.add_child(painting)

	# Set transform
	painting.global_position = Vector3(
		position_data.get("x", 0.0),
		position_data.get("y", 0.0),
		position_data.get("z", 0.0)
	)
	painting.global_rotation = Vector3(
		rotation_data.get("x", 0.0),
		rotation_data.get("y", 0.0),
		rotation_data.get("z", 0.0)
	)

	# Load and apply texture
	var image = Image.new()
	var error = image.load(texture_path)
	if error != OK:
		push_error("Failed to load texture image: " + str(error))
		painting.queue_free()
		return false

	var texture = ImageTexture.create_from_image(image)

	# Apply texture to mesh
	var mesh_instance = painting.get_node_or_null("MeshInstance3D")
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_texture = texture
		mesh_instance.set_surface_override_material(0, material)

	return true

func _delete_directory_recursive(path: String) -> void:
	"""Recursively delete a directory and all its contents"""
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var filename = dir.get_next()

	while filename != "":
		var full_path = path + "/" + filename

		if dir.current_is_dir():
			_delete_directory_recursive(full_path)
		else:
			DirAccess.remove_absolute(full_path)

		filename = dir.get_next()

	dir.list_dir_end()
	DirAccess.remove_absolute(path)
