extends Area3D

@export var spawn_position: Vector3 = Vector3(-0.947, 1.207, 12.446)

var _is_respawning: bool = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and not _is_respawning:
		_respawn(body)

func _respawn(player):
	_is_respawning = true

	# Disable player input
	CameraManager.set_player_input(false)

	# Fade to black
	await SceneTransition.fade_out(0.5)

	# Teleport player and reset velocity
	player.velocity = Vector3.ZERO
	player.global_position = spawn_position

	# Brief pause while black
	await get_tree().create_timer(0.3).timeout

	# Fade back in
	await SceneTransition.fade_in(0.5)

	# Re-enable input
	CameraManager.set_player_input(true)
	_is_respawning = false
