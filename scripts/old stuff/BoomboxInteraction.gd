extends CarryableComponent
class_name BoomboxInteraction

enum BoomboxState { OFF, PLAYING, LOADING }

signal audio_started(label: String)
signal audio_stopped

@export_group("Boombox Settings")
@export var boombox_id: String = "boombox_1"
@export var auto_play_on_start: bool = false

@export_group("Audio Settings")
@export var songs: Array[AudioStream]
@export var song_names: Array[String] = []  # Optional display names, parallel to `songs`. Falls back to the filename if empty/missing for that index.
@export var switch_sound: AudioStream
@export var dial_up_sound: AudioStream
@export var default_volume: float = 0.5
@export var max_hearing_distance: float = 15.0
@export var min_distance: float = 1.0
@export var attenuation_model: AudioStreamPlayer3D.AttenuationModel = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

@export_group("Radio Stations")
@export var radio_stations: Array[Dictionary] = [
	{"name": "Radio 1", "url": "https://radiok.broadcasttool.stream/play_128"},
	{"name": "Radio 2", "url": "https://streams.wtju.net/wxtj-live.mp3"},
	{"name": "Radio 3", "url": "https://kexp-mp3-128.streamguys1.com/kexp128.mp3"},
	{"name": "Radio 4", "url": "http://streaming.wrek.org:8000/wrek_live-128kb"},
]

var _current_state: BoomboxState = BoomboxState.OFF
var _current_index: int = -1
var _is_radio_entry: bool = false
var _playlist: Array[Dictionary] = []

var _animation_player: AnimationPlayer
var _local_player: AudioStreamPlayer3D
var _switch_player: AudioStreamPlayer3D
var _dial_up_player: AudioStreamPlayer3D
var _stream_slot_a: AudioStreamPlayer3D
var _stream_slot_b: AudioStreamPlayer3D
var _active_slot: AudioStreamPlayer3D
var _inactive_slot: AudioStreamPlayer3D
var _next_chunk: AudioStreamMP3 = null
var _radio: RadioStreamPlayer
var _rf_mesh: MeshInstance3D


func _ready() -> void:
	super._ready()

	has_e_key_interaction = true
	can_interact_while_carried = true
	enable_floor_freeze = true
	carry_smoothness = 8.0
	carry_distance_offset = 0.0
	lock_rotation_when_carried = true
	drop_distance = 2.0

	_rf_mesh = get_parent().get_node_or_null("RF")
	if _rf_mesh:
		_rf_mesh.visible = ShopManager.is_purchased("rf_receiver")

	_build_playlist()
	_setup_local_player()
	_setup_switch_player()
	_setup_dial_up_player()
	_setup_stream_slots()
	_setup_radio_stream_player()
	_setup_animation()

	WorldStateManager.world_state_loaded.connect(_on_world_state_loaded, CONNECT_ONE_SHOT)
	ShopManager.item_purchased.connect(_on_item_purchased)
	audio_started.connect(_on_audio_started)


const _DEFAULT_STATIONS := [
	{"name": "Radio 1", "url": "https://radiok.broadcasttool.stream/play_128"},
	{"name": "Radio 2", "url": "https://streams.wtju.net/wxtj-live.mp3"},
	{"name": "Radio 3", "url": "https://kexp-mp3-128.streamguys1.com/kexp128.mp3"},
	{"name": "Radio 4", "url": "http://streaming.wrek.org:8000/wrek_live-128kb"},
]

func _build_playlist() -> void:
	var local_entries: Array[Dictionary] = []
	for i in range(songs.size()):
		var s = songs[i]
		if not s:
			continue
		var label: String = s.resource_path.get_file().get_basename()
		if i < song_names.size() and song_names[i] != "":
			label = song_names[i]
		local_entries.append({"type": "local", "stream": s, "label": label})

	var radio_entries: Array[Dictionary] = []
	if ShopManager.is_purchased("rf_receiver"):
		var stations := radio_stations if radio_stations.size() > 0 else _DEFAULT_STATIONS
		for r in stations:
			var url: String = r.get("url", "")
			var label: String = r.get("name", "Radio")
			if url.length() > 0:
				radio_entries.append({"type": "radio", "url": url, "label": label})

	# Stagger radio stations between songs: insert one radio entry after each song,
	# cycling through stations if there are more songs than stations (or vice versa).
	var total := maxi(local_entries.size(), radio_entries.size())
	for i in range(total):
		if i < local_entries.size():
			_playlist.append(local_entries[i])
		if i < radio_entries.size():
			_playlist.append(radio_entries[i])



