extends StaticBody3D

var interaction_text: String = "Insert $1"
var _coin_sound: AudioStreamPlayer3D
var _coin_mesh_shape: Mesh
var _coin_mat: StandardMaterial3D
var _slot_mesh: MeshInstance3D
var _slot_highlight_mat: StandardMaterial3D
var _slot_original_mat: Material

func _ready():
	_coin_sound = AudioStreamPlayer3D.new()
	_coin_sound.stream = preload("res://scenes/rubens_coin_pusher/coins_single_02.wav")
	_coin_sound.volume_db = -5.0
	_coin_sound.max_distance = 8.0
	_coin_sound.bus = "SFX"
	add_child(_coin_sound)

	# Mesh/material for the insert-animation coin. These are shared Resources
	# (safe/cheap to reference from multiple MeshInstance3D nodes at once) —
	# unlike the MeshInstance3D node itself, which _animate_coin_insert() now
	# creates fresh per insertion, so a coin already mid-drop never gets its
	# position reset or freed early by a second coin being inserted right after.
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = 0.01
	_coin_mesh_shape = mesh
	_coin_mat = StandardMaterial3D.new()
	_coin_mat.albedo_color = Color(0.9, 0.75, 0.2)
	_coin_mat.metallic = 0.8
	_coin_mat.roughness = 0.3

	# Mouse-over highlight: this node is in the "no_outline" group (the generic
	# OutlineManager silhouette system doesn't have anything sensible to outline
	# here — this node's own visible mesh, "SlotMesh", is deliberately hidden by
	# default), so it needs its own hover reaction instead. Reuse SlotMesh's real
	# authored geometry rather than guessing at new highlight shape/placement:
	# reveal it with a glowing override material on hover, hide it again otherwise.
	_slot_mesh = get_node_or_null("SlotMesh")
	if _slot_mesh:
		_slot_original_mat = _slot_mesh.material_override
	_slot_highlight_mat = StandardMaterial3D.new()
	_slot_highlight_mat.albedo_color = Color(1.0, 0.85, 0.3)
	_slot_highlight_mat.emission_enabled = true
	_slot_highlight_mat.emission = Color(1.0, 0.7, 0.15)
	_slot_highlight_mat.emission_energy_multiplier = 2.0
	_connect_hover_signals()


func _connect_hover_signals() -> void:
	# Wait a frame — the player (and its PlayerInteractionComponent) may not
	# exist yet when this node's own _ready() runs, same as HUD.gd does.
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	for child in player.get_children():
		if child is PlayerInteractionComponent:
			child.interactive_object_detected.connect(_on_interactive_object_detected)
			child.nothing_detected.connect(_set_highlight.bind(false))
			return


func _on_interactive_object_detected(interactable: Node3D) -> void:
	_set_highlight(interactable == self)


func _set_highlight(on: bool) -> void:
	if not _slot_mesh:
		return
	_slot_mesh.visible = on
	_slot_mesh.material_override = _slot_highlight_mat if on else _slot_original_mat

func interact(_interactor) -> void:
	if GameManager.try_insert_dollar():
		_coin_sound.pitch_scale = randf_range(0.9, 1.1)
		_coin_sound.play()
		_animate_coin_insert()

func _animate_coin_insert() -> void:
	var coin_mesh := MeshInstance3D.new()
	coin_mesh.mesh = _coin_mesh_shape
	coin_mesh.material_override = _coin_mat
	coin_mesh.position = Vector3(0, 0.35, 0.03)  # raised drop-in start height
	coin_mesh.rotation = Vector3(PI / 2, 0, 0)
	add_child(coin_mesh)

	var tween = create_tween()
	tween.tween_property(coin_mesh, "position", Vector3(0, 0, 0), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(coin_mesh.queue_free)
