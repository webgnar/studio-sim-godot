extends Node3D
class_name StickerWallManager

## Procedural sticker wall for the Studio Assistant room.
## Spawns a new sticker on the canvas every sticker_interval seconds.
## Use wall_id to differentiate multiple instances — each saves independently.

const MARGIN = 40.0  # px from canvas edge

## Unique ID for this wall's save file. Change per-instance for multiple walls.
@export var wall_id: String = "wall_a"
## How often a new sticker appears (seconds).
@export var sticker_interval: float = 6.0
## Canvas resolution. Match this to your SubViewport size.
@export var canvas_size: Vector2 = Vector2(512, 512)

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

	add_to_group("sticker_wall_managers")

	# Restore saved stickers from lightweight file (fast, avoids world state parse)
	var saved = _load_stickers_from_file()
	for data in saved:
		_spawn_sticker_sprite(data)
	_placements = saved.duplicate(true)

	# Start the interval timer — only if Studio Assistant is already active
	_timer = Timer.new()
	_timer.wait_time = sticker_interval
	_timer.autostart = false
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	if has_node("/root/AutomationManager"):
		if AutomationManager.is_assistant_active():
			_timer.start()
		else:
			AutomationManager.assistant_purchased.connect(_on_assistant_purchased)


func _on_assistant_purchased() -> void:
	_timer.start()


func _on_timer_timeout() -> void:
	if not has_node("/root/StickerLibrary"):
		return

	var library: Array = StickerLibrary.sticker_library
	if library.is_empty():
		return

	var idx = randi() % library.size()
	var x = randf_range(MARGIN, canvas_size.x - MARGIN)
	var y = randf_range(MARGIN, canvas_size.y - MARGIN)
	var rot = randf_range(-PI, PI)
	var scl = randf_range(0.15, 0.45)

	var data = {"idx": idx, "x": x, "y": y, "rotation": rot, "scale": scl}
	_spawn_sticker_sprite(data)
	_placements.append(data)

	# Force viewport update so the new sticker renders
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _save_file_path() -> String:
	return "user://sticker_wall_%s.json" % wall_id


func _save_stickers_only() -> void:
	var file = FileAccess.open(_save_file_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_placements))
		file.close()


func _load_stickers_from_file() -> Array:
	var path = _save_file_path()
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


func has_stickers() -> bool:
	"""Returns true if any stickers have been placed on this wall."""
	return not _placements.is_empty()


func bake_to_image() -> Image:
	"""Capture the current SubViewport contents as an Image. Awaits one frame to ensure render."""
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	return sub_viewport.get_texture().get_image()


func clear_stickers() -> void:
	"""Remove all stickers from the wall and persist the empty state."""
	_placements.clear()
	for child in sticker_canvas.get_children():
		child.queue_free()
	_save_stickers_only()
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


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
