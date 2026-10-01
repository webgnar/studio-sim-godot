class_name ExSkatePlayer
extends Node2D
## Skater: physics, state machine, tricks and animation (port of player.ts).
## Origin is the bottom-centre of the 30x75 collision box (feet).

signal died
signal trick_performed(trick_name: StringName)
## Emitted when a UFO is stomped. `value` is already multiplied by the speed tier.
signal ufo_destroyed(pos: Vector2, ufo: ExSkateUfo, value: int)

enum State { GROUNDED, AIRBORNE, GRINDING, LANDING }

const A_IDLE := &"idle"
const A_PUSH := &"push"
const A_OLLIE := &"ollie"
const A_KICKFLIP := &"kickflip"
const A_HEELFLIP := &"heelflip"
const A_SHUV1 := &"shuv1"
const A_SHUV2 := &"shuv2"
const A_IMPACT := &"impact"
const A_GRIND1 := &"grind1"
const A_GRIND2 := &"grind2"
const A_FREEFALL := &"freefall"
const A_UFO_BOUNCE := &"ufo_bounce"

const START_POS := Vector2(200, 400)
const HALF_WIDTH := 15.0
const HEIGHT := 75.0

const MAX_JUMPS := 3
const PUSH_CYCLE_DURATION := 1.0
const TRICK_COOLDOWN_TIME := 0.2
const IMPACT_DURATION := 0.35
const OLLIE_DURATION := 0.76
const UFO_BOUNCE_DURATION := 0.3

const BASE_SPEED := 320.0
const MAX_SPEED := 720.0
# [score threshold, speed, point multiplier]
const SPEED_TIERS := [
	[0, 320.0, 1.0],
	[250, 400.0, 1.5],
	[500, 480.0, 2.0],
	[1000, 560.0, 2.5],
	[1500, 640.0, 3.0],
	[2500, 720.0, 3.5],
]

const GRAVITY := 2400.0
const JUMP := -900.0
const TERMINAL_VELOCITY := 1200.0
const LANDING_TOLERANCE := 10.0

var terrain: ExSkateTerrain
var audio: ExSkateAudio

var current_grind_rail: ExSkateRail = null
var is_dead: bool = false

var _velocity_y: float = 0.0
var _is_grounded: bool = false
var _prev_y: float = 400.0
var _should_jump: bool = false

var _game_state: State = State.GROUNDED
var _jumps_available: float = 2.0

var _push_cycle_timer: float = 0.0
var _is_pushing: bool = false

var _can_perform_trick: bool = true
var _trick_cooldown: float = 0.0

var _impact_timer: float = 0.0
var _is_ufo_bounce: bool = false
var _ufo_bounce_timer: float = 0.0
var _ollie_timer: float = 0.0

var _current_grind_anim: StringName = A_GRIND1
var _has_played_grind_sound: bool = false

var _current_speed: float = BASE_SPEED
var _current_speed_tier: int = 1

# --- animation ---
var _sprite: Sprite2D
var _anims: Dictionary = {}
var _anim_state: StringName = A_IDLE
var _anim_frame: int = 0
var _anim_elapsed: float = 0.0
var _anim_done: bool = false
var _anim_time_scale: float = 1.0


func _ready() -> void:
	z_index = 10
	position = START_POS
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.offset = Vector2(-ExSkateAssets.PLAYER_FRAME_SIZE.x / 2.0, -ExSkateAssets.PLAYER_FRAME_SIZE.y)
	add_child(_sprite)
	_setup_animations()
	_play_animation(A_IDLE)


# ---------------------------------------------------------------- public API

func request_jump() -> void:
	_should_jump = true


func get_state() -> State:
	return _game_state


func get_jumps_available() -> float:
	return _jumps_available


func get_is_ufo_bounce() -> bool:
	return _is_ufo_bounce


func get_bounds() -> Rect2:
	return Rect2(position.x - HALF_WIDTH, position.y - HEIGHT, HALF_WIDTH * 2.0, HEIGHT)


## World-space point the camera follows (centre of the collision box).
func get_camera_target() -> Vector2:
	return position + Vector2(0, -HEIGHT / 2.0)


