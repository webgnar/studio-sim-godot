extends RigidBody3D

var _spawn_position: Vector3
var _spawn_rotation: Basis

func _ready() -> void:
	add_to_group("respawnable")
	_spawn_position = global_position
	_spawn_rotation = global_basis

func respawn() -> void:
	# Unfreeze if floor-frozen
	freeze = false
	# Reset physics state
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# Return to original position and rotation
	global_position = _spawn_position
	global_basis = _spawn_rotation
