extends CharacterBody3D

## Gallery Visitor NPC — walks between paintings and other gallery attractions.
## Add any node to the "gallery_attraction" group to make it a visitable target.

enum State { IDLE, CHOOSING, WALKING, VIEWING }

@export var skin_material: StandardMaterial3D
@export var visitor_display_name: String = ""

@export var walk_speed: float = 2.0
@export var rotation_speed: float = 5.0
@export var view_time_min: float = 4.0
@export var view_time_max: float = 8.0
@export var stop_distance: float = 2.0
@export var think_interval_min: float = 2.0
@export var think_interval_max: float = 5.0

const GRAVITY := 9.8

const DIALOGUE_API_URL = "https://studio-sim-gallery.vercel.app/api/visitor-dialogue"
const ATTRACTION_API_URL = "https://studio-sim-gallery.vercel.app/api/attraction-dialogue"
const API_KEY = "jupTtic3qGOULETb2w7E"
const DIALOGUE_COOLDOWN = 60.0

const FALLBACK_LINES = [
	"Just checking the place out.",
	"Nice space.",
	"Interesting.",
	"Not sure what to make of it.",
	"Love what they've done with the lighting.",
	"I need to come back when it's less crowded.",
]

const PERSONALITIES = ["casual", "pretentious", "confused", "enthusiastic"]
# Streetwise is skin-assigned only — excluded from the random pool
const PERSONALITIES_RANDOM = ["casual", "pretentious", "confused", "enthusiastic"]

const SKIN_PERSONALITIES: Dictionary = {
	"blackguy_redshirt": "streetwise",
	"tanguy_greenshirt": "spiritual",
	"blondeguy_whiteshirt": "fabulous",
	"garyskin": "casual",
	"humanskin": "enthusiastic",
	"skeletonskin": "confused",
}

const STREETWISE_FALLBACK_LINES = [
	"This hits different.",
	"Whoever made this got something to say.",
	"Real talk, I respect the vision.",
	"I don't know about all the art world stuff, but this one got me.",
	"Straight up, this is hard.",
	"Nah this is lowkey underrated.",
]

const SPIRITUAL_FALLBACK_LINES = [
	"There's a real energy here.",
	"I keep coming back to this one.",
	"I want to carry something from this into my own work.",
	"It's like the artist was working something out.",
	"You can feel the intention behind it.",
	"This is the kind of thing that stays with you.",
]

const FABULOUS_FALLBACK_LINES = [
	"This is absolutely fabulous.",
	"Fabulous. Just... fabulous.",
	"I don't know who made this, but they have fabulous taste.",
	"The color palette? Fabulous. The composition? Fabulous. Everything? Fabulous.",
	"I came in for five minutes and now I never want to leave. Fabulous.",
	"Honestly, this whole gallery is giving me fabulous energy.",
]

## Exposed so PlayerInteractionComponent can show a prompt label.
var interaction_text: String = "Talk"

var _state: State = State.IDLE
var _nav_agent: NavigationAgent3D
var _anim_player: AnimationPlayer
var _last_attraction: Node3D = null
var _view_timer: float = 0.0
var _view_duration: float = 0.0
var _is_thinking: bool = false
var _think_cooldown: float = 0.0

var _personality: String = "casual"
var _http_request: HTTPRequest
var _cached_dialogue: String = ""
var _dialogue_cooldown: float = 0.0
var _is_interacting: bool = false
var _facing_player: bool = false
var _face_player_ref: Node3D = null


