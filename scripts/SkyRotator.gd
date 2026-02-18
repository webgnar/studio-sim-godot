extends WorldEnvironment

@export var rotation_speed: float = 0.05  # radians per second

func _process(delta: float) -> void:
	environment.sky_rotation.y += rotation_speed * delta
