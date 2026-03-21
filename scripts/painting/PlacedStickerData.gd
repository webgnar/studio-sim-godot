extends Resource
class_name PlacedStickerData

## Stores complete placement information for a single sticker in a mission
## Used to capture exact position, rotation, and layering for validation

@export var sticker_id: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var rotation_deg: float = 0.0
@export var scale: float = 1.0

func _init(p_sticker_id: String = "", p_position: Vector2 = Vector2.ZERO, p_rotation: float = 0.0):
	sticker_id = p_sticker_id
	position = p_position
	rotation_deg = p_rotation
	scale = 1.0

# matches() function removed - no longer needed for simplified validation system
