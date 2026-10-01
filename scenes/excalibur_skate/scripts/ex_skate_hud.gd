class_name ExSkateHud
extends CanvasLayer
## Score readout (top-left) and POP double-jump meter (top-right).

var _score_value: Label
var _score_prefix: Label
var _meter: ExSkateJumpMeter


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)

	_score_prefix = ExSkateUI.make_label("Score: ", 32, Color.WHITE, 4)
	_score_prefix.position = Vector2(50, 50)
	root.add_child(_score_prefix)
	_score_value = ExSkateUI.make_label("0", 32, ExSkateUI.LIME, 4)
	root.add_child(_score_value)
	_place_score()

	_meter = ExSkateJumpMeter.new()
	_meter.position = Vector2(750, 50) - ExSkateJumpMeter.SIZE / 2.0
	root.add_child(_meter)


func set_score(value: int) -> void:
	_score_value.text = str(value)


func update(dt: float, jumps_available: float) -> void:
	_meter.update(dt, jumps_available)


func reset(jumps_available: float) -> void:
	set_score(0)
	_meter.snap(jumps_available)


func _place_score() -> void:
	_score_prefix.reset_size()
	_score_value.position = _score_prefix.position + Vector2(_score_prefix.size.x, 0)