func _ready() -> void:
	add_to_group("gallery_visitors")
	# Only interactable while VIEWING — added/removed as state changes
	# Player raycast hits layers 1–4 (mask 15). Visitor is on layer 6 (32) by default,
	# so we also join layer 4 (8) to be detectable.
	collision_layer |= 8

	# Skin-based personality (deterministic) or hash fallback
	if skin_material:
		var key := skin_material.resource_path.get_file().get_basename()
		_personality = SKIN_PERSONALITIES.get(key, "casual")
		_apply_skin()
	else:
		var seed_val := hash(name + str(get_instance_id()))
		_personality = PERSONALITIES_RANDOM[seed_val % PERSONALITIES_RANDOM.size()]

	_nav_agent = $NavigationAgent3D
	_nav_agent.path_desired_distance = 2.0
	_nav_agent.target_desired_distance = stop_distance
	_nav_agent.navigation_finished.connect(_on_navigation_finished)

	_anim_player = _find_animation_player($humanrig)
	if not _anim_player:
		push_warning("GalleryVisitor: AnimationPlayer not found inside humanrig!")
	else:
		_anim_player.animation_finished.connect(_on_animation_finished)

	_http_request = HTTPRequest.new()
	_http_request.name = "DialogueRequest"
	_http_request.timeout = 15.0
	add_child(_http_request)
	_http_request.request_completed.connect(_on_dialogue_response)

	_play_animation("idle")
	get_tree().create_timer(1.0).timeout.connect(_choose_next_attraction, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _dialogue_cooldown > 0.0:
		_dialogue_cooldown -= delta

	match _state:
		State.WALKING:
			_update_walking(delta)
		State.VIEWING:
			_update_viewing(delta)
		_:
			move_and_slide()


func interact(_player: Node) -> void:
	var box: VisitorDialogueBox = _get_dialogue_box()

	# If dialogue is already open, advance to the next chunk
	if box and box.is_open():
		box.advance()
		return

	# Ignore spam while a request is in flight
	if _is_interacting:
		return
	_is_interacting = true

	# Store player reference so we can track them continuously while talking
	if is_instance_valid(_player) and _player is Node3D:
		_face_player_ref = _player as Node3D
	_facing_player = true

	# Connect dialogue_finished once so we know when to turn back
	if box and not box.dialogue_finished.is_connected(_on_dialogue_finished):
		box.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)

	# Fresh cached line still within cooldown — show instantly, no API call
	if _cached_dialogue != "" and _dialogue_cooldown > 0.0:
		_start_dialogue(_cached_dialogue)
		_is_interacting = false
		return

	# Not currently viewing a painting — fallback immediately
	if _state != State.VIEWING or not is_instance_valid(_last_attraction):
		_start_dialogue(_pick_fallback())
		_is_interacting = false
		return

	# Show loading indicator and fetch dialogue
	_start_dialogue("...")
	_fetch_dialogue()


