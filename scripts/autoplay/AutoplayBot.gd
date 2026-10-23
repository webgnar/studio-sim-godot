extends Node

## The idle autoplay "brain". AutoplayManager decides WHEN the bot runs;
## this decides WHAT it does. Each behavior is a coroutine gated by what the
## player has unlocked. Behaviors check still_running(token) after every
## await, so any input stops them on the spot.
##
## It gets around like a player: it pathfinds on foot (AutoplayNavigation)
## and never teleports.
##
## Behaviors:
## - Wander: walk to a random reachable spot and look around.
## - Paint: walk to the studio canvas and paint it in plain view: the sticker
##   ghost is dragged around the canvas, rotated and sized, then placed, the
##   same way a player paints. WHAT it paints comes from AutoplayPainter (the
##   tuning surface); this file only performs it. When done it detaches the
##   painting with the red button and starts a fresh one.

const STAND_DISTANCE := 2.2         ## metres in front of the canvas
const WAYPOINT_REACHED := 0.4
const ARRIVE_DISTANCE := 0.6        ## close enough to the final destination
const STUCK_TIMEOUT := 2.0          ## seconds without progress before re-planning
const STUCK_PROGRESS := 0.25        ## metres that count as progress
const MAX_REPLANS := 3
const BUTTON_REACH := 2.5           ## press the detach button from at most this far
const EYE_HEIGHT := 1.6

const PAINT_CHANCE := 0.6           ## per cycle, when painting is available
const WANDER_STOPS_MIN := 1
const WANDER_STOPS_MAX := 3
const LOOK_AROUND_MIN := 1.5        ## seconds spent looking around at each wander stop
const LOOK_AROUND_MAX := 4.0


## Detached paintings pile up on the floor, so stop detaching after this many
## per autoplay session and just keep painting the current canvas.
const MAX_DETACHES_PER_SESSION := 3

var player: Node3D = null
var nav: Node = null  ## AutoplayNavigation, set by AutoplayManager

var _token: int = 0
var _detaches_this_session: int = 0
var _saved_selection: Dictionary = {}
var painter: AutoplayPainter = preload("res://scripts/autoplay/AutoplayPainter.gd").new()


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
	player = null


func still_running(token: int) -> bool:
	return token == _token and is_instance_valid(player)


# --- Main loop ---

func _run(token: int) -> void:
	if not await nav.ensure_baked(get_tree().current_scene):
		return
	if not still_running(token):
		return
	while still_running(token):
		var did_something := false
		if _can_paint() and randf() < PAINT_CHANCE:
			did_something = await _paint_canvas(token)
		if not did_something and still_running(token):
			did_something = await _wander(token)
		if not did_something:
			# Nothing reachable to do right now; stand around and try again.
			if not await _look_around(token, 3.0):
				return


func _can_paint() -> bool:
	return PaintingModeManager.painting_system_2d != null \
		and is_instance_valid(PaintingModeManager.painting_system_2d) \
		and not StickerLibrary.sticker_library.is_empty()


# --- Behavior: wander ---

func _wander(token: int) -> bool:
	var moved := false
	for i in randi_range(WANDER_STOPS_MIN, WANDER_STOPS_MAX):
		var spot = nav.random_reachable_point(player.global_position)
		if spot == null:
			break
		if not await _go_to(token, spot):
			if not still_running(token):
				return false
			continue
		moved = true
		if not await _look_around(token, randf_range(LOOK_AROUND_MIN, LOOK_AROUND_MAX)):
			return false
	return moved


func _look_around(token: int, seconds: float) -> bool:
	"""Glance in a couple of random directions, like someone taking in the room."""
	var t := 0.0
	while t < seconds:
		var yaw := randf_range(-PI, PI)
		var look := player.global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 5.0
		look.y += EYE_HEIGHT + randf_range(-1.0, 1.0)
		player.autoplay_look_at(look)
		var pause := randf_range(1.0, 2.0)
		if not await _wait(token, pause):
			return false
		t += pause
	return true


