extends InteractionComponent
class_name MirrorInteraction
## Mirror interaction component - cycles player skin between human and skeleton
## Extends InteractionComponent to inherit common interaction functionality

signal skin_toggled(is_skeleton: bool)

@export_group("Mirror Settings")
@export var human_skin_material: Material  # The human skin material (humanskin.tres)
@export var skeleton_skin_material: Material  # The skeleton skin material (skeletonskin.tres)
@export var toggle_sound: AudioStream

var _is_skeleton: bool = false
var _player_node: CharacterBody3D = null
var _player_meshes: Array[MeshInstance3D] = []

func _on_ready() -> void:
	interaction_text = "Change Skin"
	_ensure_audio_player()
	_find_player()
	_find_meshes()
	print("✅ MirrorInteraction ready: " + parent_object.name)
	
	if not human_skin_material:
		push_warning("⚠️ No human skin material set for mirror!")
	if not skeleton_skin_material:
		push_warning("⚠️ No skeleton skin material set for mirror!")

func _ensure_audio_player() -> void:
	if toggle_sound and not _audio_player:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "MirrorAudio"
		_audio_player.max_distance = 10.0
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(_audio_player)
		print("Created audio player for mirror sounds")

func _find_player() -> void:
	# Find the player node from the "player" group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_node = players[0]
		print("🪞 Mirror found player: " + str(_player_node.get_path()))
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
	
	print("🔍 Found " + str(_player_meshes.size()) + " mesh instances in player model:")
	for mesh in _player_meshes:
		if mesh.mesh:
			var surface_count = mesh.mesh.get_surface_count()
			print("  - " + mesh.name + " (" + str(surface_count) + " surfaces)")

func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		meshes.append(node)
	
	for child in node.get_children():
		meshes.append_array(_find_all_mesh_instances(child))
	
	return meshes

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	_toggle_skin()

func _toggle_skin() -> void:
	if not _player_node:
		push_error("❌ Cannot toggle skin - player not found!")
		return
	
	if _player_meshes.is_empty():
		push_error("❌ Cannot toggle skin - no meshes found!")
		return
	
	# Toggle between human and skeleton
	_is_skeleton = not _is_skeleton
	
	var target_material = skeleton_skin_material if _is_skeleton else human_skin_material
	var skin_name = "skeleton" if _is_skeleton else "human"
	
	print("🎨 Changing all meshes to " + skin_name + " skin")
	
	# Apply the material to all player meshes
	for mesh in _player_meshes:
		_apply_material_to_mesh(mesh, target_material)
	
	# Play sound
	if toggle_sound:
		_play_sound(toggle_sound)
		print("🔊 Playing mirror toggle sound")
	
	skin_toggled.emit(_is_skeleton)

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
func is_skeleton_skin() -> bool:
	return _is_skeleton

func reset_to_human() -> void:
	if _is_skeleton:
		_toggle_skin()

func reset_to_skeleton() -> void:
	if not _is_skeleton:
		_toggle_skin()