func update_speed(current_score: int) -> void:
	var new_tier := 1
	var new_speed := BASE_SPEED
	for i in SPEED_TIERS.size():
		var tier: Array = SPEED_TIERS[i]
		if current_score >= int(tier[0]):
			new_tier = i + 1
			new_speed = tier[1]
	_current_speed_tier = new_tier
	_current_speed = minf(new_speed, MAX_SPEED)


func get_point_multiplier() -> float:
	return SPEED_TIERS[_current_speed_tier - 1][2]


func reset() -> void:
	if audio:
		audio.stop_sfx("grind")
	position = START_POS
	_velocity_y = 0.0
	_is_grounded = false
	_prev_y = START_POS.y
	_should_jump = false
	_game_state = State.GROUNDED
	_jumps_available = 2.0
	_can_perform_trick = true
	_trick_cooldown = 0.0
	_impact_timer = 0.0
	_ollie_timer = 0.0
	_ufo_bounce_timer = 0.0
	current_grind_rail = null
	_has_played_grind_sound = false
	is_dead = false
	_push_cycle_timer = 0.0
	_is_pushing = false
	_is_ufo_bounce = false
	_current_speed = BASE_SPEED
	_current_speed_tier = 1
	_play_animation(A_IDLE)


# ---------------------------------------------------------------- simulation

func step(dt: float) -> void:
	if is_dead:
		return
	_tick_animation(dt)

	_trick_cooldown = maxf(0.0, _trick_cooldown - dt)
	if _trick_cooldown == 0.0:
		_can_perform_trick = true
	_ollie_timer = maxf(0.0, _ollie_timer - dt)

	_prev_y = position.y

	position.x += _current_speed * dt
	_velocity_y = minf(_velocity_y + GRAVITY * dt, TERMINAL_VELOCITY)
	position.y += _velocity_y * dt

	# Fell off the world.
	if position.y > 800.0:
		is_dead = true
		_velocity_y = 0.0
		position.y = 800.0
		died.emit()
		return

	_detect_collisions()
	_update_state(dt)
	_handle_input()


func _update_state(dt: float) -> void:
	match _game_state:
		State.GROUNDED:
			_push_cycle_timer += dt
			if _push_cycle_timer >= PUSH_CYCLE_DURATION:
				_push_cycle_timer = 0.0
				_is_pushing = not _is_pushing
				_play_animation(A_PUSH if _is_pushing else A_IDLE)
			_jumps_available = 2.0
		State.AIRBORNE:
			if _is_ufo_bounce:
				_ufo_bounce_timer += dt
				if _ufo_bounce_timer >= UFO_BOUNCE_DURATION:
					_play_animation(A_FREEFALL)
					_is_ufo_bounce = false
					_ufo_bounce_timer = 0.0
				return
			if _velocity_y > 0.0 and _ollie_timer == 0.0 and _anim_state != A_FREEFALL:
				_play_animation(A_FREEFALL)
		State.GRINDING:
			if current_grind_rail:
				_velocity_y = 0.0
				position.y = current_grind_rail.position.y - current_grind_rail.rail_height
				_jumps_available = 1.75
				if _anim_state != A_GRIND1 and _anim_state != A_GRIND2:
					_play_animation(_current_grind_anim)
		State.LANDING:
			_impact_timer += dt
			if _impact_timer >= IMPACT_DURATION:
				_game_state = State.GROUNDED
				_play_animation(A_IDLE)
				_impact_timer = 0.0