# --- Behavior: paint and detach ---

func _paint_canvas(token: int) -> bool:
	var system: PaintingSystem2D = PaintingModeManager.painting_system_2d
	var plane: MeshInstance3D = system.painting_plane
	if not plane:
		return false

	var stand := _stand_point_for(plane)
	if not nav.can_reach(player.global_position, stand):
		return false
	if not await _go_to(token, stand):
		return false
	player.autoplay_look_at(plane.global_position)
	if not await _wait_for_look(token):
		return false

	for i in painter.stroke_count():
		if not still_running(token):
			return false
		# The canvas may have been replaced (format toggle, detach) mid-loop
		if PaintingModeManager.painting_system_2d != system:
			return true
		if not await _perform_stroke(token, system, painter.next_stroke(system, i)):
			return false
		if not await _wait(token, painter.pause_after_time()):
			return false

	if _detaches_this_session < MAX_DETACHES_PER_SESSION:
		if await _press_detach_button(token):
			_detaches_this_session += 1
	return true


func _perform_stroke(token: int, system: PaintingSystem2D, stroke: Dictionary) -> bool:
	"""Show the chosen sticker as the ghost, drag it through the stroke's
	waypoints while easing into its rotation and size, then place it."""
	PaintingModeManager.sync_sticker_selection(stroke.sticker_index)
	var start_rot := system.preview_rotation
	var end_rot := start_rot + wrapf(stroke.rotation_deg - start_rot, -180.0, 180.0)
	var start_scale := system.preview_scale_multiplier
	var waypoints: Array = stroke.waypoints

	var from_uv := _aim_uv(system)
	var total := 0.0
	for wp in waypoints:
		total += painter.drag_time(from_uv, wp)
		from_uv = wp
	var elapsed := 0.0
	from_uv = _aim_uv(system)

	for i in waypoints.size():
		var to_uv: Vector2 = waypoints[i]
		var duration := painter.drag_time(from_uv, to_uv)
		var t := 0.0
		while t < duration:
			if not still_running(token) or PaintingModeManager.painting_system_2d != system:
				return still_running(token)
			await get_tree().process_frame
			var dt := get_process_delta_time()
			t += dt
			elapsed += dt
			var k := smoothstep(0.0, 1.0, clampf(t / duration, 0.0, 1.0))
			player.autoplay_look_at(_uv_to_world(system, from_uv.lerp(to_uv, k)))
			var overall := clampf(elapsed / total, 0.0, 1.0) if total > 0.0 else 1.0
			_set_ghost_pose(system, lerpf(start_rot, end_rot, overall), lerpf(start_scale, stroke.scale, overall))
		from_uv = to_uv
		var last := i == waypoints.size() - 1
		if not await _wait(token, painter.settle_time() if last else painter.hover_time()):
			return false

	_set_ghost_pose(system, end_rot, stroke.scale)
	if not await _wait_for_look(token, 0.5):
		return false
	_click_canvas()
	return true


func _set_ghost_pose(system: PaintingSystem2D, rotation_deg: float, scale_mult: float) -> void:
	system.preview_rotation = fposmod(rotation_deg, 360.0)
	system.preview_scale_multiplier = scale_mult
	if system.preview_sprite:
		system.preview_sprite.rotation_degrees = system.preview_rotation
	system._update_preview_scale()
	# Keep the ghost fully visible while the bot works it
	system.preview_idle_time = 0.0
	system.preview_target_opacity = system.preview_base_opacity


func _click_canvas() -> void:
	"""'Click' exactly the way PaintingModeManager does for the player: ray
	from the screen centre, routed to whichever canvas it hits."""
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
		if not await _go_to(token, approach):
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

# PaintingSystem2D maps the plane's local X/Z to the canvas (see _world_to_viewport_coords),
# so canvas UV (0..1 from the top-left of the image) <-> plane local is a straight scale.