func _on_item_purchased(item_id: String) -> void:
	if item_id == "rf_receiver":
		if _rf_mesh:
			_rf_mesh.visible = true
		var current_label := ""
		if _current_index >= 0 and _current_index < _playlist.size():
			current_label = _playlist[_current_index].get("label", "")
		_playlist.clear()
		_build_playlist()
		if current_label != "":
			for i in range(_playlist.size()):
				if _playlist[i].get("label", "") == current_label:
					_current_index = i
					return
		_current_index = maxi(_current_index, -1)


func _setup_local_player() -> void:
	_local_player = _make_3d_player("LocalPlayer", "Music")


func _setup_switch_player() -> void:
	if not switch_sound:
		return
	_switch_player = AudioStreamPlayer3D.new()
	_switch_player.name = "SwitchPlayer"
	_switch_player.max_distance = 5.0
	_switch_player.volume_db = -10.0
	_switch_player.bus = "SFX"
	add_child(_switch_player)


func _setup_dial_up_player() -> void:
	if not dial_up_sound:
		return
	_dial_up_player = AudioStreamPlayer3D.new()
	_dial_up_player.name = "DialUpPlayer"
	_dial_up_player.max_distance = max_hearing_distance
	_dial_up_player.unit_size = min_distance
	_dial_up_player.volume_db = linear_to_db(default_volume)
	_dial_up_player.bus = "SFX"
	add_child(_dial_up_player)


func _setup_stream_slots() -> void:
	_stream_slot_a = _make_3d_player("StreamA", "Music")
	_stream_slot_b = _make_3d_player("StreamB", "Music")
	_active_slot = _stream_slot_a
	_inactive_slot = _stream_slot_b


func _setup_radio_stream_player() -> void:
	_radio = RadioStreamPlayer.new()
	add_child(_radio)
	_radio.chunk_ready.connect(_on_chunk_ready)
	# Deliberately not wiring station_name_resolved (the real ICY-NAME from the
	# live stream) into audio_started — station labels are simplified to
	# "Radio 1/2/3/4" and shouldn't get silently overridden once a stream connects.
	_radio.stream_error.connect(_on_stream_error)


func _setup_animation() -> void:
	_animation_player = find_animation_player()
	if _animation_player:
		_animation_player.stop()


