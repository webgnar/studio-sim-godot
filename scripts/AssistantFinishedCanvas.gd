extends Node3D
class_name AssistantFinishedCanvas

## Static display canvas in the adjacent room.
## Shows the baked output of the studio assistant's sticker wall.
## Persists across sessions by loading user://assistant_canvas.png on ready.

@onready var canvas_plane: MeshInstance3D = $CanvasPlane

const SAVE_PATH := "user://assistant_canvas.png"

var _current_image: Image = null


func _ready() -> void:
	canvas_plane.visible = false
	if FileAccess.file_exists(SAVE_PATH):
		var image := Image.new()
		if image.load(SAVE_PATH) == OK:
			display_painting(image)


func display_painting(image: Image) -> void:
	"""Apply a baked Image as the canvas plane's texture with alpha transparency."""
	_current_image = image
	var texture := ImageTexture.create_from_image(image)
	var mat := StandardMaterial3D.new()
	mat.flags_unshaded = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = texture
	canvas_plane.set_surface_override_material(0, mat)
	canvas_plane.visible = true


func save_to_disk() -> void:
	"""Called by WorldStateManager.save_world_state() to persist the canvas PNG."""
	if _current_image:
		_current_image.save_png(SAVE_PATH)
