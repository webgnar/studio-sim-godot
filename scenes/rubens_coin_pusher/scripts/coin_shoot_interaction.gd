extends StaticBody3D

var interaction_text: String = "Shoot Coin"
var _zap_sound: AudioStreamPlayer3D

func _ready():
	_zap_sound = AudioStreamPlayer3D.new()
	_zap_sound.stream = preload("res://scenes/rubens_coin_pusher/zap_c_02.wav")
	_zap_sound.volume_db = -5.0
	_zap_sound.max_distance = 8.0
	_zap_sound.bus = "SFX"
	add_child(_zap_sound)

func _process(_delta):
	if GameManager.coins_loaded > 0:
		interaction_text = "Shoot Coin"
	else:
		interaction_text = "Insert $1 at Coin Slot"

func interact(_interactor) -> void:
	if not GameManager.try_shoot_coin():
		return
	_zap_sound.play()
	var spawn_point = GameManager.coin_spawn_point
	if not spawn_point:
		return
	var anim = spawn_point.get_node_or_null("Gun/AnimationPlayer")
	if anim:
		anim.play("fire")
	var dir = -spawn_point.global_transform.basis.z
	var pos = spawn_point.global_position
	pos += Vector3(randf_range(-0.02, 0.02), 0, 0)
	var impulse = dir * 0.015 + Vector3(randf_range(-0.004, 0.004), 0, 0)
	# CoinShootArea's clickable hitbox is a big box inside the playfield, so it
	# sits on collision layer 4 (Interactables) only: the player's interaction
	# raycast (mask 15) still hits it, but coins/balls (mask 1) pass through.
	# On layer 1 it blocked every ball from reaching the front edge — they piled
	# up behind it forever and the growing pile of physics bodies tanked FPS.
	GameManager.spawn_coin(pos, impulse, PI / 2)
