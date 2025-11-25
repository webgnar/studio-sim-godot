extends Resource
class_name PaintingLayerDefinition

## Represents a sticker type in the library
## This is the "definition" of a sticker that can be placed

@export var id: String = ""
@export var texture: Texture2D = null
@export var unlock_cost: int = 0
@export var unlocked: bool = false
@export var rarity: String = "common"  # common, rare, epic, legendary

func _init(p_id: String = "", p_texture: Texture2D = null, p_cost: int = 0):
	id = p_id
	texture = p_texture
	unlock_cost = p_cost
