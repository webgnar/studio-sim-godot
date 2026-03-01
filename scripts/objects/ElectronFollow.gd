extends PathFollow3D

# speed in full loops per second (0.5 = one loop every 2s)
@export var speed := 0.5

var _base_ratio := 0.0

func _process(delta: float) -> void:
	_base_ratio += speed * delta
	progress_ratio = fmod(_base_ratio, 1.0) + sin(Time.get_ticks_msec() * 0.01) * 0.002
