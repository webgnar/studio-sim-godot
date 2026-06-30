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
signal foreign_object_entered(body: RigidBody3D)
signal foreign_object_exited(body: RigidBody3D)
signal gate_clearance_changed()  ## Emitted when a painting starts/stops blocking the gate

enum GateState { OPEN, CLOSED, ANIMATING }

@export_group("References")
@export var detection_area: Area3D
@export var gate_animation_player: AnimationPlayer
@export var moving_parts: Node3D  ## The node that descends during export
@export var gallery_spawn_point: Node3D  ## Drop point in gallery room for shipped paintings
@export var gate_clearance_area: Area3D  ## Thin zone at the gate threshold — detects painting blocking the gate

@export_group("Export Settings")
@export var descent_duration: float = 1.5  ## Duration of descent animation
@export var descent_distance: float = 10.0  ## How far the elevator descends

# State
var paintings_inside: Array[CarryablePainting] = []
var gate_state: GateState = GateState.OPEN
var is_exporting: bool = false

# Player detection for elevator achievement
var player_detection_area: Area3D
var player_inside_elevator: bool = false

# Foreign object detection (non-painting items that shouldn't be in elevator)
var foreign_objects_inside: Array[RigidBody3D] = []
var foreign_object_detection_area: Area3D

# Gate clearance — paintings overlapping the gate threshold
var paintings_blocking_gate: Array[CarryablePainting] = []

# Tracks the painting_id of an in-flight gallery upload so we can save the gallery_id on completion
var _pending_upload_painting_id: String = ""

# Audio
var _export_sound: AudioStreamPlayer3D
var _door_sound: AudioStreamPlayer3D
var _door_open_sound: AudioStreamPlayer3D
var _slam_sound: AudioStreamPlayer3D
var _error_sound: AudioStreamPlayer3D
var _door_stream: AudioStream = preload("res://sounds/picotron/elevator_door.ogg")
var _door_open_stream: AudioStream = preload("res://sounds/picotron/elevator_door_rev.ogg")
var _slam_stream: AudioStream = preload("res://sounds/picotron/doorslam.ogg")
var _descent_stream: AudioStream = preload("res://sounds/picotron/elevator_down.ogg")
var _error_stream: AudioStream = preload("res://sounds/picotron/error.ogg")

func _ready() -> void:
	# If exports weren't resolved, try to find nodes by path
	if not moving_parts:
		moving_parts = get_node_or_null("MovingParts")

	if not detection_area:
		detection_area = get_node_or_null("MovingParts/PaintingDetectionArea")

	if not gate_animation_player:
		gate_animation_player = get_node_or_null("MovingParts/gate/AnimationPlayer")

	# NOTE: gallery_spawn_point lookup is deferred to start_export() because GallerySpawnPoint
	# (a sibling in world.tscn) may not be in the scene tree yet when _ready() runs on
	# instanced subscenes. If assigned via the Inspector, this block is skipped.

	# Connect Area3D signals if found
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("ElevatorController: No detection_area found!")

	# Setup player detection for achievement
	_setup_player_detection()
	_setup_foreign_object_detection()

	# Connect gate clearance area (fallback to node path if not assigned in Inspector)
	if not gate_clearance_area:
		gate_clearance_area = get_node_or_null("MovingParts/GateClearanceArea")
	if gate_clearance_area:
		gate_clearance_area.body_entered.connect(_on_gate_clearance_body_entered)
		gate_clearance_area.body_exited.connect(_on_gate_clearance_body_exited)
	else:
		push_warning("ElevatorController: No gate_clearance_area found!")

	# Connect gate_closed for elevator achievement
	gate_closed.connect(_on_gate_closed_check_player)

	# Save gallery_id back to the painting when an upload finishes
	GalleryUploader.upload_completed.connect(_on_gallery_upload_completed)

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

	_door_open_sound = AudioStreamPlayer3D.new()
	_door_open_sound.name = "DoorOpenSound"
	_door_open_sound.max_distance = 15.0
	_door_open_sound.bus = "SFX"
	_door_open_sound.stream = _door_open_stream
	add_child(_door_open_sound)

	_slam_sound = AudioStreamPlayer3D.new()
	_slam_sound.name = "SlamSound"
	_slam_sound.max_distance = 15.0
	_slam_sound.bus = "SFX"
	_slam_sound.stream = _slam_stream
	add_child(_slam_sound)

	_error_sound = AudioStreamPlayer3D.new()
	_error_sound.name = "ErrorSound"
	_error_sound.max_distance = 15.0
	_error_sound.bus = "SFX"
	_error_sound.stream = _error_stream
	add_child(_error_sound)

