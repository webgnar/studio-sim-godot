extends CharacterBody3D

## Gallery Visitor NPC — walks between paintings and other gallery attractions.
## Add any node to the "gallery_attraction" group to make it a visitable target.

enum State { IDLE, CHOOSING, WALKING, VIEWING }

@export var walk_speed: float = 2.0
@export var rotation_speed: float = 5.0
@export var view_time_min: float = 4.0
@export var view_time_max: float = 8.0
@export var stop_distance: float = 2.0

const GRAVITY := 9.8

var _state: State = State.IDLE
var _nav_agent: NavigationAgent3D
var _anim_player: AnimationPlayer
var _last_attraction: Node3D = null
var _view_timer: float = 0.0
var _view_duration: float = 0.0


func _ready() -> void:
	_nav_agent = $NavigationAgent3D
	_nav_agent.path_desired_distance = 2.0
	_nav_agent.target_desired_distance = stop_distance
	_nav_agent.navigation_finished.connect(_on_navigation_finished)

	_anim_player = _find_animation_player($humanrig)
	if not _anim_player:
		push_warning("GalleryVisitor: AnimationPlayer not found inside humanrig!")

	_play_animation("idle")
	get_tree().create_timer(1.0).timeout.connect(_choose_next_attraction, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	match _state:
		State.WALKING:
			_update_walking(delta)
		State.VIEWING:
			_update_viewing(delta)
		_:
			move_and_slide()


func _on_navigation_finished() -> void:
	if _state == State.WALKING:
		_enter_viewing()


func _update_walking(delta: float) -> void:
	# Manual distance fallback in case the signal fires late or not at all
	if is_instance_valid(_last_attraction):
		var flat_dist := Vector2(global_position.x, global_position.z).distance_to(
			Vector2(_last_attraction.global_position.x, _last_attraction.global_position.z))
		if flat_dist <= stop_distance:
			_enter_viewing()
			return

	var next_pos: Vector3 = _nav_agent.get_next_path_position()
	var dir: Vector3 = (next_pos - global_position)
	dir.y = 0.0
	var dir_len := dir.length()

	if dir_len > 0.01:
		dir = dir / dir_len
		velocity.x = dir.x * walk_speed
		velocity.z = dir.z * walk_speed
		var target_basis := Basis.looking_at(dir)
		transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()


func _update_viewing(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()

	if is_instance_valid(_last_attraction):
		var to_attraction: Vector3 = _last_attraction.global_position - global_position
		to_attraction.y = 0.0
		if to_attraction.length() > 0.1:
			var target_basis := Basis.looking_at(to_attraction.normalized())
			transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)

	_view_timer += delta
	if _view_timer >= _view_duration:
		_choose_next_attraction()


func _enter_viewing() -> void:
	_state = State.VIEWING
	_view_timer = 0.0
	_view_duration = randf_range(view_time_min, view_time_max)
	_play_animation("idle")


func _choose_next_attraction() -> void:
	_state = State.CHOOSING
	var all_attractions := _get_attraction_nodes()

	var candidates: Array[Node3D] = all_attractions.filter(
		func(n: Node3D) -> bool: return n != _last_attraction
	)
	if candidates.is_empty():
		candidates = all_attractions

	if candidates.is_empty():
		_play_animation("idle")
		_state = State.IDLE
		get_tree().create_timer(3.0).timeout.connect(_choose_next_attraction, CONNECT_ONE_SHOT)
		return

	_last_attraction = candidates.pick_random()
	# Project target to the navmesh surface so we never send the agent inside an obstacle
	var map := _nav_agent.get_navigation_map()
	var nav_target := NavigationServer3D.map_get_closest_point(map, _last_attraction.global_position)
	_nav_agent.set_target_position(nav_target)
	_state = State.WALKING
	_play_animation("walk")


func _get_attraction_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []

	# Source 1: shipped paintings tracked by WorldStateManager
	if has_node("/root/WorldStateManager"):
		for data in WorldStateManager.get_all_paintings():
			if data["status"] == "SHIPPED" and is_instance_valid(data["node"]):
				result.append(data["node"] as Node3D)

	# Source 2: anything else explicitly tagged as a gallery attraction
	for node in get_tree().get_nodes_in_group("gallery_attraction"):
		if is_instance_valid(node) and node.is_visible_in_tree() and node not in result:
			result.append(node as Node3D)

	return result


func _play_animation(anim_name: String) -> void:
	if not _anim_player:
		return
	if not _anim_player.has_animation(anim_name):
		push_warning("GalleryVisitor: animation '%s' not found. Available: %s" % [
			anim_name, str(_anim_player.get_animation_list())])
		return
	if anim_name in ["idle", "walk"]:
		_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim_player.play(anim_name)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null
