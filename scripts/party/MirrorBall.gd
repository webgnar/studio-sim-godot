extends Node3D
class_name MirrorBall
## Slowly spinning disco ball for the DJ dance party (the faceted sparkle is in
## shaders/mirror_ball.gdshader). Spins only while the party rig is processing.

@export var spin_speed_degrees: float = 25.0


func _process(delta: float) -> void:
	rotate_y(deg_to_rad(spin_speed_degrees) * delta)
