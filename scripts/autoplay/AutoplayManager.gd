extends CanvasLayer

## Idle Autoplay ("screensaver mode").
## When enabled in Options > Game, and the player has given no input for
## idle_seconds while in normal gameplay, the bot takes over the player.
## Any real input (key, mouse, touch, gamepad, Steam Input) hands control
## back immediately, and that input is swallowed so it doesn't also act.
##
## The bot never synthesizes InputEvents: it drives the game through direct
## calls, so nothing it does can be mistaken for the player waking it up.

signal autoplay_started
signal autoplay_stopped

const SETTINGS_PATH := "user://settings.json"
const KEY_ENABLED := "autoplay_enabled"
const KEY_IDLE_SECONDS := "autoplay_idle_seconds"

const DEFAULT_IDLE_SECONDS := 120.0
const MIN_IDLE_SECONDS := 15.0
const MOUSE_MOTION_THRESHOLD := 2.0  ## px; ignores sensor jitter on idle mice
const STICK_THRESHOLD := 0.3         ## ignores stick drift on idle pads

var enabled: bool = false
var idle_seconds: float = DEFAULT_IDLE_SECONDS

var _idle_time: float = 0.0
var _active: bool = false
var _label: Label
var _fade_rect: ColorRect
var _bot: Node
var _swallow_event: InputEvent = null


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_bot = preload("res://scripts/autoplay/AutoplayBot.gd").new()
	_bot.name = "AutoplayBot"
	_bot.fade_rect = _fade_rect
	add_child(_bot)
	_load_settings()
	# The root window's signal fires before the event reaches any node, so a
	# scene node marking the event handled in its own _input() can't hide it.
	get_tree().root.window_input.connect(_on_window_input)


func is_active() -> bool:
	return _active


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		stop()
	_idle_time = 0.0
	_save_settings()


func set_idle_seconds(value: float) -> void:
	idle_seconds = max(value, MIN_IDLE_SECONDS)
	_idle_time = 0.0
	_save_settings()


func _on_window_input(event: InputEvent) -> void:
	if not _is_player_input(event):
		return
	_idle_time = 0.0
	if _active:
		stop()
		_swallow_event = event


func _input(event: InputEvent) -> void:
	# Best effort: eat the input that woke us so it doesn't also click or move.
	# Scene nodes see _input() before autoloads, so this can't catch everything.
	if event == _swallow_event:
		_swallow_event = null
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _steam_input_moved():
		_idle_time = 0.0
		if _active:
			stop()
		return

	if _active:
		if not _can_autoplay():
			stop()
		return

	if not enabled or not _can_autoplay():
		_idle_time = 0.0
		return

	_idle_time += delta
	if _idle_time >= idle_seconds:
		start()


func start() -> void:
	if _active:
		return
	_active = true
	_label.visible = true
	print("AutoplayManager: player idle for %.0fs, autoplay started" % idle_seconds)
	_bot.begin(_get_player())
	autoplay_started.emit()


func stop() -> void:
	if not _active:
		return
	_active = false
	_idle_time = 0.0
	_label.visible = false
	_bot.end()
	print("AutoplayManager: input detected, control returned to player")
	autoplay_stopped.emit()


# --- Idle detection ---

func _is_player_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		return event.relative.length() >= MOUSE_MOTION_THRESHOLD
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) >= STICK_THRESHOLD
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.is_pressed()
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return true
	return false


func _steam_input_moved() -> bool:
	"""Steam Input reads controllers through the Steam API, so it never reaches
	_input(). Poll its move/look sticks and digital actions instead."""
	if not SteamInput._is_steam_input_active():
		return false
	if SteamInput.get_analog_action("move").length() >= STICK_THRESHOLD:
		return true
	if SteamInput.get_analog_action("camera").length() >= STICK_THRESHOLD:
		return true
	# SteamInput already polls every digital action once per frame
	return SteamInput._current_states.values().has(true)


func _can_autoplay() -> bool:
	"""Only run in plain studio gameplay: no menus, missions, cutscenes or
	camera zones, and only when a player exists in the scene."""
	if UIManager.current_state != UIManager.GameState.GAMEPLAY:
		return false
	if not CameraManager.player_input_enabled:
		return false
	if get_tree().paused:
		return false
	var player = _get_player()
	if not player or not "autoplay_move" in player:
		return false
	if player.is_skating() or player.is_climbing():
		return false
	if not _active:
		# Don't take over mid-task: holding a painting, a tool or a weapon
		var interaction = player.get("_interaction_component")
		if interaction and (interaction.is_carrying or interaction.is_weapon_equipped):
			return false
	return true


func _get_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


# --- UI ---

func _build_ui() -> void:
	# The bot's own fade for repositioning; stopping the bot always clears it
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_label = Label.new()
	_label.theme = load("res://themes/ui_theme.tres")
	_label.text = "AUTOPLAY  -  press any key to take over"
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label.position += Vector2(16, -40)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)


# --- Settings (shares user://settings.json with OptionsMenu) ---

func _read_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data if data is Dictionary else {}


func _load_settings() -> void:
	var settings = _read_settings()
	enabled = bool(settings.get(KEY_ENABLED, false))
	idle_seconds = max(float(settings.get(KEY_IDLE_SECONDS, DEFAULT_IDLE_SECONDS)), MIN_IDLE_SECONDS)


func _save_settings() -> void:
	var settings = _read_settings()
	settings[KEY_ENABLED] = enabled
	settings[KEY_IDLE_SECONDS] = idle_seconds
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()
