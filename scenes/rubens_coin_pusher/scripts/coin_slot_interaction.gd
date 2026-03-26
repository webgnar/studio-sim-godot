extends StaticBody3D

var interaction_text: String = "Insert $1"
var _coin_sound: AudioStreamPlayer3D
var _coin_mesh: MeshInstance3D

func _ready():
	_coin_sound = AudioStreamPlayer3D.new()
	_coin_sound.stream = preload("res://scenes/rubens_coin_pusher/coins_single_02.wav")
	_coin_sound.volume_db = -5.0
	_coin_sound.max_distance = 8.0
	add_child(_coin_sound)

	# Create a reusable coin mesh for the insert animation
	_coin_mesh = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = 0.01
	_coin_mesh.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.75, 0.2)
	mat.metallic = 0.8
	mat.roughness = 0.3
	_coin_mesh.material_override = mat
	_coin_mesh.visible = false
	add_child(_coin_mesh)

func interact(_interactor) -> void:
	if GameManager.try_insert_dollar():
		_coin_sound.pitch_scale = randf_range(0.9, 1.1)
		_coin_sound.play()
		_animate_coin_insert()

func _animate_coin_insert() -> void:
	_coin_mesh.position = Vector3(0, 0.12, 0.03)
	_coin_mesh.rotation = Vector3(PI / 2, 0, 0)
	_coin_mesh.visible = true

	var tween = create_tween()
	tween.tween_property(_coin_mesh, "position", Vector3(0, 0, 0), 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): _coin_mesh.visible = false)
