extends Resource
class_name PlacedStickerData

## Stores complete placement information for a single sticker in a mission
## Used to capture exact position, rotation, and layering for validation

@export var sticker_id: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var rotation_deg: float = 0.0
@export var scale: float = 1.0
@export var z_order: int = 0

func _init(p_sticker_id: String = "", p_position: Vector2 = Vector2.ZERO, p_rotation: float = 0.0, p_z_order: int = 0):
	sticker_id = p_sticker_id
	position = p_position
	rotation_deg = p_rotation
	scale = 1.0
	z_order = p_z_order

func matches(other: PlacedStickerData, position_tolerance: float, rotation_tolerance: float) -> float:
	"""Calculate how closely this placement matches another (0.0 to 1.0)"""
	if sticker_id != other.sticker_id:
		return 0.0  # Wrong sticker entirely

	# Calculate position difference
	var pos_diff = position.distance_to(other.position)
	var pos_score = clamp(1.0 - (pos_diff / position_tolerance), 0.0, 1.0)

	# Calculate rotation difference (handle wrapping)
	var rot_diff = abs(rotation_deg - other.rotation_deg)
	if rot_diff > 180.0:
		rot_diff = 360.0 - rot_diff
	var rot_score = clamp(1.0 - (rot_diff / rotation_tolerance), 0.0, 1.0)

	# Average the scores (could weight them differently if needed)
	return (pos_score + rot_score) / 2.0
