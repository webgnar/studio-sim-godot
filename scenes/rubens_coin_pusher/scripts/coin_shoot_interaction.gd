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
	var coin := GameManager.spawn_coin(pos, impulse, PI / 2)
	# CoinShootArea's own clickable hitbox physically overlaps CoinSpawnBox (both
	# default to collision_layer/mask 1), so a freshly fired coin spawns embedded
	# in that StaticBody3D's collision and gets stuck instead of flying out. This
	# script is shared by 4 nodes (CoinShootArea + the 3 glass panels), so `self`
	# isn't necessarily the overlapping one — look up CoinShootArea specifically
	# (a sibling of coin_spawn_point) rather than assuming it's whichever panel
	# was actually clicked. A collision exception stops the physical interaction
	# without touching collision_layer, which would also break raycast detection.
	if coin:
		var shoot_area := spawn_point.get_parent().get_node_or_null("CoinShootArea")
		if shoot_area:
			shoot_area.add_collision_exception_with(coin)
