class_name ExSkateRail
extends Node2D
## Grindable rail. Origin is the bottom-left corner; the grind surface is
## position.y - rail_height.

const TILE_SIZE := 20.0

var rail_width: float = 300.0
var rail_height: float = 20.0


func setup(x: float, y: float, width: float) -> void:
	position = Vector2(x, y)
	rail_width = width
	queue_redraw()


func _draw() -> void:
	var top := -rail_height
	draw_texture(ExSkateAssets.RAIL_CAP_LEFT, Vector2(0, top))
	var x := TILE_SIZE
	while x < rail_width - TILE_SIZE:
		draw_texture(ExSkateAssets.RAIL_TILE, Vector2(x, top))
		x += TILE_SIZE
	draw_texture(ExSkateAssets.RAIL_CAP_RIGHT, Vector2(rail_width - TILE_SIZE, top))