func _setup_player_detection() -> void:
	"""Create an Area3D to detect the player inside the elevator (for achievement)"""
	player_detection_area = Area3D.new()
	player_detection_area.name = "PlayerDetectionArea"
	player_detection_area.collision_layer = 0
	player_detection_area.collision_mask = 1  # Player's CharacterBody3D layer
	player_detection_area.monitoring = true
	player_detection_area.monitorable = false

	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3.2, 2.5, 3.0)  # Match PaintingDetectionArea dimensions
	shape.shape = box

	player_detection_area.add_child(shape)
	player_detection_area.position = Vector3(2.1, 1.0, 0.75)  # Match PaintingDetectionArea position

	if moving_parts:
		moving_parts.add_child(player_detection_area)
	else:
		add_child(player_detection_area)

	player_detection_area.body_entered.connect(_on_player_entered)
	player_detection_area.body_exited.connect(_on_player_exited)

func _on_player_entered(body: Node) -> void:
	if body is CharacterBody3D:
		player_inside_elevator = true

func _on_player_exited(body: Node) -> void:
	if body is CharacterBody3D:
		player_inside_elevator = false

func _setup_foreign_object_detection() -> void:
	"""Create an Area3D to detect non-painting objects inside the elevator"""
	foreign_object_detection_area = Area3D.new()
	foreign_object_detection_area.name = "ForeignObjectDetectionArea"
	foreign_object_detection_area.collision_layer = 0
	# Layer 3 (moving objects/gun) = 1<<2 = 4, Layer 8 (interactables: nailgun, fan, plug, trash can) = 1<<7 = 128
	foreign_object_detection_area.collision_mask = 132
	foreign_object_detection_area.monitoring = true
	foreign_object_detection_area.monitorable = false

	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3.2, 2.5, 3.0)  # Match PaintingDetectionArea dimensions
	shape.shape = box
	foreign_object_detection_area.add_child(shape)
	foreign_object_detection_area.position = Vector3(2.1, 1.0, 0.75)  # Match PaintingDetectionArea position

	if moving_parts:
		moving_parts.add_child(foreign_object_detection_area)
	else:
		add_child(foreign_object_detection_area)

	foreign_object_detection_area.body_entered.connect(_on_foreign_body_entered)
	foreign_object_detection_area.body_exited.connect(_on_foreign_body_exited)

func _on_foreign_body_entered(body: Node) -> void:
	if body is CarryablePainting:
		return  # paintings are handled by PaintingDetectionArea
	if body is RigidBody3D:
		if body not in foreign_objects_inside:
			foreign_objects_inside.append(body)
			foreign_object_entered.emit(body)

func _on_foreign_body_exited(body: Node) -> void:
	if body is RigidBody3D and not body is CarryablePainting:
		foreign_objects_inside.erase(body)
		foreign_object_exited.emit(body)

func _on_gate_clearance_body_entered(body: Node) -> void:
	if body is CarryablePainting and body not in paintings_blocking_gate:
		paintings_blocking_gate.append(body)
		gate_clearance_changed.emit()

func _on_gate_clearance_body_exited(body: Node) -> void:
	if body is CarryablePainting:
		paintings_blocking_gate.erase(body)
		gate_clearance_changed.emit()

func is_painting_blocking_gate() -> bool:
	if not gate_clearance_area:
		return not paintings_blocking_gate.is_empty()
	var shape_node := gate_clearance_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not shape_node or not shape_node.shape:
		return not paintings_blocking_gate.is_empty()
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = 4
	for result in space_state.intersect_shape(query, 8):
		if result["collider"] is CarryablePainting:
			return true
	return false

