extends Node3D
class_name StickerWallManager

## Procedural sticker wall for the Studio Assistant room.
## The assistant paints here the way the idle autoplay bot paints its studio
## paintings (AutoplayPainter, see "The studio assistant" there): one sticker
## every sticker_interval seconds, round after round of making shapes and
## defining the forms that come out of them. It never finishes on its own;
## the player decides when it's done by transferring the work.
## Use wall_id to differentiate multiple instances — each saves independently.

## The Psy Wheel in the assistant's studio switches its painting style
## (AutomationManager.ASSISTANT_STYLES), even mid-painting: the new style
## picks up from whatever is on the wall.

const MARGIN = 40.0  # px from canvas edge (random style)
const FLATTEN_KEEP := 3  # newest stickers left as sprites when the wall is flattened, so an undo still works

## Unique ID for this wall's save file. Change per-instance for multiple walls.
@export var wall_id: String = "wall_a"
## How often a new sticker appears (seconds), with no gallery visitors.
@export var sticker_interval: float = 6.0
## Each gallery visitor the player has bought speeds the assistant up by
## this share of its base pace: interval = sticker_interval / (1 + visitors x
## this). At 0.5: 1 visitor 4 s, 2 visitors 3 s, 4 visitors 2 s (0 = visitors
## don't change the pace) (zack 2026-11-04).
@export var visitor_speedup: float = 0.5
## Once this many stickers are on the wall as separate sprites, they're
## flattened into one image under the new ones, so redrawing the wall costs
## the same however long the assistant paints or however fast it goes
## (zack 2026-11-04). 0 = never flatten.
@export var flatten_after: int = 300
## The fastest the assistant will go, however many visitors (seconds).
@export var fastest_interval: float = 0.25
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
var _painter_style := ""   # the style the painter was started in
var _warmed := 0           # stickers the painter has looked at (see AutoplayPainter.warm_up)
var _planning := -1        # worker thread task planning the next round
var _flat: Sprite2D        # everything flattened so far, drawn under the live sprites
var _live := 0             # stickers on the wall as their own sprites (not yet flattened)
var _flattening := false
var _clears := 0           # times the wall was cleared (a flatten that spans one is dropped)


func _ready():
	# Wire the SubViewport texture to the wall mesh material at runtime
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = sub_viewport.get_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall_plane.set_surface_override_material(0, mat)

	add_to_group("sticker_wall_managers")

	# The Psy Wheel next to the wall switches the painting style
	var wheel := get_node_or_null("../Psywheel")
	if wheel:
		wheel.add_child.call_deferred(AssistantStyleWheel.new())

	# Restore saved stickers from lightweight file (fast, avoids world state parse)
	var saved = _load_stickers_from_file()
	for data in saved:
		_sprites.append(_spawn_sticker_sprite(data))
	_placements = saved.duplicate(true)
	_live = _sprites.size()
	_maybe_flatten.call_deferred()

	# Start the interval timer — only if Studio Assistant is already active
	_timer = Timer.new()
	_timer.wait_time = _current_interval()
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


func _current_interval() -> float:
	"""Seconds between stickers: faster the more gallery visitors there are."""
	var visitors := 0
	if has_node("/root/WorldStateManager"):
		visitors = WorldStateManager.get_gallery_visitor_count()
	return maxf(sticker_interval / (1.0 + visitors * visitor_speedup), fastest_interval)


func _on_timer_timeout() -> void:
	_timer.wait_time = _current_interval()   # a visitor bought since the last sticker counts at once
	if _flattening:
		return
	if not has_node("/root/StickerLibrary"):
		return

	var library: Array = StickerLibrary.sticker_library
	if library.is_empty():
		return

	var style := _style()
	if style == "random":
		_place_random(library)
		_painter_ready = false   # back in a bot style, it picks up from what's on the wall
		return
	if _painter_ready and style != _painter_style:
		_painter_ready = false
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
			if sprite:   # (a flattened sticker stays: it's part of the image now)
				sprite.queue_free()
				_live -= 1
	else:
		var data := _stamp_to_data(stroke)
		_sprites.append(_spawn_sticker_sprite(data))
		_placements.append(data)
		_live += 1

	# Force viewport update so the new sticker renders
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_maybe_flatten()


func _maybe_flatten() -> void:
	"""Flatten the wall into one image once there are flatten_after live sprites."""
	if flatten_after > 0 and _live >= flatten_after and not _flattening and is_inside_tree():
		_flatten()


func _flatten() -> void:
	"""Render the wall, keep the picture as one image under everything, and
	drop the sprites it holds. The placements stay, so the painter still
	knows what's there and the save still has every sticker."""
	_flattening = true
	# The newest few stay sprites: the assistant takes a mistake back with
	# the very next stroke, so the last sticker must still be removable
	var keep: Array[Sprite2D] = []
	for k in range(_sprites.size() - 1, -1, -1):
		if keep.size() >= FLATTEN_KEEP:
			break
		if _sprites[k]:
			keep.append(_sprites[k])
			_sprites[k].visible = false
	var clears := _clears
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if clears != _clears:   # transferred meanwhile: the picture is gone
		_flattening = false
		return
	for sprite in keep:
		if is_instance_valid(sprite):
			sprite.visible = true
	var image := sub_viewport.get_texture().get_image()
	if image and not image.is_empty():
		if not is_instance_valid(_flat):
			_flat = Sprite2D.new()
			_flat.centered = false
			var blend := CanvasItemMaterial.new()
			blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA   # the viewport holds premultiplied colour
			_flat.material = blend
			sticker_canvas.add_child(_flat)
		sticker_canvas.move_child(_flat, 0)
		_flat.scale = canvas_size / Vector2(image.get_size())
		_flat.texture = ImageTexture.create_from_image(image)
		for k in _sprites.size():
			if _sprites[k] and not _sprites[k] in keep:
				_sprites[k].queue_free()
				_sprites[k] = null
		_live = keep.size()
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_flattening = false


func _style() -> String:
	return AutomationManager.assistant_style if has_node("/root/AutomationManager") else "studio"


func _place_random(library: Array) -> void:
	var data = {
		"idx": randi() % library.size(),
		"x": randf_range(MARGIN, canvas_size.x - MARGIN),
		"y": randf_range(MARGIN, canvas_size.y - MARGIN),
		"rotation": randf_range(-PI, PI),
		"scale": randf_range(0.15, 0.45),
	}
	_sprites.append(_spawn_sticker_sprite(data))
	_placements.append(data)
	_live += 1
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_maybe_flatten()


func _process(_delta: float) -> void:
	if _planning >= 0 and WorkerThreadPool.is_task_completed(_planning):
		WorkerThreadPool.wait_for_task_completion(_planning)
		_planning = -1
	# One sticker a frame, so looking at them all never stalls a frame
	if _style() != "random" and not _timer.is_stopped() and has_node("/root/StickerLibrary") and _warmed < StickerLibrary.sticker_library.size():
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
	_painter_style = _style()
	_painter.begin_assistant(canvas_size.y / canvas_size.x, placed, _painter_style)
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
	_live = 0
	_flat = null   # freed with the other children
	_clears += 1
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
