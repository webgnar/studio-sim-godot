extends AnimatableBody3D

var push_speed: float = 0.12
var push_distance: float = 0.15
var start_z: float
var direction: float = 1.0

func _ready():
	start_z = position.z

func _physics_process(delta):
	position.z += push_speed * direction * delta
	if position.z > start_z + push_distance:
		direction = -1.0
	elif position.z < start_z:
		direction = 1.0
