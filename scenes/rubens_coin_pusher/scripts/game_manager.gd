extends Node

## Fires the one time ever a ball actually falls into the score zone —
## persisted via WorldStateManager so it never fires again after the first
## time, even across save/load. Used to gate the "Hidden Door" fog reveal.
signal first_ball_scored

const FIRST_BALL_FLAG := "coin_pusher_first_ball"

var score: int = 0
var score_3d: Label3D
var coins_3d: Label3D
var money_3d: Label3D
var interact_prompt: Label3D
var main_scene: Node
var coin_spawn_point: Node3D
var coin_scene = preload("res://scenes/rubens_coin_pusher/scenes/coin.tscn")
var ball_script = preload("res://scenes/rubens_coin_pusher/scripts/ball.gd")
var bonus_item_script = preload("res://scenes/rubens_coin_pusher/scripts/bonus_item.gd")
const MAX_COINS = 500

## Jackpot prize pool for the "bonus item" that drops every 200 points
## instead of a plain ball (see add_score). These models
## (models/coinpusher_items/*.glb) are all wildly different native sizes
## (roughly 9 to 31 units on their longest axis, no import scale applied), so
## `scale` here is per-model — computed so every item's longest dimension
## ends up at the same ~0.18 target (about 1.5x the plain ball's 0.12
## diameter — a step up in size that still reads as "one item", not a flat
## multiplier that would let the elephant dwarf the penguin 3x over just
## because of how differently they were originally modeled). `offset`
## recenters each model, since several of them aren't modeled around their
## own origin (e.g. the buoy's origin sits at its base, not its center) —
## both derived from each .glb's actual bounding box.
const BONUS_ITEMS := [
	{"path": "res://models/coinpusher_items/penguin.glb", "scale": 0.016552, "radius": 0.09, "offset": Vector3(0.000780, 0.010529, 0.006693)},
	{"path": "res://models/coinpusher_items/giraffe.glb", "scale": 0.006729, "radius": 0.09, "offset": Vector3(-0.000009, -0.003564, 0.000104)},
	{"path": "res://models/coinpusher_items/elephant.glb", "scale": 0.005782, "radius": 0.09, "offset": Vector3(0.0, -0.085702, 0.018556)},
	{"path": "res://models/coinpusher_items/bear.glb", "scale": 0.011081, "radius": 0.09, "offset": Vector3(0.000244, -0.010432, -0.004640)},
	{"path": "res://models/coinpusher_items/dolphin.glb", "scale": 0.011520, "radius": 0.09, "offset": Vector3(0.0, 0.008743, -0.019440)},
	{"path": "res://models/coinpusher_items/cow.glb", "scale": 0.019079, "radius": 0.09, "offset": Vector3(-0.000057, 0.004036, -0.011384)},
	{"path": "res://models/coinpusher_items/buoy.glb", "scale": 0.018403, "radius": 0.09, "offset": Vector3(0.0, -0.090020, 0.004073)},
	{"path": "res://models/coinpusher_items/statue_of liberty.glb", "scale": 0.006318, "radius": 0.09, "offset": Vector3(-0.003339, 0.035430, 0.001055)},
]
var _bonus_bag: Array[int] = []  ## shuffled draw order; refilled+reshuffled whenever exhausted so every item is seen once per cycle before any repeats

var next_ball_at: int = 50
var pending_drops: Array[String] = []  ## queue of "ball" / "bonus", in the order their score thresholds were crossed
var coins_loaded: int = 0

func _ready():
	pass

func add_score(amount: int = 1):
	score += amount
	if score_3d:
		score_3d.text = "Score: " + str(score)
	while score >= next_ball_at:
		pending_drops.append("bonus" if next_ball_at % 200 == 0 else "ball")
		next_ball_at += 50
	if not pending_drops.is_empty():
		drop_next_ball()

func add_dollars(amount: int):
	EconomyManager.add_money(amount, "coin_pusher")
	_update_money_3d()

func on_ball_scored() -> void:
	if WorldStateManager.has_flag(FIRST_BALL_FLAG):
		return
	WorldStateManager.set_flag(FIRST_BALL_FLAG)
	first_ball_scored.emit()

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
	if pending_drops.is_empty() or not main_scene:
		return
	var kind: String = pending_drops.pop_front()
	var body: RigidBody3D
	if kind == "bonus":
		body = _create_bonus_item()
	else:
		body = RigidBody3D.new()
		body.set_script(ball_script)
	main_scene.add_child(body)
	body.global_position = main_scene.to_global(Vector3(randf_range(-0.08, 0.08), 1.7, randf_range(-0.65, -0.45)))

func _create_bonus_item() -> RigidBody3D:
	if _bonus_bag.is_empty():
		# Refill with every item's index, freshly shuffled — this is what
		# guarantees "each chosen once until all have been chosen, then
		# repeat the cycle randomly": pop_back() below draws them in this
		# shuffled order with no repeats until the bag empties out again.
		for i in range(BONUS_ITEMS.size()):
			_bonus_bag.append(i)
		_bonus_bag.shuffle()
	var data: Dictionary = BONUS_ITEMS[_bonus_bag.pop_back()]
	var body := RigidBody3D.new()
	body.set_script(bonus_item_script)
	body.set_meta("bonus_data", data)
	return body

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
