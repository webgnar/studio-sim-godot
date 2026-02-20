extends InteractionComponent
class_name MirrorInteraction
## Mirror interaction component - cycles player skin between available skins
## Extends InteractionComponent to inherit common interaction functionality

signal skin_changed(skin_index: int)

@export_group("Mirror Settings")
@export var skin_materials: Array[Material] = []  # Ordered list of skin materials to cycle through
@export var toggle_sound: AudioStream

var _current_skin_index: int = 0
var _player_node: CharacterBody3D = null
var _player_meshes: Array[MeshInstance3D] = []
var _all_skin_materials: Array[Material] = []

func _on_ready() -> void:
	# interaction_text set via inspector
	_ensure_audio_player()
	_find_player()
	_find_meshes()
	_build_materials_list()

	if SkinLibrary.has_signal("library_changed"):
		SkinLibrary.library_changed.connect(_build_materials_list)

	if _all_skin_materials.is_empty():
		push_warning("No skin materials set for mirror!")

func _build_materials_list() -> void:
	_all_skin_materials = skin_materials.duplicate()
	_all_skin_materials.append_array(SkinLibrary.custom_skin_materials)
	# Clamp index in case the list shrank
	_current_skin_index = clampi(_current_skin_index, 0, max(0, _all_skin_materials.size() - 1))

func _ensure_audio_player() -> void:
	if toggle_sound and not _audio_player:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "MirrorAudio"
		_audio_player.max_distance = 10.0
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(_audio_player)

func _find_player() -> void:
	# Find the player node from the "player" group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_node = players[0]
	else:
		push_warning("⚠️ No player found for MirrorInteraction")

func _find_meshes() -> void:
	if not _player_node:
		return
	
	# Find the human model in the player
	var human_node = _player_node.get_node_or_null("human")
	
	if not human_node:
		push_error("❌ Cannot find 'human' node in player!")
		return
	
	# Find all MeshInstance3D nodes in the human model
	_player_meshes = _find_all_mesh_instances(human_node)

func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		meshes.append(node)
	
	for child in node.get_children():
		meshes.append_array(_find_all_mesh_instances(child))
	
	return meshes

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	_cycle_skin()

func _cycle_skin() -> void:
	if not _player_node:
		push_error("Cannot cycle skin - player not found!")
		return

	if _player_meshes.is_empty():
		push_error("Cannot cycle skin - no meshes found!")
		return

	if _all_skin_materials.is_empty():
		push_error("Cannot cycle skin - no materials configured!")
		return

	# Advance to next skin, wrapping around (built-ins first, then custom)
	_current_skin_index = (_current_skin_index + 1) % _all_skin_materials.size()

	var target_material = _all_skin_materials[_current_skin_index]

	# Apply the material to all player meshes
	for mesh in _player_meshes:
		_apply_material_to_mesh(mesh, target_material)

	# Play sound
	if toggle_sound:
		_play_sound(toggle_sound)

	skin_changed.emit(_current_skin_index)

func _apply_material_to_mesh(mesh: MeshInstance3D, material: Material) -> void:
	if not mesh or not material:
		push_warning("⚠️ Cannot apply material - mesh or material is null")
		return
	
	if not mesh.mesh:
		push_warning("⚠️ Mesh instance has no mesh")
		return
	
	var surface_count = mesh.mesh.get_surface_count()
	
	for i in range(surface_count):
		mesh.set_surface_override_material(i, material)

# Public methods
func get_current_skin_index() -> int:
	return _current_skin_index

func set_skin(index: int) -> void:
	if index < 0 or index >= _all_skin_materials.size():
		push_warning("Skin index %d out of range" % index)
		return
	_current_skin_index = index
	var target_material = _all_skin_materials[_current_skin_index]
	for mesh in _player_meshes:
		_apply_material_to_mesh(mesh, target_material)
	skin_changed.emit(_current_skin_index)
