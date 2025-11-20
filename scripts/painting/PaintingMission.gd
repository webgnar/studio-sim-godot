extends Resource
class_name PaintingMission

## Represents a painting mission/challenge for the player to complete

@export var mission_id: String = ""
@export var target_layers: Array[PaintingLayerDefinition] = []  # Ordered from back to front
@export var reward: int = 100
@export var difficulty: int = 1

# Helper to get list of required sticker IDs
func get_required_stickers() -> Array[String]:
	var sticker_ids: Array[String] = []
	for layer in target_layers:
		if not sticker_ids.has(layer.id):
			sticker_ids.append(layer.id)
	return sticker_ids

func _init(p_id: String = "", p_reward: int = 100):
	mission_id = p_id
	reward = p_reward
	target_layers = []
