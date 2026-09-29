extends StaticBody3D
class_name DJBooth
## Purchasable DJ (shop item "dj"): a human behind a DJ booth in the gallery. Talking to them
## starts / ends the gallery dance party (DanceParty.gd).
##
## The DJ wears a random NPC skin from ShopManager.VISITOR_ROSTER, re-rolled every time the game
## boots. They loop `booth_animation`, or just stand in "idle" if the rig doesn't have it.

@export var booth_animation: String = "bartending"
@export var idle_animation: String = "idle"
@export var dj_rig_path: NodePath = ^"DJ/humanrig"
@export var start_text: String = "Start the Party"
@export var stop_text: String = "End the Party"

## Read by PlayerInteractionComponent for the prompt.
var interaction_text: String = "Start the Party"

var _party: DanceParty


func _ready() -> void:
	add_to_group("interactable")
	interaction_text = start_text

	var rig := get_node_or_null(dj_rig_path)
	if rig:
		_apply_random_skin(rig)
		_start_booth_animation(rig)
	else:
		push_warning("DJBooth: no DJ rig at %s" % dj_rig_path)

	# The party node may be further down the tree than us; look it up once everything's in.
	_connect_party.call_deferred()


func interact(_player: Node) -> void:
	if not _party:
		_connect_party()
	if _party:
		_party.toggle()
	else:
		push_warning("DJBooth: no DanceParty node in the scene (group 'dance_party')")


func _connect_party() -> void:
	if _party:
		return
	_party = DanceParty.find_in(get_tree())
	if _party:
		_party.party_started.connect(_refresh_text)
		_party.party_ended.connect(_refresh_text)
		_refresh_text()


func _refresh_text() -> void:
	interaction_text = stop_text if _party and _party.is_active else start_text


func _start_booth_animation(rig: Node) -> void:
	var anim_player := _find_animation_player(rig)
	if not anim_player:
		return
	var anim := booth_animation if anim_player.has_animation(booth_animation) else idle_animation
	if not anim_player.has_animation(anim):
		return
	anim_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	anim_player.play(anim)


func _apply_random_skin(rig: Node) -> void:
	var skins: Array[String] = []
	for entry in ShopManager.VISITOR_ROSTER:
		var path: String = entry.get("skin_path", "")
		if path != "":
			skins.append(path)
	if skins.is_empty():
		return
	var mat := load(skins.pick_random()) as StandardMaterial3D
	if mat:
		_apply_material_to_tree(rig, mat)


func _apply_material_to_tree(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for i in mesh_inst.get_surface_override_material_count():
			mesh_inst.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_material_to_tree(child, mat)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
