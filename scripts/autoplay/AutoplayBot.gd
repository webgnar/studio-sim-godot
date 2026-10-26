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
## - Clear the canvas: detached paintings land in front of the fresh canvas,
##   so the bot carries each one off and tosses it onto a pile in a studio
##   corner, then paints.

const STAND_DISTANCE := 2.2         ## metres in front of the canvas
const WAYPOINT_REACHED := 0.4
const ARRIVE_DISTANCE := 0.6        ## close enough to the final destination
const STUCK_TIMEOUT := 2.0          ## seconds without progress before re-planning
const STUCK_PROGRESS := 0.25        ## metres that count as progress
const MAX_REPLANS := 3
const BUTTON_REACH := 2.5           ## press the detach button from at most this far
const EYE_HEIGHT := 1.6

const STEP_BACK_EVERY_MIN := 45.0   ## seconds of painting between steps back from the canvas
const STEP_BACK_EVERY_MAX := 90.0
const STEP_BACK_DISTANCE := 2.0     ## metres the bot backs away from where it paints
const STEP_BACK_LOOK_MIN := 3.0     ## seconds spent looking at the whole painting from there
const STEP_BACK_LOOK_MAX := 7.0

const PAINT_CHANCE := 0.6           ## per cycle, when painting is available
const WANDER_STOPS_MIN := 1
const WANDER_STOPS_MAX := 3
const LOOK_AROUND_MIN := 1.5        ## seconds spent looking around at each wander stop
const LOOK_AROUND_MAX := 4.0

const CLEAR_RADIUS := 3.5           ## loose paintings this close to the canvas get cleared away
const MAX_CLEARS_PER_PASS := 3
const PICKUP_DISTANCE := 1.8        ## grab a painting from this far: it floats 1.5 m in front once held
const MAX_PICKUP_TRIES := 2         ## per painting per session, before leaving it where it is
const TOSS_POWER := 20.0            ## the player's throw is 50; this lobs it a couple of metres
const TOSS_HEIGHT := 0.5            ## aim this high into the corner, so it's slightly downwards
const CORNER_PROBE := 2.5           ## wall rays this long decide what counts as a corner
const CORNER_SEARCH := 15           ## metres around the canvas searched for a corner, on a 1 m grid
const CORNER_MIN_FROM_CANVAS := 5.0
const CORNER_MIN_FROM_DOOR := 3.0
const CORNER_PILE_RADIUS := 3.0     ## paintings this close to the dump corner are already dumped
const TOSS_FROM := 3.0              ## stand this far out from the corner: paintings are 3-5 m wide

## Detached paintings pile up in the dump corner, so stop detaching after this
## many per autoplay session and just keep painting the current canvas.
const MAX_DETACHES_PER_SESSION := 3

var player: Node3D = null
var nav: Node = null  ## AutoplayNavigation, set by AutoplayManager

var _token: int = 0
var _detaches_this_session: int = 0
var _saved_selection: Dictionary = {}
var _carrying: CarryableComponent = null  ## a painting the bot picked up and hasn't tossed yet
var _dump: Dictionary = {}                ## the cached dump corner: {scene, stand, target}
var _pickup_tries: Dictionary = {}        ## painting -> failed pickups this session
var painter: AutoplayPainter = preload("res://scripts/autoplay/AutoplayPainter.gd").new()


func begin(target_player: Node3D) -> void:
	player = target_player
	_token += 1
	_detaches_this_session = 0
	_pickup_tries.clear()
	_save_player_selection()
	_run(_token)


func end() -> void:
	_token += 1  # invalidates every pending coroutine step
	if is_instance_valid(player):
		player.autoplay_move = Vector2.ZERO
	# Don't leave the player holding a painting they never picked up
	if is_instance_valid(_carrying) and _carrying.is_carried:
		_carrying.player_ref.drop_carried_object()
	_carrying = null
	_restore_player_selection()
	player = null


func still_running(token: int) -> bool:
	return token == _token and is_instance_valid(player)


# --- Main loop ---

