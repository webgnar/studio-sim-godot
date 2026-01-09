extends Node

# WorldStateManager - Singleton for managing persistent world state (carryable paintings)
# Handles saving/loading painting positions, rotations, and textures to disk

const SAVE_VERSION = 2
const WORLD_STATE_PATH = "user://world_state.json"
const TEXTURES_DIR = "user://world_paintings"

# Preload scenes for instantiation
var carryable_painting_scene = preload("res://scenes/CarryablePainting.tscn")
var wall_nail_scene = preload("res://scenes/WallNail.tscn")

# Dictionary mapping painting nodes to their metadata
# Format: { painting_node: {"id": String, "texture_path": String} }
var _registered_paintings: Dictionary = {}

# Dictionary mapping nail nodes to their IDs
# Format: { nail_node: nail_id }
var _registered_nails: Dictionary = {}

# Reference to 3D painting system for saving stickers
var _painting_system_3d: PaintingSystem3D = null

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

func register_nail(nail: Node, nail_id: String) -> void:
	"""Register a wall-mounted nail with the save system"""
	if not nail:
		push_warning("Attempted to register null nail")
		return

	_registered_nails[nail] = nail_id

func unregister_nail(nail: Node) -> void:
	"""Unregister a nail when it's removed from scene"""
	if nail in _registered_nails:
		_registered_nails.erase(nail)

func register_painting_system_3d(system: PaintingSystem3D) -> void:
	"""Register the 3D painting system for sticker persistence"""
	if not system:
		push_warning("Attempted to register null painting system")
		return

	_painting_system_3d = system
	print("PaintingSystem registered for persistence")

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
		"paintings": [],
		"nails": [],
		"stickers_3d": [],
		"economy": _save_economic_state()  # PHASE 0: Economy save
	}

	var valid_painting_ids = []

	# Save nails
	for nail in _registered_nails.keys():
		if not is_instance_valid(nail):
			continue

		var nail_id = _registered_nails[nail]
		var _nail_component = _find_nail_component(nail)

		var nail_data = {
			"id": nail_id,
			"position": {
				"x": nail.global_position.x,
				"y": nail.global_position.y,
				"z": nail.global_position.z
			},
			"rotation": {
				"x": nail.global_rotation.x,
				"y": nail.global_rotation.y,
				"z": nail.global_rotation.z
			}
		}

		save_data["nails"].append(nail_data)

	# Save paintings
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
			},
			"hung_on_nail": ""  # Will be filled if painting is hung
		}

		# Check if painting is hung on a nail
		var hanging_comp = _find_hanging_component(painting)
		if hanging_comp and hanging_comp.is_hung and hanging_comp.current_nail:
			# Find the nail ID
			var nail_node = hanging_comp.current_nail.get_parent()
			if nail_node in _registered_nails:
				painting_data["hung_on_nail"] = _registered_nails[nail_node]

		save_data["paintings"].append(painting_data)
		valid_painting_ids.append(painting_id)

	# Save 3D stickers
	if _painting_system_3d:
		for placed_layer in _painting_system_3d.placed_layers:
			if not is_instance_valid(placed_layer.node):
				continue

			var sticker_data = {
				"id": placed_layer.id,
				"position": {
					"x": placed_layer.node.global_position.x,
					"y": placed_layer.node.global_position.y,
					"z": placed_layer.node.global_position.z
				},
				"rotation": {
					"x": placed_layer.node.global_rotation.x,
					"y": placed_layer.node.global_rotation.y,
					"z": placed_layer.node.global_rotation.z
				},
				"pixel_size": placed_layer.node.pixel_size,
				"order": placed_layer.order,
				"rotation_deg": placed_layer.rotation_deg,
				"surface_key": placed_layer.surface_key  # NEW: Save surface association
			}

			save_data["stickers_3d"].append(sticker_data)

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

	print("World state saved: %d paintings, %d nails, %d 3D stickers" % [save_data["paintings"].size(), save_data["nails"].size(), save_data["stickers_3d"].size()])
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

	# Load nails FIRST (before paintings)
	var nails_array = save_data.get("nails", [])
	var nail_id_map = {}  # Map nail_id -> nail_node for painting attachment
	var nails_loaded = 0

	for nail_data in nails_array:
		var nail = _load_nail(world_root, nail_data)
		if nail:
			nail_id_map[nail_data["id"]] = nail
			nails_loaded += 1

	# Load paintings SECOND (after nails)
	var paintings_array = save_data.get("paintings", [])
	var paintings_loaded = 0

	for painting_data in paintings_array:
		if await _load_painting(world_root, painting_data, nail_id_map):
			paintings_loaded += 1

	# Load 3D stickers THIRD (after nails and paintings)
	var stickers_array = save_data.get("stickers_3d", [])
	var stickers_loaded = 0

	if _painting_system_3d:
		for sticker_data in stickers_array:
			if _load_sticker_3d(sticker_data):
				stickers_loaded += 1
	else:
		push_warning("PaintingSystem not registered, skipping 3D sticker load")

	# PHASE 0: Load economic state
	var economy_data = save_data.get("economy", {})
	_load_economic_state(economy_data)

	print("World state loaded: %d/%d nails, %d/%d paintings, %d/%d stickers" % [nails_loaded, nails_array.size(), paintings_loaded, paintings_array.size(), stickers_loaded, stickers_array.size()])

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

	# Clear registered paintings and nails (though scene should be reloading anyway)
	_registered_paintings.clear()
	_registered_nails.clear()

	# Clear 3D stickers
	if _painting_system_3d:
		_painting_system_3d.clear_canvas()

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

		# Find PaintingHangingComponent (or fallback to CarryableComponent for old paintings)
		var hanging_comp = painting.get_node_or_null("PaintingHangingComponent")
		if not hanging_comp:
			hanging_comp = painting.get_node_or_null("CarryableComponent")

		if hanging_comp and hanging_comp.has_method("drop") and hanging_comp.is_carried:
			hanging_comp.drop()