func _on_gallery_upload_completed(gallery_id: String) -> void:
	"""Save the gallery_id onto the painting that was just uploaded."""
	if _pending_upload_painting_id != "":
		WorldStateManager.save_gallery_id_for_painting(_pending_upload_painting_id, gallery_id)
		_pending_upload_painting_id = ""

func _on_gate_closed_check_player() -> void:
	"""Check if player is trapped inside when gate closes"""
	if player_inside_elevator and SteamManager:
		SteamManager.unlock_achievement("ACH_ELEVATOR")

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
	_door_open_sound.play()

	if gate_animation_player and gate_animation_player.has_animation("open"):
		gate_animation_player.play("open")
		await gate_animation_player.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout

	gate_state = GateState.OPEN
	gate_opened.emit()

func has_too_many_paintings() -> bool:
	return paintings_inside.size() > 1

func has_foreign_objects() -> bool:
	return not foreign_objects_inside.is_empty()

func play_error_sound() -> void:
	_error_sound.play()

func close_gate() -> void:
	"""Close the elevator gate"""
	if not can_toggle_gate() or gate_state == GateState.CLOSED:
		return

	if is_painting_blocking_gate():
		await _play_gate_blocked_bounce()
		return

	gate_state = GateState.ANIMATING
	_door_sound.play()

	if gate_animation_player and gate_animation_player.has_animation("close"):
		gate_animation_player.play("close")
		get_tree().create_timer(0.24).timeout.connect(func(): _slam_sound.play())
		await gate_animation_player.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout

	gate_state = GateState.CLOSED
	gate_closed.emit()

func _play_gate_blocked_bounce() -> void:
	"""Gate tries to close but a painting is blocking the threshold — bounce back open."""
	gate_state = GateState.ANIMATING
	_door_sound.play()

	if gate_animation_player and gate_animation_player.has_animation("close"):
		gate_animation_player.play("close")
		# Let the gate descend about 45% of the way before hitting the painting
		await get_tree().create_timer(0.45).timeout
		# Reverse from current position by flipping speed_scale (play_backwards would snap to end)
		gate_animation_player.speed_scale = -1.0
		_error_sound.play()  # play at impact moment, not after reopening
		_door_open_sound.play()
		await gate_animation_player.animation_finished
		gate_animation_player.speed_scale = 1.0
	else:
		await get_tree().create_timer(0.5).timeout

	gate_state = GateState.OPEN

func toggle_gate() -> void:
	"""Toggle gate between open and closed"""
	if gate_state == GateState.OPEN:
		close_gate()
	elif gate_state == GateState.CLOSED:
		open_gate()

# --- Export Control ---