func _uv_to_world(system: PaintingSystem2D, uv: Vector2) -> Vector3:
	var local := Vector3((uv.x - 0.5) * system.plane_width, 0.0, (uv.y - 0.5) * system.plane_height)
	return system.painting_plane.to_global(local)


func _aim_uv(system: PaintingSystem2D) -> Vector2:
	"""Where the ghost is now: the canvas point under the screen centre, or the
	canvas centre if the player isn't looking at it."""
	var hit := PaintingModeManager._perform_unified_raycast()
	if hit and PaintingModeManager._is_canvas_plane(hit):
		var local: Vector3 = system.painting_plane.to_local(hit.position)
		return Vector2(local.x / system.plane_width + 0.5, local.z / system.plane_height + 0.5)
	return Vector2(0.5, 0.5)


func _stand_point_for(plane: MeshInstance3D) -> Vector3:
	"""A spot on the open side of the canvas. The canvas hangs on a wall, so
	the side whose ray hits something right away is the back."""
	var normal := plane.global_basis.y.normalized()
	var front := normal
	if _blocked_within(plane.global_position, normal, STAND_DISTANCE):
		front = -normal
	# Snap to the walkable floor in front of the canvas
	return nav.closest_point(plane.global_position + front * STAND_DISTANCE + Vector3.DOWN * 1.5)


func _blocked_within(from: Vector3, dir: Vector3, dist: float) -> bool:
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from + dir * 0.05, from + dir * dist)
	query.exclude = [player.get_rid()]
	return not space.intersect_ray(query).is_empty()


# --- Movement ---

func _go_to(token: int, destination: Vector3) -> bool:
	"""Pathfind on foot to `destination`. Re-plans when blocked (a moved prop,
	a closed door); gives up after MAX_REPLANS."""
	for attempt in MAX_REPLANS:
		if not still_running(token):
			return false
		var path: PackedVector3Array = nav.find_path(player.global_position, destination)
		if path.is_empty():
			return false
		var result := await _follow_path(token, path)
		if result:
			return _flat_distance(player.global_position, nav.closest_point(destination)) <= ARRIVE_DISTANCE + 0.3
		if not still_running(token):
			return false
	return false


func _follow_path(token: int, path: PackedVector3Array) -> bool:
	"""Walk the path waypoint by waypoint. Returns false if stuck."""
	var i := 0
	var best_dist := INF
	var since_progress := 0.0
	while still_running(token):
		# Skip waypoints we've already passed
		while i < path.size() - 1 and _flat_distance(player.global_position, path[i]) <= WAYPOINT_REACHED:
			i += 1
			best_dist = INF
		var target := path[i]
		var to := target - player.global_position
		to.y = 0.0
		var dist := to.length()
		var is_last := i == path.size() - 1
		if is_last and dist <= ARRIVE_DISTANCE:
			player.autoplay_move = Vector2.ZERO
			return true

		# Face where we're heading and walk forward, like a player would
		player.autoplay_look_at(player.global_position + to.normalized() * 4.0 + Vector3.UP * EYE_HEIGHT)
		var local: Vector3 = player.global_basis.inverse() * to.normalized()
		var speed := clampf(dist, 0.4, 1.0) if is_last else 1.0
		player.autoplay_move = Vector2(local.x, local.z).normalized() * speed

		await get_tree().physics_frame
		if dist < best_dist - STUCK_PROGRESS:
			best_dist = dist
			since_progress = 0.0
		else:
			since_progress += get_physics_process_delta_time()
			if since_progress > STUCK_TIMEOUT:
				print("AutoplayBot: snagged at %s heading to %s, re-planning" % [player.global_position, target])
				player.autoplay_move = Vector2.ZERO
				return false
	if is_instance_valid(player):
		player.autoplay_move = Vector2.ZERO
	return false


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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
