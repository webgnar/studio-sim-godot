extends MeshInstance3D

@export var mirror_resolution: Vector2i = Vector2i(512, 512)

@onready var dummy_cam = $DummyCam
@onready var mirror_cam = $SubViewport/Camera3D

func _ready():
	add_to_group("mirrors")
	$SubViewport.size = Vector2(mirror_resolution.x, mirror_resolution.y)
	$SubViewport.own_world_3d = true
	$SubViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func update_cam(main_cam_transform):
	# Flip the mirror's Y scale to invert the transform
	scale.y *= -1
	# Apply the main camera's transform to the dummy cam
	dummy_cam.global_transform = main_cam_transform
	# Revert the mirror's Y scale
	scale.y *= -1
	# Apply the dummy cam's transform to the mirror cam
	mirror_cam.global_transform = dummy_cam.global_transform
	# Flip the X basis to correct the reflection
	mirror_cam.global_transform.basis.x *= -1
