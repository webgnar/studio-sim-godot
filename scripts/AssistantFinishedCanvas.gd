extends Node3D
class_name AssistantFinishedCanvas

## Interactive canvas in the gallery room.
## The assistant's transferred sticker work overlays whatever is already on the canvas.
## The player can add their own stickers on top, then convert to a CarryablePainting5x3.
## Each transfer flattens the current state and overlays the new work on top.

@onready var canvas_plane: MeshInstance3D = $CanvasPlane
@onready var canvas_viewport: SubViewport = $CanvasViewport
@onready var background_sprite: Sprite2D = $CanvasViewport/CanvasRoot/BackgroundSprite
@onready var painting_system: PaintingSystem2D = $CanvasViewport/CanvasRoot

## Matches PaintingRoot2D interface so PaintingSpawner can treat this as a painting root
var plane_width: float = 5.0
var plane_height: float = 3.0

const SAVE_PATH := "user://assistant_canvas.png"
const VIEWPORT_SIZE := Vector2(1700, 1020)

var _background_image: Image = null


func _ready() -> void:
	painting_system.plane_width = plane_width
	painting_system.plane_height = plane_height
	painting_system.sticker_scale = 0.5
	painting_system.preview_fade_delay = 2.0
	painting_system.preview_fade_speed = 3.0
	painting_system.preview_base_opacity = 0.5
	painting_system.preview_target_opacity = 0.5
	painting_system.preview_rotation = 0.0
	if painting_system.preview_sprite:
		painting_system.preview_sprite.modulate.a = 0.5
		painting_system.preview_sprite.rotation_degrees = 0.0
	painting_system._update_preview_texture()
	PaintingModeManager.register_extra_2d_system(painting_system)

	# Load persisted background PNG into BackgroundSprite
	if FileAccess.file_exists(SAVE_PATH):
		var image := Image.new()
		if image.load(SAVE_PATH) == OK:
			_set_background_image(image)

	# Gate visibility behind assistant purchase
	_set_canvas_active(AutomationManager.is_assistant_active())
	AutomationManager.assistant_purchased.connect(_on_assistant_purchased)


func set_background_composite(new_image: Image) -> void:
	"""Transfer new assistant work on top of the current canvas state.

	Flow:
	1. Bake the current viewport (captures player stickers + any prior background)
	2. Blend new_image ON TOP of the baked state
	3. Set the flattened result as BackgroundSprite
	4. Clear player sticker Sprite2D nodes (they are now baked in)
	5. Save to disk
	"""
	if painting_system.placed_layers.is_empty() and _background_image == null:
		# Nothing on canvas yet — set new work directly as background
		_set_background_image(_scale_to_viewport(new_image))
		_do_save()
		return

	# Capture current viewport (UPDATE_ALWAYS mode, just wait for next frame)
	await RenderingServer.frame_post_draw

	var current_bake: Image = canvas_viewport.get_texture().get_image()

	# Blend new assistant work on top of the current baked state
	var scaled := _scale_to_viewport(new_image)
	if current_bake:
		current_bake.blend_rect(scaled,
			Rect2i(0, 0, scaled.get_width(), scaled.get_height()),
			Vector2i(0, 0))
	else:
		current_bake = scaled

	# Flatten: set composite as background, clear floating stickers
	_set_background_image(current_bake)
	painting_system.clear_canvas()
	_do_save()


func save_to_disk() -> void:
	"""Called by WorldStateManager — bakes viewport and persists to disk."""
	if _background_image == null and painting_system.placed_layers.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image = canvas_viewport.get_texture().get_image()
	if image:
		image.save_png(SAVE_PATH)


func reset_canvas() -> void:
	"""Called after converting to CarryablePainting — clears everything for next session."""
	painting_system.clear_canvas()
	_background_image = null
	background_sprite.texture = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func has_content() -> bool:
	return _background_image != null or not painting_system.placed_layers.is_empty()


func _on_assistant_purchased() -> void:
	_set_canvas_active(true)


func _set_canvas_active(active: bool) -> void:
	canvas_plane.visible = active
	$stretcher.visible = active
	$CanvasPlane/StaticBody3D.collision_layer = 4 if active else 0


# --- Private helpers ---

func _set_background_image(image: Image) -> void:
	_background_image = image
	background_sprite.texture = ImageTexture.create_from_image(image)
	# Scale sprite to fill the viewport regardless of source image resolution
	var img_size := Vector2(image.get_width(), image.get_height())
	background_sprite.scale = VIEWPORT_SIZE / img_size


func _scale_to_viewport(image: Image) -> Image:
	var w := int(VIEWPORT_SIZE.x)
	var h := int(VIEWPORT_SIZE.y)
	if image.get_width() == w and image.get_height() == h:
		return image
	var copy := image.duplicate()
	copy.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return copy


func _do_save() -> void:
	if _background_image:
		_background_image.save_png(SAVE_PATH)
