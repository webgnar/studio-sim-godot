extends Area3D

@export var spawn_position: Vector3 = Vector3(-0.947, 1.207, 12.446)
@export var watch_duration: float = 1.5

var _is_respawning: bool = false
var _death_camera: Camera3D
var _target_player: CharacterBody3D
var _death_sound: AudioStream = preload("res://sounds/die.ogg")

func _ready():
	body_entered.connect(_on_body_entered)
	set_process(false)

func _process(_delta):
	if _death_camera and _target_player:
		_death_camera.look_at(_target_player.global_position)

func _on_body_entered(body):
	if body.is_in_group("player") and not _is_respawning:
		_respawn(body)

func _respawn(player):
	_is_respawning = true
	_target_player = player

	# Play death sound
	var sfx = AudioStreamPlayer.new()
	sfx.stream = _death_sound
	sfx.bus = "SFX"
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	# Disable player input (gravity still applies)
	CameraManager.set_player_input(false)

	# Create a temp camera at the player's current eye position
	_death_camera = Camera3D.new()
	_death_camera.fov = CameraManager.player_camera.fov
	get_tree().root.add_child(_death_camera)
	_death_camera.global_transform = CameraManager.player_camera.global_transform
	_death_camera.make_current()

	# Start tracking the falling player
	set_process(true)

	# Watch them fall
	await get_tree().create_timer(watch_duration).timeout

	# Fade to black
	await SceneTransition.fade_out(0.5)

	# Stop tracking
	set_process(false)

	# Teleport player and reset velocity
	player.velocity = Vector3.ZERO
	player.global_position = spawn_position

	# Restore player camera
	_death_camera.queue_free()
	_death_camera = null
	_target_player = null
	CameraManager.player_camera.make_current()

	# Brief pause while black
	await get_tree().create_timer(0.3).timeout

	# Fade back in
	await SceneTransition.fade_in(0.5)

	# Re-enable input
	CameraManager.set_player_input(true)
	_is_respawning = false
