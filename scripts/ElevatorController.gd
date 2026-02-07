extends Node3D
class_name ElevatorController

## Controls the elevator export system
## Manages gate state (open/closed), painting detection, and export sequence

signal painting_entered(painting: CarryablePainting)
signal painting_exited(painting: CarryablePainting)
signal gate_opened()
signal gate_closed()
signal export_started(painting: CarryablePainting)
signal export_completed(png_path: String, glb_path: String)

enum GateState { OPEN, CLOSED, ANIMATING }

@export_group("References")
@export var detection_area: Area3D
@export var gate_animation_player: AnimationPlayer
@export var moving_parts: Node3D  ## The node that descends during export

@export_group("Export Settings")
@export var descent_duration: float = 1.5  ## Duration of descent animation
@export var descent_distance: float = 10.0  ## How far the elevator descends

# State
var paintings_inside: Array[CarryablePainting] = []
var gate_state: GateState = GateState.OPEN
var is_exporting: bool = false

# Audio
var _export_sound: AudioStreamPlayer3D
var _door_sound: AudioStreamPlayer3D
var _door_stream: AudioStream = preload("res://sounds/picotron/elevator_door.ogg")
var _descent_stream: AudioStream = preload("res://sounds/picotron/elevator_down.ogg")

func _ready() -> void:
	# If exports weren't resolved, try to find nodes by path
	if not moving_parts:
		moving_parts = get_node_or_null("MovingParts")

	if not detection_area:
		detection_area = get_node_or_null("MovingParts/PaintingDetectionArea")

	if not gate_animation_player:
		gate_animation_player = get_node_or_null("MovingParts/gate/AnimationPlayer")

	# Connect Area3D signals if found
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("ElevatorController: No detection_area found!")

	# Setup audio
	_setup_audio()

func _setup_audio() -> void:
	_export_sound = AudioStreamPlayer3D.new()
	_export_sound.name = "ExportSound"
	_export_sound.max_distance = 15.0
	_export_sound.bus = "SFX"
	_export_sound.stream = _descent_stream
	add_child(_export_sound)

	_door_sound = AudioStreamPlayer3D.new()
	_door_sound.name = "DoorSound"
	_door_sound.max_distance = 15.0
	_door_sound.bus = "SFX"
	_door_sound.stream = _door_stream
	add_child(_door_sound)

func _on_body_entered(body: Node) -> void:
	if body is CarryablePainting:
		var painting = body as CarryablePainting
		if painting not in paintings_inside:
			paintings_inside.append(painting)
			painting_entered.emit(painting)

func _on_body_exited(body: Node) -> void:
	if body is CarryablePainting:
		var painting = body as CarryablePainting
		paintings_inside.erase(painting)
		painting_exited.emit(painting)

# --- Gate Control ---

func is_gate_open() -> bool:
	return gate_state == GateState.OPEN

func is_gate_closed() -> bool:
	return gate_state == GateState.CLOSED

func is_gate_animating() -> bool:
	return gate_state == GateState.ANIMATING

func can_toggle_gate() -> bool:
	"""Check if gate can be opened/closed (not animating, not exporting)"""
	return gate_state != GateState.ANIMATING and not is_exporting

func open_gate() -> void:
	"""Open the elevator gate"""
	if not can_toggle_gate() or gate_state == GateState.OPEN:
		return

	gate_state = GateState.ANIMATING
	_door_sound.play()

	if gate_animation_player and gate_animation_player.has_animation("open"):
		gate_animation_player.play("open")
		await gate_animation_player.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout

	gate_state = GateState.OPEN
	gate_opened.emit()

func close_gate() -> void:
	"""Close the elevator gate"""
	if not can_toggle_gate() or gate_state == GateState.CLOSED:
		return

	gate_state = GateState.ANIMATING
	_door_sound.play()

	if gate_animation_player and gate_animation_player.has_animation("close"):
		gate_animation_player.play("close")
		await gate_animation_player.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout

	gate_state = GateState.CLOSED
	gate_closed.emit()

func toggle_gate() -> void:
	"""Toggle gate between open and closed"""
	if gate_state == GateState.OPEN:
		close_gate()
	elif gate_state == GateState.CLOSED:
		open_gate()

# --- Export Control ---

func can_export() -> bool:
	"""Check if export is possible (painting inside, gate closed, not already exporting)"""
	return not paintings_inside.is_empty() and gate_state == GateState.CLOSED and not is_exporting

func get_painting_count() -> int:
	"""Get number of paintings currently inside elevator"""
	return paintings_inside.size()

func start_export() -> void:
	"""Begin the export sequence"""
	if not can_export():
		push_warning("ElevatorController: Cannot export - requirements not met")
		return

	is_exporting = true
	var painting = paintings_inside[0]
	export_started.emit(painting)

	# Play descent animation with sound
	_export_sound.play()
	await _play_descent_effect()

	# Perform export
	var result = PaintingExporter.export_painting(painting)

	var png_path = ""
	var glb_path = ""

	if not result.is_empty():
		png_path = result.get("png", "")
		glb_path = result.get("glb", "")

	# Upload to gallery (non-blocking)
	if not png_path.is_empty() and not glb_path.is_empty():
		GalleryUploader.upload_painting(png_path, glb_path, painting.painting_name, painting.artist_statement)

	# Remove painting from game (it's been "shipped")
	paintings_inside.erase(painting)
	painting.queue_free()  # This will auto-unregister from WorldStateManager via _exit_tree()

	# Ascend back up
	await _play_ascent_effect()

	# Open gate after export
	gate_state = GateState.ANIMATING
	_door_sound.play()
	if gate_animation_player and gate_animation_player.has_animation("open"):
		gate_animation_player.play("open")
		await gate_animation_player.animation_finished
	gate_state = GateState.OPEN
	gate_opened.emit()

	is_exporting = false
	export_completed.emit(png_path, glb_path)


func _play_descent_effect() -> void:
	"""Animate the elevator descending"""
	if not moving_parts:
		await get_tree().create_timer(descent_duration).timeout
		return

	var start_pos = moving_parts.position
	var end_pos = start_pos - Vector3(0, descent_distance, 0)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(moving_parts, "position", end_pos, descent_duration)
	await tween.finished

func _play_ascent_effect() -> void:
	"""Animate the elevator ascending back up"""
	if not moving_parts:
		await get_tree().create_timer(descent_duration).timeout
		return

	var start_pos = moving_parts.position
	var end_pos = Vector3.ZERO  # Return to original position

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(moving_parts, "position", end_pos, descent_duration)
	await tween.finished