func can_export() -> bool:
	"""Check if export is possible (painting inside, gate closed, not already exporting)"""
	return not paintings_inside.is_empty() and gate_state == GateState.CLOSED and not is_exporting and not has_foreign_objects()

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

	# Freeze painting before descent so it rides with the elevator, not physics
	painting.freeze = true
	_export_sound.play()
	await _play_descent_effect(painting)

	# Perform export
	var result = PaintingExporter.export_painting(painting)

	var png_path = ""
	var glb_path = ""

	if not result.is_empty():
		png_path = result.get("png", "")
		glb_path = result.get("glb", "")

	# Read social handles from settings
	var instagram_handle: String = ""
	var bluesky_handle: String = ""
	if FileAccess.file_exists("user://settings.json"):
		var sj_file = FileAccess.open("user://settings.json", FileAccess.READ)
		if sj_file:
			var sj_json = JSON.new()
			if sj_json.parse(sj_file.get_as_text()) == OK and typeof(sj_json.data) == TYPE_DICTIONARY:
				if sj_json.data.has("instagram_handle"):
					var raw = str(sj_json.data["instagram_handle"]).strip_edges()
					if raw != "":
						instagram_handle = ("@" + raw) if not raw.begins_with("@") else raw
				if sj_json.data.has("bluesky_handle"):
					var raw2 = str(sj_json.data["bluesky_handle"]).strip_edges()
					if raw2 != "":
						bluesky_handle = ("@" + raw2) if not raw2.begins_with("@") else raw2
			sj_file.close()

	# Upload to gallery (non-blocking)
	if not png_path.is_empty() and not glb_path.is_empty():
		_pending_upload_painting_id = painting.painting_id
		GalleryUploader.upload_painting(png_path, glb_path, painting.painting_name, painting.artist_statement, SteamManager.persona_name, instagram_handle, bluesky_handle)

	# Ship painting to gallery — mark as SHIPPED and teleport to gallery room
	WorldStateManager.ship_painting(painting)
	if has_node("/root/EconomyManager"):
		var viewer_count: int = 0
		if has_node("/root/WorldStateManager"):
			viewer_count = WorldStateManager.get_gallery_visitor_count()
		var commission_multiplier: float = 0.25 if painting.is_commissioned else 1.0
		var ship_price: int = int(275.0 * (1.0 + viewer_count * 0.15) * commission_multiplier)
		EconomyManager.add_money(ship_price, "shipped: " + painting.painting_name)
	paintings_inside.erase(painting)

	# Late lookup: find GallerySpawnPoint now if not already set via Inspector.
	# Done here (not in _ready) because sibling nodes aren't guaranteed to be in the
	# tree yet when an instanced subscene's _ready() fires.
	if not gallery_spawn_point:
		gallery_spawn_point = get_parent().find_child("GallerySpawnPoint", true, false) as Node3D

	# Teleport painting to gallery spawn point (scatter slightly so multiple don't stack)
	# painting.freeze is already true from before descent
	if gallery_spawn_point:
		var offset = Vector3(randf_range(-3.0, 3.0), 0.5, randf_range(-3.0, 3.0))
		painting.global_position = gallery_spawn_point.global_position + offset
		painting.global_rotation = Vector3(0, randf_range(-PI * 0.1, PI * 0.1), 0)
		painting.freeze = false
		painting.linear_velocity = Vector3.ZERO
		painting.angular_velocity = Vector3.ZERO
	else:
		push_warning("ElevatorController: gallery_spawn_point not set — painting freed instead")
		painting.queue_free()

	# Save game state after shipping
	var save_success = await WorldStateManager.save_world_state()
	if save_success:
		var save_notification = get_tree().root.get_node_or_null("World/GameplayUI_Layer/SaveNotification")
		if save_notification and save_notification.has_method("show_notification"):
			save_notification.show_notification()

	# Ascend back up
	await _play_ascent_effect()

	# Open gate after export
	gate_state = GateState.ANIMATING
	_door_open_sound.play()
	if gate_animation_player and gate_animation_player.has_animation("open"):
		gate_animation_player.play("open")
		await gate_animation_player.animation_finished
	gate_state = GateState.OPEN
	is_exporting = false
	gate_opened.emit()
	export_completed.emit(png_path, glb_path)


func _play_descent_effect(painting: RigidBody3D = null) -> void:
	"""Animate the elevator descending. Pass painting to have it ride along."""
	if not moving_parts:
		await get_tree().create_timer(descent_duration).timeout
		return

	var start_pos = moving_parts.position
	var end_pos = start_pos - Vector3(0, descent_distance, 0)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(moving_parts, "position", end_pos, descent_duration)

	if painting:
		# Mirror the painting's world-space position to match moving_parts' descent.
		# moving_parts moves (0, -descent_distance, 0) in its parent's local space;
		# multiply by the parent's basis to get the equivalent world-space delta.
		var world_delta = moving_parts.get_parent().global_transform.basis * Vector3(0, -descent_distance, 0)
		tween.parallel().tween_property(painting, "global_position", painting.global_position + world_delta, descent_duration)

	await tween.finished

func _play_ascent_effect() -> void:
	"""Animate the elevator ascending back up"""
	if not moving_parts:
		await get_tree().create_timer(descent_duration).timeout
		return

	var end_pos = Vector3.ZERO  # Return to original position

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(moving_parts, "position", end_pos, descent_duration)
	await tween.finished
