extends Node

## The idle autoplay "brain". AutoplayManager decides WHEN the bot runs;
## this decides WHAT it does. Each behavior is a coroutine gated by what the
## player has unlocked. Behaviors check still_running(token) after every
## await, so any input stops them on the spot.
##
## v1 behavior: paint the studio canvas like the assistant does (random owned
## stickers, random spots, rotation and size), then detach it with the red
## button and start a fresh one.

const WALK_MAX_DISTANCE := 12.0     ## further than this (or another floor) = fade and reposition instead
const WALK_MAX_HEIGHT_DIFF := 1.5
const STAND_DISTANCE := 2.2         ## metres in front of the canvas
const ARRIVE_DISTANCE := 0.35
const STUCK_TIMEOUT := 1.5          ## seconds without progress before giving up on walking
const STUCK_PROGRESS := 0.25        ## metres that count as progress
const BUTTON_REACH := 2.5           ## press the detach button from at most this far

const STICKERS_MIN := 12
const STICKERS_MAX := 30
const STICKER_PAUSE_MIN := 0.5      ## seconds between stickers, so it paints at a human pace
const STICKER_PAUSE_MAX := 1.6
const SCALE_MIN := 0.5
const SCALE_MAX := 1.6
const CANVAS_EDGE_MARGIN := 0.08    ## keep sticker centres this fraction away from the canvas edges

## Detached paintings pile up on the floor, so stop detaching after this many
## per autoplay session and just keep painting the current canvas.
const MAX_DETACHES_PER_SESSION := 3

var player: Node3D = null
var fade_rect: ColorRect = null    ## set by AutoplayManager; ours alone, so a stop can always clear it

var _token: int = 0
var _detaches_this_session: int = 0
var _saved_selection: Dictionary = {}


func begin(target_player: Node3D) -> void:
	player = target_player
	_token += 1
	_detaches_this_session = 0
	_save_player_selection()
	_run(_token)


func end() -> void:
	_token += 1  # invalidates every pending coroutine step
	if is_instance_valid(player):
		player.autoplay_move = Vector2.ZERO
	_restore_player_selection()
	if fade_rect:
		fade_rect.color.a = 0.0
	player = null


func still_running(token: int) -> bool:
	return token == _token and is_instance_valid(player)


# --- Main loop ---

func _run(token: int) -> void:
	while still_running(token):
		var did_something := false
		if _can_paint():
			did_something = await _paint_canvas(token)
		if not did_something:
			# Nothing available to do right now; idle quietly and look again.
			if not await _wait(token, 3.0):
				return


func _can_paint() -> bool:
	return PaintingModeManager.painting_system_2d != null \
		and is_instance_valid(PaintingModeManager.painting_system_2d) \
		and not StickerLibrary.sticker_library.is_empty()


# --- Behavior: paint and detach ---

func _paint_canvas(token: int) -> bool:
	var system: PaintingSystem2D = PaintingModeManager.painting_system_2d
	var plane: MeshInstance3D = system.painting_plane
	if not plane:
		return false

	var stand := _stand_point_for(plane)
	if not await _go_to(token, stand, plane.global_position):
		return false

	var count := randi_range(STICKERS_MIN, STICKERS_MAX)
	for i in count:
		if not still_running(token):
			return false
		# The canvas may have been replaced (format toggle, detach) mid-loop
		if PaintingModeManager.painting_system_2d != system:
			return true
		var target := _random_point_on(system)
		player.autoplay_look_at(target)
		if not await _wait_for_look(token):
			return false
		_place_sticker(system)
		if not await _wait(token, randf_range(STICKER_PAUSE_MIN, STICKER_PAUSE_MAX)):
			return false

	if _detaches_this_session < MAX_DETACHES_PER_SESSION:
		if await _press_detach_button(token):
			_detaches_this_session += 1
	return true


func _place_sticker(system: PaintingSystem2D) -> void:
	"""Pick a random owned sticker, rotation and size, then 'click' exactly the
	way PaintingModeManager does for the player: ray from the screen centre."""
	var library := StickerLibrary.sticker_library
	PaintingModeManager.sync_sticker_selection(randi() % library.size())
	system.preview_rotation = randf_range(0.0, 360.0)
	if system.preview_sprite:
		system.preview_sprite.rotation_degrees = system.preview_rotation
	system.preview_scale_multiplier = randf_range(SCALE_MIN, SCALE_MAX)
	system._update_preview_scale()

	var hit := PaintingModeManager._perform_unified_raycast()
	if hit and PaintingModeManager._is_canvas_plane(hit):
		var target_2d := PaintingModeManager._resolve_2d_system(hit.collider)
		if target_2d:
			target_2d.handle_primary_action(hit)


func _press_detach_button(token: int) -> bool:
	var button := _find_detach_button()
	if not button:
		return false
	var button_pos: Vector3 = button.get_parent().global_position
	if player.global_position.distance_to(button_pos) > BUTTON_REACH + 1.0:
		var approach := button_pos + (player.global_position - button_pos).normalized() * BUTTON_REACH
		approach.y = player.global_position.y
		if not await _go_to(token, approach, button_pos):
			return false
	player.autoplay_look_at(button_pos)
	if not await _wait_for_look(token):
		return false
	if not await _wait(token, 0.4):
		return false
	var interaction = player.get("_interaction_component")
	button.interact(interaction)
	return await _wait(token, 1.5)


