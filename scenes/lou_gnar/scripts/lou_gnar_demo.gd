extends Control
## F6 test harness: shows LouGnar in a window at 1.5x.

const SCALE := 1.5

@onready var _container: SubViewportContainer = $SubViewportContainer


func _ready() -> void:
	_container.scale = Vector2(SCALE, SCALE)
	var window_size := get_viewport_rect().size
	_container.position = (window_size - Vector2(LouGnarGame.SCREEN_SIZE) * SCALE) / 2.0
