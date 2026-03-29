extends Node3D

var _win_sound: AudioStreamPlayer3D

func _ready():
	GameManager.main_scene = self
	GameManager.coin_spawn_point = $CoinSpawnBox
	GameManager.score_3d = $DisplayPanel/Score3D
	GameManager.coins_3d = $DisplayPanel/Coins3D
	GameManager.money_3d = $DisplayPanel/Money3D
	GameManager.interact_prompt = $CoinSlot/InteractPrompt
	GameManager._update_money_3d()

	_win_sound = AudioStreamPlayer3D.new()
	_win_sound.stream = preload("res://scenes/rubens_coin_pusher/ingle_win_synth_05.wav")
	_win_sound.volume_db = -5.0
	_win_sound.max_distance = 10.0
	_win_sound.bus = "SFX"
	add_child(_win_sound)

	_prespawn_coins.call_deferred()

func _on_score(body: Node3D):
	if body.is_in_group("coins"):
		GameManager.add_score(1)
		body.queue_free()
	elif body.is_in_group("balls"):
		body.queue_free()
		GameManager.add_dollars(10)
		_win_sound.play()

func _prespawn_coins():
	var sample_coin = GameManager.coin_scene.instantiate()
	var coin_radius = sample_coin.get_radius()
	sample_coin.queue_free()
	var coin_spacing = coin_radius * 2.13
	var jitter = coin_radius * 0.17
	var x_start = -0.28
	var x_end = 0.28
	var z_start = -0.57
	var z_end = -0.28
	var z = z_start
	var row = 0
	while z <= z_end:
		var x_offset = coin_spacing * 0.5 if row % 2 == 1 else 0.0
		var x = x_start + x_offset
		while x <= x_end:
			var local_pos = Vector3(
				x + randf_range(-jitter, jitter),
				0.91 + randf_range(0, jitter * 1.5),
				z + randf_range(-jitter, jitter)
			)
			GameManager.spawn_coin(to_global(local_pos))
			x += coin_spacing
		z += coin_spacing * 0.87
		row += 1