func _find_detach_button() -> PaintingConvertButton:
	return _find_node_of_type(get_tree().current_scene)


func _find_node_of_type(node: Node) -> PaintingConvertButton:
	if node is PaintingConvertButton:
		return node
	for child in node.get_children():
		var found := _find_node_of_type(child)
		if found:
			return found
	return null


# --- Canvas geometry ---

func _random_point_on(system: PaintingSystem2D) -> Vector3:
	# PaintingSystem2D maps the plane's local X/Z to the canvas (see _world_to_viewport_coords)
	var half_w := system.plane_width * (0.5 - CANVAS_EDGE_MARGIN)
	var half_h := system.plane_height * (0.5 - CANVAS_EDGE_MARGIN)
	var local := Vector3(randf_range(-half_w, half_w), 0.0, randf_range(-half_h, half_h))
	return system.painting_plane.to_global(local)


func _stand_point_for(plane: MeshInstance3D) -> Vector3:
	"""A spot on the open side of the canvas. The canvas hangs on a wall, so
	the side whose ray hits something right away is the back."""
	var normal := plane.global_basis.y.normalized()
	var front := normal
	if _blocked_within(plane.global_position, normal, STAND_DISTANCE):
		front = -normal
	var stand := plane.global_position + front * STAND_DISTANCE
	stand.y = player.global_position.y if absf(player.global_position.y - plane.global_position.y) < 3.0 \
		else plane.global_position.y - 1.0
	return stand


func _blocked_within(from: Vector3, dir: Vector3, dist: float) -> bool:
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from + dir * 0.05, from + dir * dist)
	query.exclude = [player.get_rid()]
	return not space.intersect_ray(query).is_empty()


# --- Movement ---

func _go_to(token: int, destination: Vector3, look_target: Vector3) -> bool:
	var offset := destination - player.global_position
	var far := Vector2(offset.x, offset.z).length() > WALK_MAX_DISTANCE \
		or absf(offset.y) > WALK_MAX_HEIGHT_DIFF
	if far or not await _walk_to(token, destination):
		if not still_running(token):
			return false
		if not await _fade_reposition(token, destination):
			return false
	player.autoplay_look_at(look_target)
	return await _wait_for_look(token)


func _walk_to(token: int, destination: Vector3) -> bool:
	"""Straight-line walk. Returns false if something blocks the way."""
	var best_dist := INF
	var since_progress := 0.0
	while still_running(token):
		var to := destination - player.global_position
		to.y = 0.0
		var dist := to.length()
		if dist <= ARRIVE_DISTANCE:
			player.autoplay_move = Vector2.ZERO
			return true
		# Face the destination and walk forward, like a player would
		player.autoplay_look_at(player.global_position + to + Vector3.UP * 1.5)
		var local: Vector3 = player.global_basis.inverse() * to.normalized()
		player.autoplay_move = Vector2(local.x, local.z).normalized() * clampf(dist, 0.3, 1.0)

		await get_tree().physics_frame
		var step := get_physics_process_delta_time()
		if dist < best_dist - STUCK_PROGRESS:
			best_dist = dist
			since_progress = 0.0
		else:
			since_progress += step
			if since_progress > STUCK_TIMEOUT:
				player.autoplay_move = Vector2.ZERO
				return false
	if is_instance_valid(player):
		player.autoplay_move = Vector2.ZERO
	return false


func _fade_reposition(token: int, destination: Vector3) -> bool:
	if not await _fade_to(token, 1.0, 0.5):
		return false
	player.global_position = destination
	player.velocity = Vector3.ZERO
	if not await _wait(token, 0.2):
		return false
	return await _fade_to(token, 0.0, 0.5)


func _fade_to(token: int, alpha: float, duration: float) -> bool:
	if not fade_rect:
		return still_running(token)
	var start := fade_rect.color.a
	var t := 0.0
	while t < duration:
		if not still_running(token):
			return false
		await get_tree().process_frame
		t += get_process_delta_time()
		fade_rect.color.a = lerpf(start, alpha, clampf(t / duration, 0.0, 1.0))
	return still_running(token)


# --- Waiting helpers ---

func _wait(token: int, seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	return still_running(token)


func _wait_for_look(token: int, timeout: float = 2.0) -> bool:
	var t := 0.0
	while still_running(token) and not player.autoplay_look_settled() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	return still_running(token)


# --- Leave the player's painting tools as they were ---

func _save_player_selection() -> void:
	var system = PaintingModeManager.painting_system_2d
	if not system or not is_instance_valid(system):
		_saved_selection = {}
		return
	_saved_selection = {
		"system": system,
		"index": system.selected_sticker_index,
		"rotation": system.preview_rotation,
		"scale": system.preview_scale_multiplier,
	}


func _restore_player_selection() -> void:
	if _saved_selection.is_empty():
		return
	var system = _saved_selection["system"]
	if is_instance_valid(system) and system == PaintingModeManager.painting_system_2d:
		system.preview_rotation = _saved_selection["rotation"]
		system.preview_scale_multiplier = _saved_selection["scale"]
		if system.preview_sprite:
			system.preview_sprite.rotation_degrees = system.preview_rotation
	if _saved_selection["index"] < StickerLibrary.sticker_library.size():
		PaintingModeManager.sync_sticker_selection(_saved_selection["index"])
	_saved_selection = {}
