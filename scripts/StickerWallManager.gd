extends Node3D

## Procedural sticker wall for the Studio Assistant room.
## Spawns a new sticker on the canvas every sticker_interval seconds.
## Sticker placements are saved persistently via WorldStateManager.

const SAVE_KEY = "sticker_wall_placements"
const CANVAS_SIZE = Vector2(512, 512)
const MARGIN = 40.0  # px from canvas edge

@export var sticker_interval: float = 6.0

@onready var sticker_canvas: Node2D = $SubViewport/StickerCanvas
@onready var sub_viewport: SubViewport = $SubViewport
@onready var wall_plane: MeshInstance3D = $WallPlane

var _placements: Array = []
var _timer: Timer


func _ready():
	# Wire the SubViewport texture to the wall mesh material at runtime
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = sub_viewport.get_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall_plane.set_surface_override_material(0, mat)

	# Restore saved stickers from lightweight file (fast, avoids world state parse)
	var saved = _load_stickers_from_file()
	for data in saved:
		_spawn_sticker_sprite(data)
	_placements = saved.duplicate(true)

	# Start the interval timer
	_timer = Timer.new()
	_timer.wait_time = sticker_interval
	_timer.autostart = true
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func _on_timer_timeout() -> void:
	if not has_node("/root/StickerLibrary"):
		return

	var library: Array = StickerLibrary.sticker_library
	if library.is_empty():
		return

	var idx = randi() % library.size()
	var x = randf_range(MARGIN, CANVAS_SIZE.x - MARGIN)
	var y = randf_range(MARGIN, CANVAS_SIZE.y - MARGIN)
	var rot = randf_range(-PI, PI)
	var scl = randf_range(0.15, 0.45)

	var data = {"idx": idx, "x": x, "y": y, "rotation": rot, "scale": scl}
	_spawn_sticker_sprite(data)
	_placements.append(data)

	# Persist sticker data only (avoid full world save every 6s)
	if has_node("/root/WorldStateManager"):
		WorldStateManager.set_data(SAVE_KEY, _placements.duplicate(true))
		_save_stickers_only()

	# Force viewport update so the new sticker renders
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _save_stickers_only() -> void:
	"""Write just the sticker placement array to a lightweight JSON file, not the full world save."""
	var path = "user://sticker_wall.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_placements))
		file.close()


func _load_stickers_from_file() -> Array:
	"""Load sticker placements from the lightweight file, fallback to WorldStateManager misc_data."""
	var path = "user://sticker_wall.json"
	if not FileAccess.file_exists(path):
		return []
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return []
	var text = file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	if result is Array:
		return result
	return []


func _spawn_sticker_sprite(data: Dictionary) -> void:
	if not has_node("/root/StickerLibrary"):
		return

	var library: Array = StickerLibrary.sticker_library
	var idx: int = data.get("idx", 0)
	if idx < 0 or idx >= library.size():
		return

	var definition: PaintingLayerDefinition = library[idx]
	if not definition.texture:
		return

	var sprite = Sprite2D.new()
	sprite.texture = definition.texture
	sprite.position = Vector2(data.get("x", 256.0), data.get("y", 256.0))
	sprite.rotation = data.get("rotation", 0.0)
	var s: float = data.get("scale", 0.3)
	sprite.scale = Vector2(s, s)
	sticker_canvas.add_child(sprite)
