extends RefCounted
class_name PlacedLayer

## Represents an instance of a sticker placed on the canvas
## Tracks the 3D node, its order, and transform data

var id: String = ""
var node: Sprite3D = null
var order: int = 0
var rotation_deg: float = 0.0
var scale_multiplier: float = 1.0  # Store the scale used when placing
var surface_key: String = ""  # Which surface this sticker is placed on

func _init(p_id: String = "", p_node: Sprite3D = null, p_order: int = 0, p_scale: float = 1.0, p_surface: String = ""):
	id = p_id
	node = p_node
	order = p_order
	rotation_deg = 0.0
	scale_multiplier = p_scale
	surface_key = p_surface
