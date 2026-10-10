class_name LouGnarGame
extends SubViewport
## Lou Gnar - arcade skate runner, ported from the Excalibur.js web game.
##
## This node IS the 800x600 viewport: put get_texture() on the cabinet screen
## (like CreditsTV does) or show it in a SubViewportContainer. Controls are one
## button (action "lou_gnar_jump": Space / Enter / left click / gamepad A).
##
## Hooks for the cabinet:
##   input_enabled   - ignore input unless someone is playing
##   audio_enabled   - silence music + sfx unless someone is at the machine
##   set_running()   - freeze simulation + rendering when nobody is around
##   press_jump()    - feed a jump from your own interaction code
##   leaderboard     - assign an LouGnarLeaderboard subclass (e.g. Steam)
## Signals: game_started, score_changed, game_over, returned_to_title

signal game_started
signal score_changed(score: int)
signal game_over(final_score: int)
signal returned_to_title

enum Phase { TITLE, PLAYING, GAME_OVER }

const SCREEN_SIZE := Vector2i(800, 600)
const MAX_DELTA := 0.05
const START_OVER_DELAY := 0.75 # ignore input briefly so death-mashing doesn't skip the board
const JUMP_ACTION := &"lou_gnar_jump"
const BACKGROUND := Color("#2a2a2a")

@export var input_enabled: bool = true
@export var audio_enabled: bool = true:
	set(value):
		audio_enabled = value
		_apply_audio_state()

## Where scores are stored/shown. Defaults to Steam leaderboards when available, else a local JSON board.
var leaderboard: LouGnarLeaderboard:
	set(value):
		if leaderboard == value:
			return
		_release_leaderboard()
		leaderboard = value
		_adopt_leaderboard()

## Steam achievement for reaching this score in a single run.
const SCORE_ACHIEVEMENT_ID := "ACH_LOU_GNAR_1500"
const SCORE_ACHIEVEMENT_THRESHOLD := 1000  # ID keeps "1500" to match Steamworks

var score: int = 0
var phase: Phase = Phase.TITLE

var _running: bool = true
var _pending_jump: bool = false
var _phase_time: float = 0.0

var _world: Node2D
var _camera: Camera2D
var _parallax: LouGnarParallax
var _terrain: LouGnarTerrain
var _player: LouGnarPlayer
var _effects: LouGnarEffects
var _camera_fx: LouGnarCameraFx
var _audio: LouGnarAudio
var _hud: LouGnarHud
var _title: LouGnarTitleScreen
var _game_over: LouGnarGameOverScreen


func _ready() -> void:
	size = SCREEN_SIZE
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_ensure_input_action()
	_build()
	if leaderboard == null:
		leaderboard = _default_leaderboard()
	else:
		_adopt_leaderboard()
	_apply_audio_state()
	_show_title()


func _process(delta: float) -> void:
	var dt := minf(delta, MAX_DELTA)
	_phase_time += dt

	var jump := _pending_jump
	_pending_jump = false
	if input_enabled and Input.is_action_just_pressed(JUMP_ACTION):
		jump = true

	match phase:
		Phase.TITLE:
			_title.update(dt)
			if jump:
				_start_run()
		Phase.PLAYING:
			if jump:
				_player.request_jump()
			_update_playing(dt)
		Phase.GAME_OVER:
			_game_over.update(dt)
			if jump and _phase_time >= START_OVER_DELAY:
				_show_title()
				returned_to_title.emit()


# ---------------------------------------------------------------- public API

## Queue a jump / confirm from outside (e.g. your own interaction code).
func press_jump() -> void:
	_pending_jump = true


## Freeze (false) or resume (true) simulation, rendering and audio.
func set_running(running: bool) -> void:
	_running = running
	process_mode = Node.PROCESS_MODE_INHERIT if running else Node.PROCESS_MODE_DISABLED
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if running else SubViewport.UPDATE_DISABLED
	_apply_audio_state()


## Abort whatever is happening and go back to the title card.
func return_to_title() -> void:
	_show_title()


func add_score(points: int) -> void:
	var previous := score
	score += points
	_player.update_speed(score)
	_hud.set_score(score)
	score_changed.emit(score)
	if phase == Phase.PLAYING and previous < SCORE_ACHIEVEMENT_THRESHOLD \
			and score >= SCORE_ACHIEVEMENT_THRESHOLD:
		_unlock_achievement(SCORE_ACHIEVEMENT_ID)


## Looked up by path (like the leaderboards) so LouGnar still runs standalone without the
## project's SteamManager autoload. SteamManager.unlock_achievement is idempotent.
func _unlock_achievement(id: String) -> void:
	var steam_manager := get_tree().root.get_node_or_null("SteamManager") if get_tree() else null
	if steam_manager and steam_manager.has_method("unlock_achievement"):
		steam_manager.unlock_achievement(id)


# ---------------------------------------------------------------- phases

func _show_title() -> void:
	phase = Phase.TITLE
	_phase_time = 0.0
	_world.visible = false
	_hud.visible = false
	_game_over.visible = false
	_title.visible = true
	_title.reset()
	_audio.stop_all()
	_audio.play_music("title")


