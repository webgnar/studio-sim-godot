extends Camera3D
class_name SkateboardCamera

## Side-scroll follow camera for skateboard mode. Position tracks the
## player's real global_position (so 3D collision drift still reads
## correctly); orientation is what's actually locked, always facing
## perpendicular to the ride axis via look_at().

@export var side_offset: float = 10.0
@export var height_offset: float = 1.5
@export var follow_smoothing: float = 5.0

var _target: Node3D
var _side_dir: Vector3 = Vector3.RIGHT

func begin_follow(player: Node3D, ride_axis: Vector3) -> void:
	_target = player
	_side_dir = ride_axis.cross(Vector3.UP).normalized()
	global_position = player.global_position + _side_dir * side_offset + Vector3.UP * height_offset
	look_at(player.global_position, Vector3.UP)

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var desired := _target.global_position + _side_dir * side_offset + Vector3.UP * height_offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_smoothing * delta))
	look_at(_target.global_position + Vector3.UP * height_offset * 0.5, Vector3.UP)