func _run(token: int) -> void:
	# Rebake every session: props get moved around between sessions
	if not await nav.ensure_baked(get_tree().current_scene, true):
		return
	if not still_running(token):
		return
	while still_running(token):
		var did_something := false
		if _can_paint() and randf() < PAINT_CHANCE:
			did_something = await _paint_canvas(token)
		if not did_something and still_running(token):
			did_something = await _wander(token)
		if not still_running(token):
			return
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
	if not await _clear_canvas_area(token, plane):
		return false
	if not _canvas_visible_from(stand, plane):
		return false
	if not await _go_to(token, stand):
		return false
	player.autoplay_look_at(plane.global_position)
	if not await _wait_for_look(token):
		return false

	painter.begin_painting(system)
	# The plan grows as it goes: mistakes queue their fixes right after them
	var i := 0
	var next_step_back := _now() + randf_range(STEP_BACK_EVERY_MIN, STEP_BACK_EVERY_MAX)
	while i < painter.stroke_count():
		if not still_running(token):
			return false
		# The canvas may have been replaced (format toggle, detach) mid-loop
		if PaintingModeManager.painting_system_2d != system:
			return true
		if _now() >= next_step_back:
			# Like a painter: walk back, take in the whole picture, come back
			if not await _step_back(token, system, stand):
				return false
			next_step_back = _now() + randf_range(STEP_BACK_EVERY_MIN, STEP_BACK_EVERY_MAX)
		var stroke := painter.next_stroke(system, i)
		if stroke.has("stare_uv"):
			# Noticed something off: look at it for a moment first
			player.autoplay_look_at(_uv_to_world(system, stroke.stare_uv))
			if not await _wait_for_look(token) or not await _wait(token, stroke.stare):
				return false
		if stroke.get("undo", false):
			_undo_on_canvas()
		elif not await _perform_stroke(token, system, stroke):
			return false
		painter.after_stroke(i)
		if not await _wait(token, stroke.pause_after):
			return false
		i += 1

	# One last long look at the finished painting
	if not await _step_back(token, system, stand):
		return false
	if _detaches_this_session < MAX_DETACHES_PER_SESSION:
		if await _press_detach_button(token):
			_detaches_this_session += 1
			var fresh: PaintingSystem2D = PaintingModeManager.painting_system_2d
			if fresh and is_instance_valid(fresh) and fresh.painting_plane:
				await _clear_canvas_area(token, fresh.painting_plane)
	return true


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _step_back(token: int, system: PaintingSystem2D, stand: Vector3) -> bool:
	"""Back away from the canvas, look at the whole painting for a while
	(STEP_BACK_LOOK_MIN..MAX seconds), then walk back to where it paints."""
	var plane := system.painting_plane
	var away := stand - plane.global_position
	away.y = 0.0
	if away.length() > 0.01:
		var back: Vector3 = nav.closest_point(stand + away.normalized() * STEP_BACK_DISTANCE)
		if back.distance_to(stand) > 0.5 and nav.can_reach(stand, back):
			if not await _go_to(token, back):
				return false
	player.autoplay_look_at(plane.global_position)
	if not await _wait_for_look(token):
		return false
	if not await _wait(token, randf_range(STEP_BACK_LOOK_MIN, STEP_BACK_LOOK_MAX)):
		return false
	if not await _go_to(token, stand):
		return false
	player.autoplay_look_at(plane.global_position)
	return await _wait_for_look(token)


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
			await get_tree().process_frame
			if not still_running(token) or PaintingModeManager.painting_system_2d != system:
				return still_running(token)
			var dt := get_process_delta_time()
			t += dt
			elapsed += dt
			var k := smoothstep(0.0, 1.0, clampf(t / duration, 0.0, 1.0))
			player.autoplay_look_at(_uv_to_world(system, from_uv.lerp(to_uv, k)))
			var overall := clampf(elapsed / total, 0.0, 1.0) if total > 0.0 else 1.0
			_set_ghost_pose(system, lerpf(start_rot, end_rot, overall), lerpf(start_scale, stroke.scale, overall))
		from_uv = to_uv
		if i == stroke.get("look_away_at", -1):
			# Distracted: glance off the canvas, then look back to a drifted ghost
			if not await _glance_away(token, system, stroke.look_away):
				return false
		var last := i == waypoints.size() - 1
		if not await _wait(token, stroke.settle if last else painter.hover_time()):
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


func _glance_away(token: int, system: PaintingSystem2D, seconds: float) -> bool:
	var plane := system.painting_plane
	var side := plane.global_basis.z.normalized() * randf_range(1.5, 3.0) * (1 if randf() < 0.5 else -1)
	player.autoplay_look_at(plane.global_position + side + Vector3.UP * randf_range(-0.5, 0.8))
	return await _wait(token, seconds)


func _undo_on_canvas() -> void:
	"""Right-click, the way PaintingModeManager does for the player: takes the
	last sticker off whichever canvas is under the screen centre."""
	var hit := PaintingModeManager._perform_unified_raycast()
	if hit and PaintingModeManager._is_canvas_plane(hit):
		var target_2d := PaintingModeManager._resolve_2d_system(hit.collider)
		if target_2d:
			target_2d.handle_secondary_action()


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


