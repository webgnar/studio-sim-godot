extends Node3D
class_name StickerWallManager

## Procedural sticker wall for the Studio Assistant room.
## The assistant paints here the way the idle autoplay bot paints its studio
## paintings (AutoplayPainter, see "The studio assistant" there): one sticker
## every sticker_interval seconds, round after round of making shapes and
## defining the forms that come out of them. It never finishes on its own;
## the player decides when it's done by transferring the work.
## Use wall_id to differentiate multiple instances — each saves independently.

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
var _sprites: Array = []   # one per placement (null if its sticker is missing)
var _timer: Timer
var _painter := AutoplayPainter.new()
var _painter_ready := false
var _warmed := 0           # stickers the painter has looked at (see AutoplayPainter.warm_up)
var _planning := -1        # worker thread task planning the next round


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
		_sprites.append(_spawn_sticker_sprite(data))
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

	if _warmed < library.size() or _planning >= 0:
		return   # still looking at the stickers, or thinking about the next round
	if not _painter_ready:
		_begin_painting()
	if _painter.needs_round():
		# Think it over off the main thread; the next tick picks it up
		_planning = WorkerThreadPool.add_task(_painter.plan_round, false, "Assistant painting")
		return
	var stroke: Dictionary = _painter.assistant_stroke()
	if stroke.has("action"):
		# Taking the last sticker back off
		if not _placements.is_empty():
			_placements.pop_back()
			var sprite: Sprite2D = _sprites.pop_back()
			if sprite:
				sprite.queue_free()
	else:
		var data := _stamp_to_data(stroke)
		_sprites.append(_spawn_sticker_sprite(data))
		_placements.append(data)

	# Force viewport update so the new sticker renders
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(_delta: float) -> void:
	if _planning >= 0 and WorkerThreadPool.is_task_completed(_planning):
		WorkerThreadPool.wait_for_task_completion(_planning)
		_planning = -1
	# One sticker a frame, so looking at them all never stalls a frame
	if not _timer.is_stopped() and has_node("/root/StickerLibrary") and _warmed < StickerLibrary.sticker_library.size():
		_painter.warm_up(_warmed)
		_warmed += 1


func _exit_tree() -> void:
	if _planning >= 0:
		WorkerThreadPool.wait_for_task_completion(_planning)
		_planning = -1


func _begin_painting() -> void:
	"""Hand the painter what's already on the wall, so it builds on it."""
	var placed: Array[Dictionary] = []
	for data in _placements:
		var stamp := _data_to_stamp(data)
		if not stamp.is_empty():
			placed.append(stamp)
	_painter.begin_assistant(canvas_size.y / canvas_size.x, placed)
	_painter_ready = true


func _stamp_to_data(stamp: Dictionary) -> Dictionary:
	"""A painter stamp (viewer space: 0..1 across and down, degrees clockwise,
	longest side in canvas widths) as a saved placement in canvas pixels."""
	var tex := _texture_size(stamp.sticker)
	return {
		"idx": stamp.sticker,
		"x": stamp.pos.x * canvas_size.x,
		"y": stamp.pos.y * canvas_size.y,
		"rotation": deg_to_rad(stamp.rot),
		"scale": stamp.size * canvas_size.x / maxf(tex.x, tex.y),
	}


func _data_to_stamp(data: Dictionary) -> Dictionary:
	var idx: int = data.get("idx", -1)
	if idx < 0 or idx >= StickerLibrary.sticker_library.size():
		return {}
	var tex := _texture_size(idx)
	return {
		"sticker": idx,
		"pos": Vector2(data.get("x", 0.0) / canvas_size.x, data.get("y", 0.0) / canvas_size.y),
		"rot": rad_to_deg(data.get("rotation", 0.0)),
		"size": data.get("scale", 0.3) * maxf(tex.x, tex.y) / canvas_size.x,
		"ponder": false, "precise": false,
	}


func _texture_size(idx: int) -> Vector2:
	var definition: PaintingLayerDefinition = StickerLibrary.sticker_library[idx]
	return definition.texture.get_size() if definition.texture else Vector2.ONE


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
	_sprites.clear()
	for child in sticker_canvas.get_children():
		child.queue_free()
	_save_stickers_only()
	if _planning >= 0:
		WorkerThreadPool.wait_for_task_completion(_planning)
		_planning = -1
	_painter_ready = false   # the next sticker starts a new painting
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _spawn_sticker_sprite(data: Dictionary) -> Sprite2D:
	if not has_node("/root/StickerLibrary"):
		return null

	var library: Array = StickerLibrary.sticker_library
	var idx: int = data.get("idx", 0)
	if idx < 0 or idx >= library.size():
		return null

	var definition: PaintingLayerDefinition = library[idx]
	if not definition.texture:
		return null

	var sprite = Sprite2D.new()
	sprite.texture = definition.texture
	sprite.position = Vector2(data.get("x", 256.0), data.get("y", 256.0))
	sprite.rotation = data.get("rotation", 0.0)
	var s: float = data.get("scale", 0.3)
	sprite.scale = Vector2(s, s)
	sticker_canvas.add_child(sprite)
	return sprite
