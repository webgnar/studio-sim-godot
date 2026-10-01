class_name LouGnarUfo
extends Node2D
## Hovering UFO. Origin is bottom-centre; stompable from above.

const FRAME_TIME := 0.1
const HIT_WIDTH := 87.0
const HIT_HEIGHT := 35.0

var _sprite: Sprite2D
var _base_y: float = 0.0
var _time: float = 0.0
var _anim_time: float = 0.0


func setup(x: float, y: float) -> void:
	position = Vector2(x, y)
	_base_y = y
	_time = randf() * TAU


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = LouGnarAssets.SHEET_UFO
	_sprite.hframes = 9
	_sprite.centered = false
	_sprite.offset = Vector2(-29, -39) # 58x39 frame, bottom-centre anchored
	_sprite.scale = Vector2(1.5, 1.5)
	add_child(_sprite)


func _process(delta: float) -> void:
	_anim_time += delta
	_sprite.frame = int(_anim_time / FRAME_TIME) % 9
	_time += delta
	position.y = _base_y + sin(_time * PI * 1.5) * 10.0
