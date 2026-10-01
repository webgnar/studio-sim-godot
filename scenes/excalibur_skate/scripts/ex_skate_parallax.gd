class_name ExSkateParallax
extends Node2D
## Five horizontally-tiling background layers (port of parallax-manager.ts).
## Each layer is a texture strip kept just left of the camera, offset by
## camera_x * factor so nearer layers scroll faster.

const SEGMENT_WIDTH := 800.0
const HALF_SCREEN := 400.0

# [texture, parallax factor, world y, z]
var _layers: Array = []


func _ready() -> void:
	var configs := [
		[ExSkateAssets.BG_SKY, 0.05, -400.0, -50],
		[ExSkateAssets.BG_FAR_MOUNTAINS, 0.15, 250.0, -40],
		[ExSkateAssets.BG_MID_HILLS, 0.35, 300.0, -30],
		[ExSkateAssets.BG_NEAR_TREES, 0.65, 350.0, -20],
		[ExSkateAssets.BG_FOREGROUND, 0.85, 500.0, -10],
	]
	for config: Array in configs:
		var tex: Texture2D = config[0]
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, SEGMENT_WIDTH * 4.0, tex.get_height())
		sprite.position.y = config[2]
		sprite.z_index = config[3]
		add_child(sprite)
		_layers.append({"sprite": sprite, "factor": config[1]})
	update(200.0)


func update(camera_x: float) -> void:
	for layer: Dictionary in _layers:
		var sprite: Sprite2D = layer["sprite"]
		var scroll := fmod(camera_x * float(layer["factor"]), SEGMENT_WIDTH)
		sprite.position.x = camera_x - HALF_SCREEN - scroll