func _make_3d_player(node_name: String, bus: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = node_name
	p.volume_db = linear_to_db(default_volume)
	p.attenuation_model = attenuation_model
	p.max_distance = max_hearing_distance
	p.unit_size = min_distance
	p.emission_angle_enabled = false
	p.panning_strength = 1.0
	p.bus = bus
	add_child(p)
	return p


func _on_world_state_loaded() -> void:
	var saved = WorldStateManager.get_data("boombox_" + boombox_id, null)
	if saved != null:
		_current_index = saved.get("playlist_index", -1)
		if saved.get("is_playing", false) and _current_index >= 0 and _current_index < _playlist.size():
			_play_entry(_current_index)
	elif auto_play_on_start:
		_current_index = 0
		_play_entry(0)


func _process(_delta: float) -> void:
	match _current_state:
		BoomboxState.PLAYING:
			if _is_radio_entry:
				_maybe_swap_radio_chunk()
			else:
				_check_local_finished()


func _on_e_key_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	_toggle_radio()


func _toggle_radio() -> void:
	_play_switch_sound()
	match _current_state:
		BoomboxState.OFF:
			_advance_and_play()
		BoomboxState.PLAYING, BoomboxState.LOADING:
			_stop_all()


func _advance_and_play() -> void:
	if _playlist.is_empty():
		return
	_current_index = (_current_index + 1) % _playlist.size()
	_play_entry(_current_index)


func _play_entry(index: int) -> void:
	var entry: Dictionary = _playlist[index]
	_is_radio_entry = entry["type"] == "radio"
	if _is_radio_entry:
		_local_player.stop()
		_active_slot.stop()
		_inactive_slot.stop()
		_next_chunk = null
		_current_state = BoomboxState.LOADING
		e_key_interaction_text = "Tuning in..."
		_start_animation()
		audio_started.emit("Tuning in: " + entry["label"])
		if _dial_up_player and dial_up_sound:
			_dial_up_player.stream = dial_up_sound
			_dial_up_player.play()
		_radio.connect_to_stream(entry["url"])
	else:
		_radio.disconnect_stream()
		_active_slot.stop()
		_inactive_slot.stop()
		_next_chunk = null
		_local_player.stream = entry["stream"]
		_local_player.play()
		_current_state = BoomboxState.PLAYING
		e_key_interaction_text = "Stop Tape"
		_start_animation()
		audio_started.emit(entry["label"])
		_save_state()


func _stop_all() -> void:
	_radio.disconnect_stream()
	_local_player.stop()
	_active_slot.stop()
	_inactive_slot.stop()
	if _dial_up_player:
		_dial_up_player.stop()
	_next_chunk = null
	_current_state = BoomboxState.OFF
	e_key_interaction_text = "Play Tape"
	_stop_animation()
	audio_stopped.emit()
	_save_state()


func _on_chunk_ready(stream: AudioStreamMP3) -> void:
	if _current_state == BoomboxState.LOADING:
		if _dial_up_player:
			_dial_up_player.stop()
		_active_slot.stream = stream
		_active_slot.play()
		_current_state = BoomboxState.PLAYING
		e_key_interaction_text = "Stop Radio"
		_save_state()
		_radio.resume()  # start buffering the next chunk immediately
	else:
		_next_chunk = stream
		# hold stays set — we resume only when we actually consume this chunk


func _maybe_swap_radio_chunk() -> void:
	if not _active_slot.playing and _next_chunk != null:
		_active_slot.stream = _next_chunk
		_active_slot.play()
		_next_chunk = null
		_radio.resume()


func _swap_slots() -> void:
	var tmp := _active_slot
	_active_slot = _inactive_slot
	_inactive_slot = tmp


func _check_local_finished() -> void:
	if _local_player and not _local_player.playing:
		_local_player.play()  # loop the current local song


func _on_stream_error() -> void:
	push_warning("Boombox: radio stream error — stopping")
	_current_state = BoomboxState.OFF
	_stop_animation()
	audio_stopped.emit()


func _play_switch_sound() -> void:
	if switch_sound and _switch_player:
		_switch_player.stream = switch_sound
		_switch_player.play()


func _start_animation() -> void:
	if not _animation_player:
		return
	if _animation_player.has_animation("default"):
		_animation_player.play("default")
	else:
		var list := _animation_player.get_animation_list()
		if list.size() > 0:
			_animation_player.play(list[0])


func _stop_animation() -> void:
	if _animation_player and _animation_player.is_playing():
		_animation_player.stop()


func _save_state() -> void:
	WorldStateManager.set_data("boombox_" + boombox_id, {
		"playlist_index": _current_index,
		"is_playing": _current_state != BoomboxState.OFF,
	})


func _on_audio_started(label: String) -> void:
	AchievementToast.show_toast("NOW PLAYING", label)


func get_radio_state() -> BoomboxState:
	return _current_state


func is_radio_playing() -> bool:
	return _current_state == BoomboxState.PLAYING


func set_volume(volume: float) -> void:
	var db := linear_to_db(clamp(volume, 0.0, 1.0))
	if _local_player:
		_local_player.volume_db = db
	if _stream_slot_a:
		_stream_slot_a.volume_db = db
	if _stream_slot_b:
		_stream_slot_b.volume_db = db


func get_current_label() -> String:
	if _current_index < 0 or _current_index >= _playlist.size():
		return ""
	return _playlist[_current_index].get("label", "")
