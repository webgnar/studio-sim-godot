extends RefCounted
class_name PlacedLayer2D

## Represents a placed sticker layer in the 2D painting system
## Holds reference to the Sprite2D node and metadata

var id: String  # Sticker ID (matches library definition)
var node: Sprite2D  # The actual Sprite2D node in the scene
var rotation_deg: float = 0.0  # Current rotation in degrees
var scale_multiplier: float = 1.0  # Scale multiplier applied to this sticker

func _init(p_id: String, p_node: Sprite2D):
	id = p_id
	node = p_node