func _get_timestamp() -> String:
	"""Get current timestamp as ISO 8601 string"""
	var time = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		time.year, time.month, time.day,
		time.hour, time.minute, time.second
	]

func _load_nail(world_root: Node3D, nail_data: Dictionary) -> Node:
	"""
	Load a single nail from save data
	Returns nail node on success, null on failure
	"""
	var position_data = nail_data.get("position", {})
	var rotation_data = nail_data.get("rotation", {})

	# Instantiate nail
	var nail = wall_nail_scene.instantiate()

	# Add to world
	world_root.add_child(nail)

	# Set transform
	nail.global_position = Vector3(
		position_data.get("x", 0.0),
		position_data.get("y", 0.0),
		position_data.get("z", 0.0)
	)
	nail.global_rotation = Vector3(
		rotation_data.get("x", 0.0),
		rotation_data.get("y", 0.0),
		rotation_data.get("z", 0.0)
	)

	return nail

func _load_painting(world_root: Node3D, painting_data: Dictionary, nail_id_map: Dictionary = {}) -> bool:
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

	# Check if painting was hung on a nail
	var hung_on_nail_id = painting_data.get("hung_on_nail", "")
	if hung_on_nail_id != "" and hung_on_nail_id in nail_id_map:
		var nail = nail_id_map[hung_on_nail_id]
		var nail_component = _find_nail_component(nail)
		if nail_component:
			# Wait one frame for painting to finish setup
			await get_tree().process_frame
			# Attach painting to nail
			nail_component.accept_painting(painting)

	return true

