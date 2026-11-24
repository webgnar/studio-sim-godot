extends Node
class_name PaintingReplay

## Plays a PaintingRecording back as a time-lapse: stickers go down (and come
## off again, for undos) one by one, in their own order and rhythm, sped up so
## the whole painting takes a few tens of seconds. Draws into its own
## SubViewport, turned the way the player sees the canvas (the same 90 degree
## turn the commission reference images get), so `texture` can stand in for a
## mission's reference image. Used by the Commissions screen's Watch Replay.

signal progress_changed(shown: int, total: int)
signal finished

## Replay length: about this many seconds per sticker, kept between the two
## limits below. Raise to slow replays down.
const SECONDS_PER_STICKER := 0.08
const MIN_SECONDS := 12.0
const MAX_SECONDS := 60.0
## A gap in the painting longer than this (seconds of painting time) is played
## as this long, so a long think doesn't stall the replay.
const LONGEST_PAUSE := 3.0
## Hold the empty canvas this long before the first sticker.
const LEAD_IN := 0.4

var playing := false
var _viewport: SubViewport
var _canvas: Node2D
var _events: Array = []
var _times: PackedFloat32Array = PackedFloat32Array()   ## replay seconds each event happens at
var _sprites: Dictionary = {}   ## event index -> Sprite2D
var _next := 0
var _clock := 0.0
var _placements := 0
var _shown := 0


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "ReplayViewport"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_canvas = Node2D.new()
	_canvas.name = "Canvas"
	_viewport.add_child(_canvas)


## The replay image (valid once start() has run).
var texture: Texture2D:
	get:
		return _viewport.get_texture() if _viewport else null


func has_content() -> bool:
	return not _events.is_empty()


## Loads `recording` and starts playing it from an empty canvas.
func start(recording: Dictionary) -> bool:
	stop()
	_events = recording.get("events", [])
	if _events.is_empty():
		return false
	var size := PaintingRecording.canvas_size(recording)
	# Turned 90 degrees clockwise, as the player sees it: canvas pixel (x, y)
	# lands at (height - y, x)
	_viewport.size = Vector2i(int(size.y), int(size.x))
	_canvas.rotation = PI / 2.0
	_canvas.position = Vector2(size.y, 0.0)
	_plan_times()
	_placements = 0
	for e in _events:
		if not e.has("remove"):
			_placements += 1
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	playing = true
	progress_changed.emit(0, _placements)
	return true


## Stops and clears the replay.
func stop() -> void:
	playing = false
	for child in _canvas.get_children():
		child.queue_free()
	_sprites.clear()
	_events = []
	_next = 0
	_clock = 0.0
	_shown = 0
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Jumps to the finished painting.
func skip_to_end() -> void:
	while _next < _events.size():
		_apply(_next)
		_next += 1
	_end()


func _plan_times() -> void:
	"""Squeeze the painting's own timing into the replay length, keeping its
	rhythm (quick runs stay quick, pauses stay pauses, up to LONGEST_PAUSE)."""
	var raw := PackedFloat32Array()
	raw.resize(_events.size())
	var prev := 0.0
	var acc := 0.0
	for i in _events.size():
		var t := float(_events[i].get("t", i))
		acc += clampf(t - prev, 0.0, LONGEST_PAUSE) if i > 0 else 0.0
		prev = t
		raw[i] = acc
	var placements := 0
	for e in _events:
		if not e.has("remove"):
			placements += 1
	var length := clampf(placements * SECONDS_PER_STICKER, MIN_SECONDS, MAX_SECONDS)
	var span := raw[raw.size() - 1]
	_times.resize(_events.size())
	for i in _events.size():
		# No timing at all (every t the same): spread evenly
		var k := raw[i] / span if span > 0.0 else float(i) / maxf(_events.size() - 1, 1)
		_times[i] = LEAD_IN + k * length


func _process(delta: float) -> void:
	if not playing:
		return
	_clock += delta
	var changed := false
	while _next < _events.size() and _times[_next] <= _clock:
		_apply(_next)
		_next += 1
		changed = true
	if changed:
		progress_changed.emit(_shown, _placements)
	if _next >= _events.size():
		_end()


func _end() -> void:
	playing = false
	progress_changed.emit(_shown, _placements)
	# Keep the finished painting on screen, but stop redrawing it every frame
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	finished.emit()


func _apply(i: int) -> void:
	var e: Dictionary = _events[i]
	if e.has("remove"):
		var sprite: Sprite2D = _sprites.get(int(e.remove))
		if sprite:
			sprite.queue_free()
			_sprites.erase(int(e.remove))
		return
	_shown += 1
	var definition = StickerLibrary.get_definition_by_id(str(e.get("id", "")))
	if not definition or not definition.texture:
		return
	# Exactly how PaintingSystem2D.spawn_sticker puts it on the canvas
	var sprite := Sprite2D.new()
	sprite.texture = definition.texture
	sprite.centered = true
	sprite.position = Vector2(float(e.x), float(e.y))
	sprite.rotation_degrees = float(e.r)
	sprite.scale = Vector2.ONE * float(e.s)
	_canvas.add_child(sprite)
	_sprites[i] = sprite