func _fetch_dialogue() -> void:
	var painting_name := ""
	var artist_statement := ""
	var artist_name := ""

	if has_node("/root/WorldStateManager"):
		for data in WorldStateManager.get_all_paintings():
			if data.get("node") == _last_attraction:
				painting_name = data.get("name", "")
				artist_statement = data.get("artist_statement", "")
				break

	if has_node("/root/SteamManager"):
		artist_name = SteamManager.persona_name

	if painting_name == "":
		# Not a painting — check if it's a shop attraction with a catalog entry
		if is_instance_valid(_last_attraction) and _last_attraction.is_in_group("shop_prop"):
			var item_id: String = _last_attraction.get_meta("shop_item_id", "")
			if item_id != "":
				_fetch_attraction_dialogue(item_id)
				return
		_start_dialogue(_pick_fallback())
		_is_interacting = false
		return

	var locale := "en"
	if has_node("/root/LocaleManager"):
		locale = LocaleManager.current_locale

	var body := JSON.stringify({
		"paintingName": painting_name,
		"artistStatement": artist_statement,
		"artistName": artist_name,
		"visitorPersonality": _personality,
		"locale": locale,
	})
	var headers := [
		"Content-Type: application/json",
		"X-API-Key: " + API_KEY,
	]
	var error := _http_request.request(DIALOGUE_API_URL, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_start_dialogue(_pick_fallback())
		_is_interacting = false
		push_error("GalleryVisitor: Failed to start dialogue request: " + str(error))


func _fetch_attraction_dialogue(item_id: String) -> void:
	var item := {}
	if has_node("/root/ShopManager"):
		for entry in ShopManager.get_catalog():
			if entry["id"] == item_id:
				item = entry
				break

	if item.is_empty():
		_start_dialogue(_pick_fallback())
		_is_interacting = false
		return

	var locale := "en"
	if has_node("/root/LocaleManager"):
		locale = LocaleManager.current_locale

	var body_str := JSON.stringify({
		"attractionTitle": item.get("title", item.get("display_name", "")),
		"attractionDescription": item.get("description", ""),
		"visitorPersonality": _personality,
		"locale": locale,
	})
	var headers := [
		"Content-Type: application/json",
		"X-API-Key: " + API_KEY,
	]
	var error := _http_request.request(ATTRACTION_API_URL, headers, HTTPClient.METHOD_POST, body_str)
	if error != OK:
		_start_dialogue(_pick_fallback())
		_is_interacting = false
		push_error("GalleryVisitor: Failed to start attraction dialogue request: " + str(error))


func _on_dialogue_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_interacting = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_start_dialogue(_pick_fallback())
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		var line: String = json.data.get("dialogue", "")
		if line != "":
			_cached_dialogue = line
			_dialogue_cooldown = DIALOGUE_COOLDOWN
			_start_dialogue(line)
			return

	_start_dialogue(_pick_fallback())


func _pick_fallback() -> String:
	match _personality:
		"streetwise":
			return STREETWISE_FALLBACK_LINES.pick_random()
		"spiritual":
			return SPIRITUAL_FALLBACK_LINES.pick_random()
		"fabulous":
			return FABULOUS_FALLBACK_LINES.pick_random()
	return FALLBACK_LINES.pick_random()


func _apply_skin() -> void:
	if not skin_material:
		return
	_apply_material_to_tree($humanrig, skin_material)


func _apply_material_to_tree(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for i in mesh_inst.get_surface_override_material_count():
			mesh_inst.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_material_to_tree(child, mat)


func _start_dialogue(text: String) -> void:
	var box: VisitorDialogueBox = _get_dialogue_box()
	if not box:
		return
	var label := visitor_display_name if visitor_display_name != "" else _personality
	box.show_dialogue(_split_into_chunks(text), _personality, label)


func _on_dialogue_finished() -> void:
	# Turn back to face the painting after a short pause
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		_facing_player = false
		_face_player_ref = null
	, CONNECT_ONE_SHOT)


func _split_into_chunks(text: String) -> Array[String]:
	# Split on sentence-ending punctuation followed by a space or end of string
	var chunks: Array[String] = []
	var remaining := text.strip_edges()
	var delimiters := [". ", "! ", "? "]

	while remaining.length() > 0:
		var earliest_pos := -1
		var earliest_len := 0
		for d in delimiters:
			var pos := remaining.find(d)
			if pos != -1 and (earliest_pos == -1 or pos < earliest_pos):
				earliest_pos = pos
				earliest_len = d.length()

		if earliest_pos == -1:
			# No more sentence boundaries — remainder is the last chunk
			chunks.append(remaining)
			break
		else:
			# Include the punctuation mark but not the trailing space
			chunks.append(remaining.substr(0, earliest_pos + 1))
			remaining = remaining.substr(earliest_pos + earliest_len)

	if chunks.is_empty():
		chunks.append(text)
	return chunks


func _get_dialogue_box() -> VisitorDialogueBox:
	var nodes := get_tree().get_nodes_in_group("visitor_dialogue_box")
	if nodes.size() > 0:
		return nodes[0] as VisitorDialogueBox
	# Auto-instantiate if not in scene yet (no manual scene setup required)
	var scene: PackedScene = load("res://scenes/UI/VisitorDialogueBox.tscn")
	if not scene:
		push_error("GalleryVisitor: Could not load VisitorDialogueBox.tscn")
		return null
	var box := scene.instantiate() as VisitorDialogueBox
	get_tree().root.add_child(box)
	return box


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

	if _facing_player and is_instance_valid(_face_player_ref):
		var to_player := _face_player_ref.global_position - global_position
		to_player.y = 0.0
		# Close dialogue if player walks out of interaction range
		if to_player.length() > 6.0:
			var box: VisitorDialogueBox = _get_dialogue_box()
			if box and box.is_open():
				box.hide_dialogue()
			_facing_player = false
			_face_player_ref = null
		elif to_player.length() > 0.1:
			transform.basis = transform.basis.slerp(
				Basis.looking_at(to_player.normalized()), rotation_speed * delta)
	elif is_instance_valid(_last_attraction):
		var to_attraction: Vector3 = _last_attraction.global_position - global_position
		to_attraction.y = 0.0
		if to_attraction.length() > 0.1:
			var target_basis := Basis.looking_at(to_attraction.normalized())
			transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)

	# Pause view timer while facing the player (covers dialogue + the 2s cooldown after)
	if _facing_player:
		return

	if not _is_thinking:
		_think_cooldown -= delta
		if _think_cooldown <= 0.0:
			_is_thinking = true
			_play_animation(["think", "think2"].pick_random())
		else:
			_view_timer += delta
			if _view_timer >= _view_duration:
				_choose_next_attraction()


func _enter_viewing() -> void:
	_state = State.VIEWING
	_view_timer = 0.0
	_view_duration = randf_range(view_time_min, view_time_max)
	_is_thinking = false
	_think_cooldown = randf_range(think_interval_min, think_interval_max)
	_cached_dialogue = ""  # New painting — clear cached line
	add_to_group("interactable")
	_play_animation("idle")


func _choose_next_attraction() -> void:
	remove_from_group("interactable")
	_facing_player = false
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
	# Offset target slightly so visitors don't stack on the same navmesh point
	var map := _nav_agent.get_navigation_map()
	var raw_target := _last_attraction.global_position
	var angle := randf() * TAU
	var offset_radius := randf_range(0.4, 1.0)
	raw_target.x += cos(angle) * offset_radius
	raw_target.z += sin(angle) * offset_radius
	var nav_target := NavigationServer3D.map_get_closest_point(map, raw_target)
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


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name in ["think", "think2"]:
		_is_thinking = false
		_play_animation("idle")
		_think_cooldown = randf_range(think_interval_min, think_interval_max)


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
