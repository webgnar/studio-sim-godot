extends Node3D
class_name DanceParty
## Gallery dance party, switched on and off by the DJ booth (DJBooth.gd).
##
## Starting the party:
##   - reveals + starts the `Rig` child (mirror ball, disco lights, projectors, specks)
##   - switches off every Light3D under `house_lights_root` (the gallery's own lights), so the
##     party lighting pops (and stays under the per-object light limit), restoring them after
##   - plays `music` from the `Music` child
##   - tells every gallery visitor to start dancing where they stand (GalleryVisitor.start_dancing);
##     visitors bought mid-party join in on their own
## Party state isn't saved - it's always off after a reload.

signal party_started
signal party_ended

@export var music: AudioStream
@export var music_volume_db: float = -3.0
@export var music_player_path: NodePath = ^"Music"
@export var rig_path: NodePath = ^"Rig"
## Lights under this node are switched off while the party runs (the rig's own lights excepted).
@export var house_lights_root: NodePath = ^"../gallery"
## Dances visitors pick from at random (only names the visitor's rig actually has are used).
@export var dance_animations: PackedStringArray = [
	"Dance_Hip_Hop_Dancing", "Dance_Hip_Hop_Dancing_2", "Dance_Hip_Hop_Dancing_3",
	"Dance_Hip_Hop_Dancing_5", "Dance_Hip_Hop_Dancing_6", "Dance_Silly_Dancing",
	"Dance_Twist_Dance", "Dance_Snake_Hip_Hop_Dance", "Dance_Rumba_Dancing",
	"Dance_Salsa_Dancing", "Dance_Northern_Soul_Spin", "Dance_Dancing_Running_Man",
	"Dance_Bboy_Hip_Hop_Move", "Dance_Dancing_Twerk",
]

var is_active: bool = false

var _rig: Node3D
var _music_player: AudioStreamPlayer3D
var _switched_off: Array[Light3D] = []


func _ready() -> void:
	add_to_group("dance_party")
	_rig = get_node_or_null(rig_path) as Node3D
	_music_player = get_node_or_null(music_player_path) as AudioStreamPlayer3D
	if _music_player:
		_music_player.bus = &"Music"
		if music:
			_music_player.stream = _looping(music)
	_set_rig_running(false)


## First DanceParty in the tree (there's normally exactly one), or null.
static func find_in(tree: SceneTree) -> DanceParty:
	return tree.get_first_node_in_group("dance_party") as DanceParty


func toggle() -> void:
	if is_active:
		stop()
	else:
		start()


func start() -> void:
	if is_active:
		return
	is_active = true
	_set_rig_running(true)
	_set_house_lights(false)
	if _music_player and _music_player.stream:
		_music_player.volume_db = music_volume_db
		_music_player.play()
	for visitor in get_tree().get_nodes_in_group("gallery_visitors"):
		if visitor.has_method("start_dancing"):
			visitor.start_dancing()
	party_started.emit()


func stop() -> void:
	if not is_active:
		return
	is_active = false
	_set_rig_running(false)
	_set_house_lights(true)
	if _music_player:
		_music_player.stop()
	for visitor in get_tree().get_nodes_in_group("gallery_visitors"):
		if visitor.has_method("stop_dancing"):
			visitor.stop_dancing()
	party_ended.emit()


## A random dance from `dance_animations` that `anim_player` actually has ("" if none).
func pick_dance(anim_player: AnimationPlayer, exclude: String = "") -> String:
	var options: Array[String] = []
	for dance in dance_animations:
		if dance != exclude and anim_player.has_animation(dance):
			options.append(dance)
	if options.is_empty():
		return exclude if anim_player.has_animation(exclude) else ""
	return options.pick_random()


func _set_rig_running(on: bool) -> void:
	if not _rig:
		return
	_rig.visible = on
	_rig.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _set_house_lights(on: bool) -> void:
	if on:
		for light in _switched_off:
			if is_instance_valid(light):
				light.visible = true
		_switched_off.clear()
		return
	var root := get_node_or_null(house_lights_root)
	if not root:
		return
	for node in root.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.visible and not (_rig and _rig.is_ancestor_of(light)):
			light.visible = false
			_switched_off.append(light)


func _looping(stream: AudioStream) -> AudioStream:
	# Loop the track without touching the shared imported resource.
	var copy := stream.duplicate() as AudioStream
	if "loop" in copy:
		copy.set("loop", true)
	return copy