func _detect_collisions() -> void:
	var was_grounded := _is_grounded
	_is_grounded = false
	var handled := false

	# Rails first (grinding takes priority).
	for rail in terrain.rails:
		if _check_landing_on_rail(rail):
			_is_grounded = true
			var was_not_grinding := _game_state != State.GRINDING
			if was_not_grinding and not _has_played_grind_sound:
				audio.play_sfx("grind")
				_has_played_grind_sound = true
			current_grind_rail = rail
			if was_not_grinding:
				_current_grind_anim = A_GRIND1 if randf() < 0.5 else A_GRIND2
			_game_state = State.GRINDING
			handled = true
			break

	if not handled:
		for ufo in terrain.ufos:
			if _check_landing_on_ufo(ufo):
				# Stomping bounces the player back up; never lands on the UFO.
				if not was_grounded and _game_state == State.AIRBORNE:
					_velocity_y = -750.0
					_jumps_available = MAX_JUMPS # UFOs restore all jumps
					_game_state = State.AIRBORNE
					_ufo_bounce_timer = 0.0
					_is_ufo_bounce = true
					_play_animation(A_UFO_BOUNCE)
					audio.play_sfx("ufoExplode")
					var points := int(floor(20.0 * get_point_multiplier()))
					ufo_destroyed.emit(ufo.position, ufo, points)
				handled = true
				break

	if not handled:
		for platform in terrain.platforms:
			if _check_landing_on_platform(platform):
				_is_grounded = true
				if not was_grounded and _game_state == State.AIRBORNE:
					# Harder landings are louder (0.3 .. 1.0).
					audio.play_sfx("impact", minf(1.0, 0.3 + (_velocity_y / TERMINAL_VELOCITY) * 0.7))
					_game_state = State.LANDING
					_impact_timer = 0.0
					_play_animation(A_IMPACT)
				elif _game_state != State.LANDING:
					_game_state = State.GROUNDED
				break

	if was_grounded and not _is_grounded:
		if current_grind_rail:
			audio.stop_sfx("grind")
		_game_state = State.AIRBORNE
		current_grind_rail = null
		_has_played_grind_sound = false


## Swept AABB: did the feet cross the platform top this frame? (prevents tunnelling)
func _swept_aabb(top: float, left: float, right: float) -> bool:
	if _velocity_y < 0.0:
		return false
	var player_left := position.x - HALF_WIDTH
	var player_right := position.x + HALF_WIDTH
	if player_right <= left or player_left >= right:
		return false
	var crossed := _prev_y <= top + LANDING_TOLERANCE and position.y >= top - LANDING_TOLERANCE
	var tunnelled := _prev_y < top and position.y > top
	return crossed or tunnelled


func _check_landing_on_platform(platform: ExSkatePlatform) -> bool:
	var top := platform.position.y
	if _swept_aabb(top, platform.position.x, platform.position.x + platform.building_width):
		position.y = top
		_velocity_y = 0.0
		return true
	return false


func _check_landing_on_rail(rail: ExSkateRail) -> bool:
	var top := rail.position.y - rail.rail_height
	if _swept_aabb(top, rail.position.x, rail.position.x + rail.rail_width):
		position.y = top
		_velocity_y = 0.0
		return true
	return false


func _check_landing_on_ufo(ufo: ExSkateUfo) -> bool:
	var top := ufo.position.y - ExSkateUfo.HIT_HEIGHT
	var half := ExSkateUfo.HIT_WIDTH / 2.0
	if _swept_aabb(top, ufo.position.x - half, ufo.position.x + half):
		position.y = top
		_velocity_y = 0.0
		return true
	return false


func _handle_input() -> void:
	if not _should_jump:
		return
	_should_jump = false

	if _game_state == State.GROUNDED or _game_state == State.GRINDING:
		if _jumps_available >= 1.0:
			_perform_jump(1.0)
			_jumps_available -= 1.0
		elif _jumps_available > 0.0:
			_perform_jump(_jumps_available)
			_jumps_available = 0.0
		_game_state = State.AIRBORNE
		current_grind_rail = null
	elif _game_state == State.AIRBORNE and _jumps_available > 0.0 and _can_perform_trick:
		_perform_trick()


func _perform_jump(power: float) -> void:
	_velocity_y = JUMP * power
	_play_animation(A_OLLIE)
	_ollie_timer = OLLIE_DURATION
	audio.play_sfx("ollie")


func _perform_trick() -> void:
	var tricks: Array[StringName] = [A_KICKFLIP, A_HEELFLIP, A_SHUV1, A_SHUV2]
	var trick: StringName = tricks[randi() % tricks.size()]
	audio.play_sfx("trick")
	_play_animation(trick)
	trick_performed.emit(trick)

	var power := 1.0
	if _jumps_available >= 1.0:
		_velocity_y = JUMP
		_jumps_available -= 1.0
	elif _jumps_available > 0.0:
		power = _jumps_available
		_velocity_y = JUMP * power
		_jumps_available = 0.0

	# Fractional jumps spin faster (less air time).
	if power < 1.0:
		_anim_time_scale = 1.0 / power

	_can_perform_trick = false
	_trick_cooldown = TRICK_COOLDOWN_TIME