func _load_sticker_3d(sticker_data: Dictionary) -> bool:
	"""
	Load a single 3D sticker from save data
	Returns true on success, false on failure
	"""
	if not _painting_system_3d:
		return false

	var sticker_id = sticker_data.get("id", "")
	var position_data = sticker_data.get("position", {})
	var rotation_data = sticker_data.get("rotation", {})
	var pixel_size = sticker_data.get("pixel_size", 0.001)
	var order = sticker_data.get("order", 0)
	var rotation_deg = sticker_data.get("rotation_deg", 0.0)
	var surface_key = sticker_data.get("surface_key", "migrated")  # NEW: Load surface key (default for old saves)

	# Validate data
	if sticker_id == "":
		push_warning("Invalid sticker data: missing id")
		return false

	# Find sticker definition in library
	var definition: PaintingLayerDefinition = null
	for def in _painting_system_3d.sticker_library:
		if def.id == sticker_id:
			definition = def
			break

	if not definition:
		push_warning("Sticker definition not found for id: " + sticker_id + " (library may have changed)")
		return false

	# Recreate Sprite3D node
	var sprite = Sprite3D.new()
	sprite.texture = definition.texture
	sprite.centered = true
	sprite.top_level = true
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.no_depth_test = false
	sprite.pixel_size = pixel_size

	# Use material with render_priority (NEW - same as spawn_sticker)
	sprite.material_override = _painting_system_3d._get_or_create_material(definition.texture, order)

	# Add to canvas root
	_painting_system_3d.canvas_root.add_child(sprite)

	# Set transform
	sprite.global_position = Vector3(
		position_data.get("x", 0.0),
		position_data.get("y", 0.0),
		position_data.get("z", 0.0)
	)
	sprite.global_rotation = Vector3(
		rotation_data.get("x", 0.0),
		rotation_data.get("y", 0.0),
		rotation_data.get("z", 0.0)
	)

	# Create PlacedLayer tracking structure with surface key (NEW)
	var placed = PlacedLayer.new(sticker_id, sprite, order, 1.0, surface_key)
	placed.rotation_deg = rotation_deg
	_painting_system_3d.placed_layers.append(placed)

	# Add to spatial hash (NEW)
	_painting_system_3d._add_to_spatial_hash(placed)

	# Update surface_order_counters to prevent conflicts (NEW - fixed)
	if surface_key in _painting_system_3d.surface_order_counters:
		if order >= _painting_system_3d.surface_order_counters[surface_key]:
			_painting_system_3d.surface_order_counters[surface_key] = order + 1
	else:
		_painting_system_3d.surface_order_counters[surface_key] = order + 1

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

func _find_nail_component(nail: Node) -> Node:
	"""Find NailComponent in nail node hierarchy"""
	for child in nail.get_children():
		if child.has_method("accept_painting"):
			return child
	return null

func _find_hanging_component(painting: Node) -> Node:
	"""Find PaintingHangingComponent in painting node hierarchy"""
	for child in painting.get_children():
		if child.has_method("hang_on_nail"):
			return child
	return null

# ============================================================================
# PHASE 0: Economy Save/Load
# ============================================================================

func _save_economic_state() -> Dictionary:
	"""Save economy data to dictionary"""
	var economy_data = {}

	# Save money if EconomyManager exists
	if has_node("/root/EconomyManager"):
		economy_data["money"] = EconomyManager.get_money()

	# Save reputation if ReputationManager exists
	if has_node("/root/ReputationManager"):
		economy_data["reputation_level"] = ReputationManager.get_reputation_level()
		economy_data["reputation_points"] = ReputationManager.get_reputation_points()

	# Save recent paintings if StyleTracker exists
	if has_node("/root/StyleTracker"):
		economy_data["recent_paintings"] = StyleTracker.get_recent_paintings()

	return economy_data

func _load_economic_state(economy_data: Dictionary):
	"""Load economy data from dictionary"""
	# Load money if EconomyManager exists
	if has_node("/root/EconomyManager") and economy_data.has("money"):
		EconomyManager.set_money(economy_data["money"])
		print("Loaded economy: $%d" % economy_data["money"])

	# Load reputation if ReputationManager exists
	if has_node("/root/ReputationManager"):
		var rep_level = economy_data.get("reputation_level", 0)
		var rep_points = economy_data.get("reputation_points", 0.0)
		ReputationManager.set_reputation(rep_points, rep_level)
		print("Loaded reputation: Level %d (%.1f points)" % [rep_level, rep_points])

	# Load recent paintings if StyleTracker exists
	if has_node("/root/StyleTracker") and economy_data.has("recent_paintings"):
		StyleTracker.set_recent_paintings(economy_data["recent_paintings"])
		print("Loaded painting history: %d paintings" % economy_data["recent_paintings"].size())
