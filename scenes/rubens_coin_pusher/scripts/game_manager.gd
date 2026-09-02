extends Node

var score: int = 0
var score_3d: Label3D
var coins_3d: Label3D
var money_3d: Label3D
var interact_prompt: Label3D
var main_scene: Node
var coin_spawn_point: Node3D
var coin_scene = preload("res://scenes/rubens_coin_pusher/scenes/coin.tscn")
var ball_script = preload("res://scenes/rubens_coin_pusher/scripts/ball.gd")
const MAX_COINS = 500

var next_ball_at: int = 50
var balls_pending: int = 0
var coins_loaded: int = 0

func _ready():
	pass

func add_score(amount: int = 1):
	score += amount
	if score_3d:
		score_3d.text = "Score: " + str(score)
	while score >= next_ball_at:
		balls_pending += 1
		next_ball_at += 50
	if balls_pending > 0:
		drop_next_ball()

func add_dollars(amount: int):
	EconomyManager.add_money(amount, "coin_pusher")
	_update_money_3d()

func try_insert_dollar() -> bool:
	if not EconomyManager.can_afford(1):
		return false
	EconomyManager.spend_money(1, "coin_pusher")
	coins_loaded += 10
	_update_coins_3d()
	return true

func try_shoot_coin() -> bool:
	if coins_loaded <= 0:
		return false
	coins_loaded -= 1
	_update_coins_3d()
	return true

func _update_coins_3d():
	if coins_3d:
		coins_3d.text = "Coins: " + str(coins_loaded)
	_update_money_3d()

func _update_money_3d():
	if money_3d:
		money_3d.text = "$" + str(EconomyManager.get_money())

func drop_next_ball():
	if balls_pending <= 0 or not main_scene:
		return
	balls_pending -= 1
	var ball = RigidBody3D.new()
	ball.set_script(ball_script)
	main_scene.add_child(ball)
	ball.global_position = main_scene.to_global(Vector3(randf_range(-0.08, 0.08), 1.7, randf_range(-0.65, -0.45)))

func spawn_coin(pos: Vector3, impulse: Vector3 = Vector3.ZERO, z_rotation: float = 0.0) -> RigidBody3D:
	if not main_scene:
		return null
	var coins = get_tree().get_nodes_in_group("coins")
	if coins.size() >= MAX_COINS:
		coins[0].queue_free()
	var coin = coin_scene.instantiate()
	main_scene.add_child(coin)
	coin.global_position = pos
	if z_rotation != 0.0:
		coin.rotation.z = z_rotation
	if impulse != Vector3.ZERO:
		coin.apply_central_impulse(impulse)
	return coin