# ---------------------------------------------------------------- animation

func _add_anim(anim_name: StringName, sheet: Texture2D, hframes: int, frames: Array, ms: Variant, loop: bool) -> void:
	var durations := PackedFloat32Array()
	for i in frames.size():
		var d: float = ms[i] if ms is Array else ms
		durations.append(d / 1000.0)
	_anims[anim_name] = {"tex": sheet, "hframes": hframes, "frames": frames, "dur": durations, "loop": loop}


func _setup_animations() -> void:
	_add_anim(A_IDLE, ExSkateAssets.SHEET_IDLE, 4, [0, 1, 2, 3], 100.0, true)
	_add_anim(A_PUSH, ExSkateAssets.SHEET_PUSH, 14, range(14), 80.0, true)
	_add_anim(A_GRIND1, ExSkateAssets.SHEET_GRIND1, 3, [0, 1, 2], 80.0, true)
	_add_anim(A_GRIND2, ExSkateAssets.SHEET_GRIND2, 3, [0, 1, 2], 80.0, true)
	_add_anim(A_FREEFALL, ExSkateAssets.SHEET_FREEFALL, 4, [0, 1, 2, 3], 80.0, true)
	# Ollie: first 4 frames fast (40ms), remaining 6 at 100ms.
	_add_anim(A_OLLIE, ExSkateAssets.SHEET_OLLIE, 10, range(10),
		[40.0, 40.0, 40.0, 40.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0], false)
	_add_anim(A_KICKFLIP, ExSkateAssets.SHEET_KICKFLIP, 7, range(7), 100.0, false)
	_add_anim(A_HEELFLIP, ExSkateAssets.SHEET_HEELFLIP, 6, range(6), 100.0, false)
	_add_anim(A_SHUV1, ExSkateAssets.SHEET_SHUV1, 7, range(7), 100.0, false)
	_add_anim(A_SHUV2, ExSkateAssets.SHEET_SHUV2, 7, range(7), 100.0, false)
	_add_anim(A_IMPACT, ExSkateAssets.SHEET_IMPACT, 7, range(7), 50.0, false)
	# UFO bounce reuses the last 3 frames of the ollie.
	_add_anim(A_UFO_BOUNCE, ExSkateAssets.SHEET_OLLIE, 10, [7, 8, 9], 100.0, false)


func _play_animation(anim_name: StringName) -> void:
	_anim_state = anim_name
	_anim_frame = 0
	_anim_elapsed = 0.0
	_anim_done = false
	_anim_time_scale = 1.0
	var anim: Dictionary = _anims[anim_name]
	_sprite.texture = anim["tex"]
	_sprite.hframes = anim["hframes"]
	# Grind sprites hang below the rail.
	var y_off := 0.0
	if anim_name == A_GRIND1:
		y_off = 5.0
	elif anim_name == A_GRIND2:
		y_off = 23.0
	_sprite.offset = Vector2(-ExSkateAssets.PLAYER_FRAME_SIZE.x / 2.0, -ExSkateAssets.PLAYER_FRAME_SIZE.y + y_off)
	_apply_frame()


func _tick_animation(dt: float) -> void:
	if _anim_done:
		return
	var anim: Dictionary = _anims[_anim_state]
	var durations: PackedFloat32Array = anim["dur"]
	var count: int = durations.size()
	_anim_elapsed += dt * _anim_time_scale
	while _anim_elapsed >= durations[_anim_frame]:
		_anim_elapsed -= durations[_anim_frame]
		_anim_frame += 1
		if _anim_frame >= count:
			if anim["loop"]:
				_anim_frame = 0
			else:
				_anim_frame = count - 1
				_anim_done = true
				break
	_apply_frame()


func _apply_frame() -> void:
	var frames: Array = _anims[_anim_state]["frames"]
	_sprite.frame = frames[_anim_frame]