# --- Behavior: clear the canvas ---

func _clear_canvas_area(token: int, plane: MeshInstance3D) -> bool:
	"""Carry loose paintings away from the front of the canvas, nearest first.
	Returns false only if the bot was stopped."""
	var cleared := 0
	for painting in _paintings_near(plane):
		if cleared >= MAX_CLEARS_PER_PASS:
			break
		if await _carry_to_dump(token, painting):
			cleared += 1
		if not still_running(token):
			return false
	if cleared > 0:
		# The bake still has the paintings where they were
		await nav.ensure_baked(get_tree().current_scene, true)
	return still_running(token)


func _paintings_near(plane: MeshInstance3D) -> Array:
	"""Loose paintings in front of the canvas: not hung on a nail, not held,
	not already on the pile."""
	var found := []
	var dump = _dump_corner(plane)
	for painting in get_tree().current_scene.find_children("*", "RigidBody3D", true, false):
		if not painting is CarryablePainting:
			continue
		var carry := _carry_component(painting)
		if not carry or carry.is_carried or carry.get("is_resting_on_nail"):
			continue
		if painting.global_position.distance_to(plane.global_position) > CLEAR_RADIUS:
			continue
		if dump and _flat_distance(painting.global_position, dump.target) < CORNER_PILE_RADIUS:
			continue
		if _pickup_tries.get(painting, 0) >= MAX_PICKUP_TRIES:
			continue  # wedged somewhere it can't be pulled out of
		found.append(painting)
	found.sort_custom(func(a, b): return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	return found


func _carry_component(painting: Node) -> CarryableComponent:
	for child in painting.get_children():
		if child is CarryableComponent:
			return child
	return null


func _carry_to_dump(token: int, painting: RigidBody3D) -> bool:
	"""Walk up to a painting, pick it up, carry it to the dump corner and toss
	it onto the pile, the way a player tidies up."""
	var dump = _dump_corner(PaintingModeManager.painting_system_2d.painting_plane)
	var carry := _carry_component(painting)
	if not dump or not carry:
		return false
	# Stand back on the room side: held paintings float 1.5 m in front, and from
	# any closer the bot would be pulling it into the wall behind it
	var away := player.global_position - painting.global_position
	away.y = 0.0
	var near: Vector3 = nav.closest_point(painting.global_position + away.normalized() * PICKUP_DISTANCE)
	if not await _go_to(token, near):
		return false
	if _flat_distance(player.global_position, painting.global_position) > PICKUP_DISTANCE + 1.0:
		return false
	player.autoplay_look_at(Vector3(painting.global_position.x, player.global_position.y + EYE_HEIGHT - 0.3, painting.global_position.z))
	if not await _wait_for_look(token):
		return false
	var interaction = player.get("_interaction_component")
	if interaction.is_carrying:
		return false
	carry.pickup(interaction)
	_carrying = carry
	# The carry gives up if the painting can't follow within its 0.5 s settle window
	if not await _wait(token, 0.8):
		return false
	if not carry.is_carried:
		_carrying = null
		_pickup_tries[painting] = _pickup_tries.get(painting, 0) + 1
		return false  # it snagged on something and slipped out of the bot's hands
	var arrived := await _go_to(token, dump.stand)
	if not still_running(token):
		return false
	if not carry.is_carried:
		_carrying = null
		_pickup_tries[painting] = _pickup_tries.get(painting, 0) + 1
		return false
	if not arrived:
		interaction.drop_carried_object()  # couldn't get there: set it down here
		_carrying = null
		return false
	player.autoplay_look_at(dump.target)
	if not await _wait_for_look(token):
		return false
	interaction.throw_carried_object(TOSS_POWER)
	_carrying = null
	return await _wait(token, 1.0)


func _dump_corner(plane: MeshInstance3D) -> Variant:
	"""One corner of the studio per scene where cleared paintings get tossed:
	reachable on foot, a few metres from the canvas, away from doors, with
	walls on two perpendicular sides and open floor on the others (so it's a
	corner, not a corridor or doorway). Searched on a grid rather than at
	random so it's the same corner every time, and cached so they all land on
	one pile."""
	var scene := get_tree().current_scene
	if _dump.get("scene") == scene:
		return _dump
	var doors := scene.find_children("*", "DoorInteraction", true, false)
	var origin := _stand_point_for(plane)
	var best := {}
	var best_score := INF
	for x in range(-CORNER_SEARCH, CORNER_SEARCH + 1):
		for z in range(-CORNER_SEARCH, CORNER_SEARCH + 1):
			var spot: Vector3 = nav.closest_point(origin + Vector3(x, 0.0, z))
			if absf(spot.y - origin.y) > 0.5:
				continue  # another floor
			if _flat_distance(spot, plane.global_position) < CORNER_MIN_FROM_CANVAS:
				continue
			if doors.any(func(d): return _flat_distance(spot, d.global_position) < CORNER_MIN_FROM_DOOR):
				continue
			var corner = _corner_at(spot)
			if not corner:
				continue
			# Tightest corner wins; nearer the canvas breaks ties (shorter trips)
			var score: float = corner.score + 0.05 * _flat_distance(spot, plane.global_position)
			if score < best_score and nav.can_reach(origin, corner.stand):
				best_score = score
				best = corner
	if best.is_empty():
		return null
	best.scene = scene
	_dump = best
	return _dump


func _corner_at(spot: Vector3) -> Variant:
	"""If walls close in `spot` on two perpendicular sides and the other two
	are open, return where to stand and where to toss."""
	var eye := spot + Vector3.UP * 1.0
	var hits: Array[float] = []
	for i in 8:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, i * PI / 4.0)
		hits.append(_wall_distance(eye, dir))
	for i in range(0, 8, 2):
		var a := i
		var b := (i + 2) % 8
		if hits[a] < CORNER_PROBE and hits[b] < CORNER_PROBE \
				and hits[(a + 4) % 8] >= CORNER_PROBE and hits[(b + 4) % 8] >= CORNER_PROBE \
				and hits[(a + 1) % 8] < CORNER_PROBE * 1.5:
			var dir_a := Vector3.FORWARD.rotated(Vector3.UP, a * PI / 4.0)
			var dir_b := Vector3.FORWARD.rotated(Vector3.UP, b * PI / 4.0)
			var apex := spot + dir_a * hits[a] + dir_b * hits[b]
			var out := -(dir_a + dir_b).normalized()
			var stand: Vector3 = nav.closest_point(apex + out * TOSS_FROM)
			var target := apex + Vector3.UP * TOSS_HEIGHT
			return {"stand": stand, "target": target, "score": hits[a] + hits[b]}
	return null


