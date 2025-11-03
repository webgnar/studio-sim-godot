extends CarryableComponent
class_name BoomboxInteraction
## Boombox interaction component - handles radio playback with secret song system
## Extends CarryableComponent to allow pickup + E-key interaction

enum BoomboxState {
	OFF,
	PLAYING,
	LOADING
}

signal audio_started(song_name: String)
signal audio_stopped

@export_group("Boombox Settings")
@export var boombox_id: String = "boombox_1"

@export_group("Audio Settings")
@export var audio_file: AudioStream  # Main audio file
@export var secret_audio_file: AudioStream  # Secret audio file
@export var switch_sound: AudioStream
@export var default_volume: float = 0.5
@export var max_hearing_distance: float = 15.0
@export var min_distance: float = 1.0
@export var attenuation_model: AudioStreamPlayer3D.AttenuationModel = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

var _current_state: BoomboxState = BoomboxState.OFF
var _is_playing_secret_song: bool = false
var _main_song_has_played: bool = false
var _animation_player: AnimationPlayer
var _radio_audio_player: AudioStreamPlayer3D
var _switch_audio_player: AudioStreamPlayer3D

func _ready() -> void:
	# Call parent ready first (CarryableComponent._ready())
	super._ready()
	
	# Enable E-key interaction while allowing pickup (AFTER parent ready)
	has_e_key_interaction = true
	can_interact_while_carried = true  # Can toggle radio while carrying!
	e_key_interaction_text = "Turn On Radio"
	
	# Adjust carry physics for boombox
	carry_smoothness = 8.0  # Slightly less aggressive
	carry_distance_offset = 0.0  # Keep at default distance
	lock_rotation_when_carried = true  # Don't tumble while carrying
	drop_distance = 2.0  # Give more leeway before auto-drop
	
	_setup_radio_audio()
	_setup_switch_audio()
	_setup_animation()
	
	if audio_file:
		print("Main audio file loaded: " + str(audio_file.resource_path))
	if secret_audio_file:
		print("🤫 Secret audio file loaded: " + str(secret_audio_file.resource_path))
	
	print("✅ BoomboxInteraction ready: " + parent_object.name + " (ID: " + boombox_id + ")")
	print("🎵 Secret song system activated!")

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
	add_child(_radio_audio_player)
	print("📻 Radio audio player created")

func _setup_switch_audio() -> void:
	if switch_sound:
		_switch_audio_player = AudioStreamPlayer3D.new()
		_switch_audio_player.name = "SwitchPlayer"
		_switch_audio_player.max_distance = 5.0
		_switch_audio_player.volume_db = -10.0
		add_child(_switch_audio_player)
		print("🔊 Switch audio player created")

func _setup_animation() -> void:
	_animation_player = find_animation_player()
	
	if _animation_player:
		print("✅ Found AnimationPlayer for boombox: " + _animation_player.name)
		_animation_player.stop()
	else:
		print("⚠️ No AnimationPlayer found in boombox - animation features disabled")

func _toggle_radio() -> void:
	if switch_sound and _switch_audio_player:
		_switch_audio_player.stream = switch_sound
		_switch_audio_player.play()
		print("🔊 Playing boombox switch sound")
	
	match _current_state:
		BoomboxState.OFF:
			if _radio_audio_player and _radio_audio_player.stream_paused:
				_resume_audio()
			else:
				_start_audio()
		BoomboxState.PLAYING:
			_stop_audio()
		BoomboxState.LOADING:
			print("Audio is loading, please wait...")

func _start_audio() -> void:
	var song_to_play: AudioStream = null
	var song_name: String = ""
	
	if _main_song_has_played and secret_audio_file:
		song_to_play = secret_audio_file
		song_name = "Halloween (Secret Song)"
		_is_playing_secret_song = true
		print("🤫 Starting SECRET SONG!")
	elif audio_file:
		song_to_play = audio_file
		song_name = "Ministudio"
		_is_playing_secret_song = false
		print("🎵 Starting main song")
	else:
		print("❌ No audio files assigned to boombox!")
		return
	
	_radio_audio_player.stream = song_to_play
	_radio_audio_player.play()
	_current_state = BoomboxState.PLAYING
	e_key_interaction_text = "Turn Off Radio"
	
	print("🎵 Audio stream set: " + str(song_to_play))
	print("🎵 Audio player playing: " + str(_radio_audio_player.playing))
	print("🎵 Audio player stream: " + str(_radio_audio_player.stream))
	
	if _animation_player and _animation_player.has_animation("default"):
		_animation_player.play("default")
		print("🎬 Started boombox animation")
	elif _animation_player:
		var anim_list = _animation_player.get_animation_list()
		if anim_list.size() > 0:
			_animation_player.play(anim_list[0])
			print("🎬 Started boombox animation: " + str(anim_list[0]))
	
	audio_started.emit(song_name)
	print("✅ Now playing: " + song_name)

func _stop_audio() -> void:
	if _radio_audio_player and _radio_audio_player.playing:
		print("⏸️ Pausing audio (will resume from current position)")
		_radio_audio_player.stream_paused = true
		_current_state = BoomboxState.OFF
		e_key_interaction_text = "Turn On Radio"
		
		if _animation_player and _animation_player.is_playing():
			_animation_player.pause()
			print("⏸️ Paused boombox animation")
		
		audio_stopped.emit()
		print("📻 Audio paused")

func _resume_audio() -> void:
	if _radio_audio_player and _radio_audio_player.stream_paused:
		print("▶️ Resuming audio from paused position")
		_radio_audio_player.stream_paused = false
		_current_state = BoomboxState.PLAYING
		e_key_interaction_text = "Turn Off Radio"
		
		if _animation_player and not _animation_player.is_playing():
			_animation_player.play()
			print("▶️ Resumed boombox animation")
		
		audio_started.emit("Audio Resumed")
		print("✅ Audio resumed")

func _check_if_audio_finished() -> void:
	if _radio_audio_player and not _radio_audio_player.playing and not _radio_audio_player.stream_paused:
		if _animation_player and _animation_player.is_playing():
			_animation_player.stop()
			print("🎬 Stopped boombox animation (song finished)")
		
		if _is_playing_secret_song:
			print("🤫 Secret song (Halloween) finished playing")
			_current_state = BoomboxState.OFF
			e_key_interaction_text = "Turn On Radio"
			audio_stopped.emit()
			print("📻 Boombox turned off (secret song ended)")
		else:
			print("🎵 Main song (Ministudio) finished playing")
			_main_song_has_played = true
			_current_state = BoomboxState.OFF
			e_key_interaction_text = "Turn On Radio"
			audio_stopped.emit()
			print("📻 Boombox turned off (main song ended)")
			print("🤫 SECRET UNLOCKED! Next time you turn on the boombox, you'll hear a secret song!")

func get_radio_state() -> BoomboxState:
	return _current_state

func is_radio_playing() -> bool:
	return _current_state == BoomboxState.PLAYING

func set_volume(volume: float) -> void:
	if _radio_audio_player:
		_radio_audio_player.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))

func get_current_audio_name() -> String:
	if _is_playing_secret_song and secret_audio_file:
		return secret_audio_file.resource_path.get_file()
	elif audio_file:
		return audio_file.resource_path.get_file()
	return "No Audio File"
