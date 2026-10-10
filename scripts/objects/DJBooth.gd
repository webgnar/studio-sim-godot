extends StaticBody3D
class_name DJBooth
## Purchasable DJ (shop item "dj"): a human behind a DJ booth in the gallery. Talking to them
## starts / ends the gallery dance party (DanceParty.gd).
##
## The DJ wears a random NPC skin from ShopManager.VISITOR_ROSTER, re-rolled every time the game
## boots. They loop `booth_animation`, or just stand in "idle" if the rig doesn't have it.
## While the dance party is on they loop `party_animation` instead.

@export var booth_animation: String = "bartending"
@export var idle_animation: String = "idle"
@export var party_animation: String = "Dance_Rapping"
@export var dj_rig_path: NodePath = ^"DJ/humanrig"
@export var start_text: String = "Start the Party"
@export var stop_text: String = "End the Party"

## Read by PlayerInteractionComponent for the prompt.
var interaction_text: String = "Start the Party"

var _party: DanceParty
var _anim_player: AnimationPlayer


func _ready() -> void:
	add_to_group("interactable")
	interaction_text = start_text

	var rig := get_node_or_null(dj_rig_path)
	if rig:
		_apply_random_skin(rig)
		# The shared humanrig carries the player's skateboard mesh; the DJ doesn't skate.
		var board := rig.find_child("skateboard", true, false) as Node3D
		if board:
			board.visible = false
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
		_party.party_started.connect(_on_party_changed)
		_party.party_ended.connect(_on_party_changed)
		_on_party_changed()


func _on_party_changed() -> void:
	var partying := _party != null and _party.is_active
	interaction_text = stop_text if partying else start_text
	_play_loop([party_animation, booth_animation, idle_animation] if partying \
			else [booth_animation, idle_animation])


func _start_booth_animation(rig: Node) -> void:
	_anim_player = _find_animation_player(rig)
	_play_loop([booth_animation, idle_animation])


## Loop the first animation in `names` the rig has.
func _play_loop(names: Array) -> void:
	if not _anim_player:
		return
	for anim: String in names:
		if _anim_player.has_animation(anim):
			if _anim_player.current_animation != anim:
				_anim_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
				_anim_player.play(anim, 0.3)
			return


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