func _wall_distance(from: Vector3, dir: Vector3) -> float:
	"""Distance to the nearest wall along `dir`, looking past props."""
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * CORNER_PROBE * 1.5)
	query.exclude = [player.get_rid()]
	var space := player.get_world_3d().direct_space_state
	for i in 4:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return INF
		if not hit.collider is PhysicsBody3D or hit.collider is StaticBody3D:
			return from.distance_to(hit.position)
		var skip := query.exclude
		skip.append(hit.rid)
		query.exclude = skip
	return INF


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
	"""A spot on the open side of the canvas: the side the player can walk to.
	There can be walkable floor behind the wall too (another room), so when
	both sides are reachable or neither is, fall back to the side whose ray
	doesn't hit the wall right away."""
	var normal := plane.global_basis.y.normalized()
	var front := normal
	if _blocked_within(plane.global_position, normal, STAND_DISTANCE):
		front = -normal
	var preferred := _floor_in_front_of(plane, front)
	if nav.can_reach(player.global_position, preferred):
		return preferred
	var other := _floor_in_front_of(plane, -front)
	return other if nav.can_reach(player.global_position, other) else preferred


func _floor_in_front_of(plane: MeshInstance3D, dir: Vector3) -> Vector3:
	# Snap to the walkable floor in front of the canvas
	return nav.closest_point(plane.global_position + dir * STAND_DISTANCE + Vector3.DOWN * 1.5)


func _canvas_visible_from(stand: Vector3, plane: MeshInstance3D) -> bool:
	"""Detached paintings land right in front of the fresh canvas, and the bot
	never carries them away. Don't go and paint stickers onto their backs."""
	var eye := stand + Vector3.UP * EYE_HEIGHT
	var beyond := plane.global_position + (plane.global_position - eye).normalized() * 0.3
	var query := PhysicsRayQueryParameters3D.create(eye, beyond)
	query.exclude = [player.get_rid()]
	return PaintingModeManager._is_canvas_plane(player.get_world_3d().direct_space_state.intersect_ray(query))


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
		# Bumped into something that's moved since the bake: rebake so the new path goes around it
		await nav.ensure_baked(get_tree().current_scene, true)
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
		if not still_running(token):
			break
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
