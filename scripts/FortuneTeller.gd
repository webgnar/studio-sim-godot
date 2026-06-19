class_name FortuneTeller extends CharacterBody3D

const COOLDOWN = 120.0

@export var skin_material: StandardMaterial3D

const NO_DATA_LINE = "The stars cannot find you without knowing when you were born. Visit the Options menu and enter your date of birth."

var _anim_player: AnimationPlayer
var _cached_reading: String = ""
var _cooldown_timer: float = 0.0
var _is_busy: bool = false

func _ready() -> void:
	add_to_group("interactable")

	_anim_player = _find_animation_player($humanrig)
	if skin_material:
		_apply_material_to_tree($humanrig, skin_material)
	_sit_then_meditate()

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func interact(player: Node) -> void:
	var box: VisitorDialogueBox = _get_dialogue_box()

	if box and box.is_open():
		box.advance()
		return

	if _is_busy:
		return
	_is_busy = true

	if box and not box.dialogue_finished.is_connected(_on_dialogue_finished):
		box.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)

	var settings := _load_settings()
	var bd: String = settings.get("birth_date", "")

	if bd.strip_edges() == "":
		_start_dialogue(NO_DATA_LINE)
		_is_busy = false
		return

	if _cached_reading != "" and _cooldown_timer > 0.0:
		_start_dialogue(_cached_reading)
		_is_busy = false
		return

	var reading := FortuneTellerGenerator.generate(bd)
	_cached_reading = reading
	_cooldown_timer = COOLDOWN
	_start_dialogue(reading)
	_is_busy = false

func _start_dialogue(text: String) -> void:
	var box: VisitorDialogueBox = _get_dialogue_box()
	if not box:
		return
	box.show_dialogue(_split_into_chunks(text), "spiritual", "The Fortune Teller")

func _on_dialogue_finished() -> void:
	pass

func _get_dialogue_box() -> VisitorDialogueBox:
	var nodes := get_tree().get_nodes_in_group("visitor_dialogue_box")
	if nodes.size() > 0:
		return nodes[0] as VisitorDialogueBox
	var scene: PackedScene = load("res://scenes/UI/VisitorDialogueBox.tscn")
	if not scene:
		push_error("FortuneTeller: Could not load VisitorDialogueBox.tscn")
		return null
	var box := scene.instantiate() as VisitorDialogueBox
	get_tree().root.add_child(box)
	return box

func _split_into_chunks(text: String) -> Array[String]:
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
			chunks.append(remaining)
			break
		else:
			chunks.append(remaining.substr(0, earliest_pos + 1))
			remaining = remaining.substr(earliest_pos + earliest_len)

	if chunks.is_empty():
		chunks.append(text)
	return chunks

func _sit_then_meditate() -> void:
	if not _anim_player:
		return
	_anim_player.play("sit")
	await _anim_player.animation_finished
	if _anim_player.has_animation("meditate"):
		_anim_player.get_animation("meditate").loop_mode = Animation.LOOP_LINEAR
	_anim_player.play("meditate")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null

func _apply_material_to_tree(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for i in mesh_inst.get_surface_override_material_count():
			mesh_inst.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_material_to_tree(child, mat)

func _load_settings() -> Dictionary:
	if not FileAccess.file_exists("user://settings.json"):
		return {}
	var file := FileAccess.open("user://settings.json", FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		file.close()
		return {}
	file.close()
	return json.data
