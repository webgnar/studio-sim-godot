class_name LouGnarCoin
extends Node2D
## Collectible flower/coin: 6-frame spinner that sways +-15 degrees.

const RADIUS := 15.0
const FRAME_TIME := 0.1

var collected: bool = false
var _sprite: Sprite2D
var _time: float = 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = LouGnarAssets.SHEET_COIN
	_sprite.hframes = 6
	add_child(_sprite)
	# 0 -> +15 -> -15 -> 0, one second per leg, forever.
	var tilt := deg_to_rad(15.0)
	var tween := create_tween().set_loops()
	tween.tween_property(self, "rotation", tilt, 1.0)
	tween.tween_property(self, "rotation", -tilt, 1.0)
	tween.tween_property(self, "rotation", 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_sprite.frame = int(_time / FRAME_TIME) % 6


func check_collection(player_bounds: Rect2) -> bool:
	if collected:
		return false
	var coin_bounds := Rect2(position - Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0)
	if player_bounds.intersects(coin_bounds):
		collected = true
		visible = false
		return true
	return false
