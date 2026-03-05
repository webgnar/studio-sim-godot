extends CarryableComponent
class_name BoomboxInteraction
## Boombox interaction component - handles radio playback with 3-song cycling
## Extends CarryableComponent to allow pickup + E-key interaction
## Interaction: Stop if playing, advance to next song if stopped

enum BoomboxState {
	OFF,
	PLAYING,
	LOADING
}

signal audio_started(song_name: String)
signal audio_stopped

@export_group("Boombox Settings")
@export var boombox_id: String = "boombox_1"
@export var auto_play_on_start: bool = false  # Auto-play song 1 when scene loads

@export_group("Audio Settings")
@export var songs: Array[AudioStream]  # Add any number of songs in the inspector
@export var switch_sound: AudioStream
@export var default_volume: float = 0.5
@export var max_hearing_distance: float = 15.0
@export var min_distance: float = 1.0
@export var attenuation_model: AudioStreamPlayer3D.AttenuationModel = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

var _current_state: BoomboxState = BoomboxState.OFF
var _current_song_index: int = 0  # Track which song to play next (0, 1, or 2)
var _animation_player: AnimationPlayer
var _radio_audio_player: AudioStreamPlayer3D
var _switch_audio_player: AudioStreamPlayer3D

func _ready() -> void:
	# Call parent ready first (CarryableComponent._ready())
	super._ready()

	# Enable E-key interaction while allowing pickup (AFTER parent ready)
	has_e_key_interaction = true
	can_interact_while_carried = true  # Can toggle radio while carrying!
	enable_floor_freeze = true  # Prevent twitching when resting on floor
	# e_key_interaction_text set via inspector

	# Adjust carry physics for boombox
	carry_smoothness = 8.0  # Slightly less aggressive
	carry_distance_offset = 0.0  # Keep at default distance
	lock_rotation_when_carried = true  # Don't tumble while carrying
	drop_distance = 2.0  # Give more leeway before auto-drop

	_setup_radio_audio()
	_setup_switch_audio()
	_setup_animation()

	# Auto-play song 1 if enabled
	if auto_play_on_start:
		_current_song_index = 0  # Set to song 1
		_start_audio()
		print("Boombox auto-playing song 1 on scene load")

func _process(_delta: float) -> void:
	if _current_state == BoomboxState.PLAYING:
		_check_if_audio_finished()

func _on_e_key_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	_toggle_radio()

func _setup_radio_audio() -> void:
	_radio_audio_player = AudioStreamPlayer3D.new()
	_radio_audio_player.name = "RadioPlayer"
	_radio_audio_player.volume_db = linear_to_db(default_volume)
	_radio_audio_player.attenuation_model = attenuation_model
	_radio_audio_player.max_distance = max_hearing_distance
	_radio_audio_player.unit_size = min_distance
	_radio_audio_player.emission_angle_enabled = false
	_radio_audio_player.panning_strength = 1.0
	_radio_audio_player.bus = "Music"
	add_child(_radio_audio_player)

func _setup_switch_audio() -> void:
	if switch_sound:
		_switch_audio_player = AudioStreamPlayer3D.new()
		_switch_audio_player.name = "SwitchPlayer"
		_switch_audio_player.max_distance = 5.0
		_switch_audio_player.volume_db = -10.0
		_switch_audio_player.bus = "SFX"
		add_child(_switch_audio_player)

func _setup_animation() -> void:
	_animation_player = find_animation_player()

	if _animation_player:
		_animation_player.stop()

func _toggle_radio() -> void:
	if switch_sound and _switch_audio_player:
		_switch_audio_player.stream = switch_sound
		_switch_audio_player.play()

	match _current_state:
		BoomboxState.OFF:
			# Not playing - advance to next song and play it
			_start_next_song()
		BoomboxState.PLAYING:
			# Playing - stop it completely
			_stop_audio()
		BoomboxState.LOADING:
			print("Audio is loading, please wait...")

func _start_next_song() -> void:
	# Advance to the next song in the cycle
	if songs.is_empty():
		return
	_current_song_index = (_current_song_index + 1) % songs.size()
	_start_audio()

func _start_audio() -> void:
	if songs.is_empty() or _current_song_index >= songs.size():
		print("No song assigned to slot " + str(_current_song_index + 1))
		return

	var song_to_play: AudioStream = songs[_current_song_index]
	var song_name: String = "Song " + str(_current_song_index + 1)

	if not song_to_play:
		print("No song assigned to slot " + str(_current_song_index + 1))
		return

	_radio_audio_player.stream = song_to_play
	_radio_audio_player.play()
	_current_state = BoomboxState.PLAYING

	if _animation_player and _animation_player.has_animation("default"):
		_animation_player.play("default")
	elif _animation_player:
		var anim_list = _animation_player.get_animation_list()
		if anim_list.size() > 0:
			_animation_player.play(anim_list[0])

	audio_started.emit(song_name)
	print("Now playing: " + song_name)

func _stop_audio() -> void:
	if _radio_audio_player and _radio_audio_player.playing:
		_radio_audio_player.stop()  # Actually stop, not pause
		_current_state = BoomboxState.OFF

		if _animation_player and _animation_player.is_playing():
			_animation_player.stop()

		audio_stopped.emit()
		print("Stopped playing")

func _check_if_audio_finished() -> void:
	# When a song finishes, loop it by restarting playback
	if _radio_audio_player and not _radio_audio_player.playing:
		# Restart the same song to create a loop
		_radio_audio_player.play()

func get_radio_state() -> BoomboxState:
	return _current_state

func is_radio_playing() -> bool:
	return _current_state == BoomboxState.PLAYING

func set_volume(volume: float) -> void:
	if _radio_audio_player:
		_radio_audio_player.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))

func get_current_audio_name() -> String:
	if not songs.is_empty() and _current_song_index < songs.size() and songs[_current_song_index]:
		return songs[_current_song_index].resource_path.get_file()
	return "No Audio File"