func _start_run() -> void:
	phase = Phase.PLAYING
	_phase_time = 0.0
	score = 0
	_title.visible = false
	_game_over.visible = false
	_world.visible = true
	_hud.visible = true

	_player.reset()
	_terrain.cleanup()
	_effects.cleanup()
	_camera_fx.cleanup()
	_camera.position = _player.get_camera_target()
	_parallax.update(_camera.position.x)
	_hud.reset(_player.get_jumps_available())

	_audio.play_music("gameplay")
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		if phase == Phase.PLAYING:
			_audio.play_sfx("gameStart"))
	game_started.emit()


func _update_playing(dt: float) -> void:
	_player.step(dt)
	if phase != Phase.PLAYING: # died this frame
		return
	_camera.position = _player.get_camera_target()
	_camera_fx.update(dt)
	_terrain.update(_camera.position.x)
	_parallax.update(_camera.position.x)
	_effects.update(_player)
	_hud.update(dt, _player.get_jumps_available())


func _on_player_died() -> void:
	phase = Phase.GAME_OVER
	_phase_time = 0.0
	_audio.stop_all()
	_audio.play_sfx("die")
	_world.visible = false
	_hud.visible = false
	_game_over.visible = true

	var player_name := LouGnarLeaderboard.resolve_player_name()
	_game_over.show_results(score, player_name)
	if leaderboard:
		leaderboard.request_entries()
		leaderboard.submit_score(player_name, score)
	else:
		_game_over.set_status("")
	game_over.emit(score)


func _on_collectible(value: int, pos: Vector2) -> void:
	_audio.play_sfx("coinCollect")
	add_score(value)
	_effects.on_collectible(value, pos)


func _on_ufo_destroyed(pos: Vector2, ufo: LouGnarUfo, value: int) -> void:
	_terrain.remove_ufo(ufo)
	add_score(value)
	_effects.on_ufo_destroyed(pos, value)


# ---------------------------------------------------------------- leaderboard

## Steam leaderboard when GodotSteam is present (it falls back to the local board
## by itself if Steam is offline), otherwise the local JSON board.
func _default_leaderboard() -> LouGnarLeaderboard:
	if Engine.has_singleton("Steam"):
		return LouGnarSteamLeaderboard.new()
	return LouGnarLocalLeaderboard.new()

func _adopt_leaderboard() -> void:
	if leaderboard == null or not is_node_ready():
		return
	if leaderboard.get_parent() == null:
		add_child(leaderboard)
	leaderboard.entries_loaded.connect(_on_entries_loaded)
	leaderboard.score_submitted.connect(_on_score_submitted)


func _release_leaderboard() -> void:
	if leaderboard == null:
		return
	if leaderboard.entries_loaded.is_connected(_on_entries_loaded):
		leaderboard.entries_loaded.disconnect(_on_entries_loaded)
	if leaderboard.score_submitted.is_connected(_on_score_submitted):
		leaderboard.score_submitted.disconnect(_on_score_submitted)


func _on_entries_loaded(entries: Array) -> void:
	if phase == Phase.GAME_OVER:
		_game_over.set_entries(entries, leaderboard.is_offline())


func _on_score_submitted(success: bool) -> void:
	if phase != Phase.GAME_OVER:
		return
	var status := "SUBMIT FAILED"
	if success:
		status = "SAVED OFFLINE" if leaderboard.is_offline() else "SUBMITTED!"
	_game_over.set_status(status)
	if success and leaderboard:
		leaderboard.request_entries() # refresh with the new score


# ---------------------------------------------------------------- setup

func _build() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -100
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.color = BACKGROUND
	bg.size = Vector2(SCREEN_SIZE)
	bg_layer.add_child(bg)

	_audio = LouGnarAudio.new()
	add_child(_audio)

	_world = Node2D.new()
	add_child(_world)
	_parallax = LouGnarParallax.new()
	_world.add_child(_parallax)
	_terrain = LouGnarTerrain.new()
	_world.add_child(_terrain)
	_player = LouGnarPlayer.new()
	_world.add_child(_player)
	_effects = LouGnarEffects.new()
	_world.add_child(_effects)

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()

	_terrain.player = _player
	_player.terrain = _terrain
	_player.audio = _audio
	_player.died.connect(_on_player_died)
	_player.ufo_destroyed.connect(_on_ufo_destroyed)
	_terrain.collectible_collected.connect(_on_collectible)
	_camera_fx = LouGnarCameraFx.new(_player, _camera)

	_hud = LouGnarHud.new()
	add_child(_hud)
	_title = LouGnarTitleScreen.new()
	add_child(_title)
	_game_over = LouGnarGameOverScreen.new()
	add_child(_game_over)


func _apply_audio_state() -> void:
	if _audio:
		_audio.enabled = audio_enabled and _running


## Registers the game's single input action if the project hasn't defined it.
static func _ensure_input_action() -> void:
	if InputMap.has_action(JUMP_ACTION):
		return
	InputMap.add_action(JUMP_ACTION)
	for keycode: Key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		InputMap.action_add_event(JUMP_ACTION, key)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(JUMP_ACTION, click)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	InputMap.action_add_event(JUMP_ACTION, pad)
