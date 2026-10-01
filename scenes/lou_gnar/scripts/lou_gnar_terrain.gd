class_name LouGnarTerrain
extends Node2D
## Endless platform / rail / pickup / UFO spawner (port of terrain-manager.ts).

signal collectible_collected(value: int, pos: Vector2)

const SPAWN_AHEAD := 1600.0
const DESPAWN_BEHIND := -800.0
const RAIL_SPAWN_CHANCE := 0.3
const COLLECTIBLE_SPAWN_CHANCE := 0.5
const UFO_SPAWN_CHANCE := 1.0

# Gaps are matched to the player's jump (216 = 90% of the 240px max reach).
const GAP_MIN := 120
const GAP_MAX := 216
const PLATFORM_MIN := 240
const PLATFORM_WIDTH_MAX := 720
const Y_STEP_MIN := 100
const Y_STEP_MAX := 150
const Y_RANGE_MIN := 350.0
const Y_RANGE_MAX := 550.0

var platforms: Array[LouGnarPlatform] = []
var rails: Array[LouGnarRail] = []
var coins: Array[LouGnarCoin] = []
var ufos: Array[LouGnarUfo] = []
var player: LouGnarPlayer

var _right_edge: float = 0.0
var _current_y: float = 500.0


func _ready() -> void:
	_spawn_initial()


func _spawn_initial() -> void:
	_add_platform(0.0, 500.0, 600.0, 1000.0)
	_right_edge = 600.0
	_current_y = 500.0


func update(camera_x: float) -> void:
	# --- spawn ahead ---
	while _right_edge < camera_x + SPAWN_AHEAD:
		var gap := _rand(GAP_MIN, GAP_MAX)
		var width := _rand(PLATFORM_MIN, PLATFORM_WIDTH_MAX)

		var y_step := _rand(Y_STEP_MIN, Y_STEP_MAX)
		var y_direction := -1.0 if randf() < 0.5 else 1.0
		var next_y := clampf(_current_y + y_direction * y_step, Y_RANGE_MIN, Y_RANGE_MAX)
		_current_y = next_y

		# Pickup in the gap, before the platform.
		if randf() < COLLECTIBLE_SPAWN_CHANCE:
			_add_coin(_right_edge + gap / 2.0, next_y - 80.0)

		var platform_x: float
		if randf() < RAIL_SPAWN_CHANCE:
			platform_x = _right_edge + gap
			_add_rail(platform_x, next_y, width)
		else:
			platform_x = _right_edge + gap
			_add_platform(platform_x, next_y, width, 1000.0)
		_right_edge = platform_x + width

		# Pickup above the platform, otherwise a UFO.
		var coin_above := randf() < COLLECTIBLE_SPAWN_CHANCE
		if coin_above:
			_add_coin(platform_x + width / 2.0, next_y - 150.0)
		if not coin_above and randf() < UFO_SPAWN_CHANCE:
			_add_ufo(platform_x + width / 2.0, next_y - 120.0)

	# --- despawn behind ---
	var limit := camera_x + DESPAWN_BEHIND
	while not platforms.is_empty() and platforms[0].position.x + platforms[0].building_width < limit:
		platforms.pop_front().queue_free()
	while not rails.is_empty() and rails[0].position.x + rails[0].rail_width < limit:
		rails.pop_front().queue_free()
	while not coins.is_empty() and coins[0].position.x < limit:
		coins.pop_front().queue_free()
	while not ufos.is_empty() and ufos[0].position.x < limit:
		ufos.pop_front().queue_free()

	# --- pickups ---
	var bounds := player.get_bounds()
	for coin in coins:
		if coin.check_collection(bounds):
			var points := int(floor(10.0 * player.get_point_multiplier()))
			collectible_collected.emit(points, coin.position)


## Called when the player stomps a UFO.
func remove_ufo(ufo: LouGnarUfo) -> void:
	var idx := ufos.find(ufo)
	if idx != -1:
		ufos.remove_at(idx)
		ufo.queue_free()


## Clear everything and re-seed the starting platform (new run).
func cleanup() -> void:
	for node: Node in platforms + rails + coins + ufos:
		node.queue_free()
	platforms.clear()
	rails.clear()
	coins.clear()
	ufos.clear()
	_spawn_initial()


func _add_platform(x: float, y: float, width: float, height: float) -> void:
	var platform := LouGnarPlatform.new()
	add_child(platform)
	platform.setup(x, y, width, height)
	platforms.append(platform)


func _add_rail(x: float, y: float, width: float) -> void:
	var rail := LouGnarRail.new()
	add_child(rail)
	rail.setup(x, y, width)
	rails.append(rail)


func _add_coin(x: float, y: float) -> void:
	var coin := LouGnarCoin.new()
	coin.position = Vector2(x, y)
	add_child(coin)
	coins.append(coin)


func _add_ufo(x: float, y: float) -> void:
	var ufo := LouGnarUfo.new()
	add_child(ufo)
	ufo.setup(x, y)
	ufos.append(ufo)


func _rand(lo: int, hi: int) -> int:
	return randi_range(lo, hi)
