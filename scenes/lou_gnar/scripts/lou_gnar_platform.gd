class_name LouGnarPlatform
extends Node2D
## Solid building. Origin is the top-left corner (landing surface = position.y).

const TILE_STEP := 32 # tiles are 36px but laid out on a 32px pitch (later tiles overlap), as in the original

var building_width: float = 300.0
var building_height: float = 100.0
var _tile: Texture2D


func setup(x: float, y: float, width: float, height: float) -> void:
	position = Vector2(x, y)
	building_width = width
	building_height = height
	_tile = LouGnarAssets.BUILDING_TILES[randi() % LouGnarAssets.BUILDING_TILES.size()]
	queue_redraw()


func _draw() -> void:
	if _tile == null:
		return
	var tile_size := _tile.get_size()
	var y := 0.0
	while y < building_height:
		var x := 0.0
		while x < building_width:
			# Clip to the building rectangle like the original canvas did.
			var w := minf(tile_size.x, building_width - x)
			var h := minf(tile_size.y, building_height - y)
			draw_texture_rect_region(_tile, Rect2(x, y, w, h), Rect2(0, 0, w, h))
			x += TILE_STEP
		y += TILE_STEP
