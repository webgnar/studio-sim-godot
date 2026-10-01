class_name LouGnarCameraFx
extends RefCounted
## Zoom punch on tricks / grinds (port of camera-effects-manager.ts).

enum Zoom { NORMAL, TRICK, GRINDING }

const NORMAL_ZOOM := 1.0
const TRICK_ZOOM := 1.4
const GRIND_ZOOM := 1.3
const ZOOM_IN_SPEED := 3.0
const ZOOM_OUT_SPEED := 1.5
const TRICK_DURATION := 0.7

var _player: LouGnarPlayer
var _camera: Camera2D
var _state: Zoom = Zoom.NORMAL
var _current: float = 1.0
var _target: float = 1.0
var _trick_timer: float = 0.0
var _was_grinding: bool = false


func _init(player: LouGnarPlayer, camera: Camera2D) -> void:
	_player = player
	_camera = camera
	player.trick_performed.connect(_on_trick)


func _on_trick(_trick: StringName) -> void:
	_state = Zoom.TRICK
	_target = TRICK_ZOOM
	_trick_timer = TRICK_DURATION


func update(dt: float) -> void:
	if _trick_timer > 0.0:
		_trick_timer = maxf(0.0, _trick_timer - dt)
		if _trick_timer == 0.0:
			if _player.current_grind_rail != null:
				_state = Zoom.GRINDING
				_target = GRIND_ZOOM
			else:
				_state = Zoom.NORMAL
				_target = NORMAL_ZOOM

	if _state != Zoom.TRICK:
		var grinding := _player.current_grind_rail != null
		if grinding and not _was_grinding:
			_state = Zoom.GRINDING
			_target = GRIND_ZOOM
		elif not grinding and _was_grinding:
			_state = Zoom.NORMAL
			_target = NORMAL_ZOOM
		_was_grinding = grinding

	var speed := ZOOM_IN_SPEED if _current < _target else ZOOM_OUT_SPEED
	_current = lerpf(_current, _target, 1.0 - exp(-speed * dt))
	_camera.zoom = Vector2(_current, _current)


func cleanup() -> void:
	_current = NORMAL_ZOOM
	_target = NORMAL_ZOOM
	_camera.zoom = Vector2.ONE
	_state = Zoom.NORMAL
	_trick_timer = 0.0
	_was_grinding = false
