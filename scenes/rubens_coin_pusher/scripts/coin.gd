extends RigidBody3D

var _sound: AudioStreamPlayer3D
var _coin_sound = preload("res://scenes/rubens_coin_pusher/coins_single_02.wav")
var _cooldown: float = 0.0

func _ready():
	add_to_group("coins")
	contact_monitor = true
	max_contacts_reported = 1
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = _coin_sound
	_sound.volume_db = -10.0
	_sound.max_distance = 5.0
	_sound.bus = "SFX"
	add_child(_sound)
	body_entered.connect(_on_body_entered)

func get_radius() -> float:
	return $Col.shape.radius

func _on_body_entered(_body: Node):
	if _cooldown > 0.0:
		return
	if linear_velocity.length() < 0.3:
		return
	_sound.pitch_scale = randf_range(0.85, 1.15)
	_sound.play()
	_cooldown = 0.1

func _physics_process(delta):
	if _cooldown > 0.0:
		_cooldown -= delta
	# "Fell through the floor" cleanup, relative to the machine's own position —
	# not a hardcoded world Y. The machine can be (and has been) moved anywhere
	# in the world, so an absolute world-space threshold would delete every coin
	# immediately if the machine sits low in world coordinates (as it now does).
	if GameManager.main_scene and global_position.y < GameManager.main_scene.global_position.y - 5:
		queue_free()
