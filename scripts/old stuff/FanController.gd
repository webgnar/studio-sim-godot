extends Node3D
## Controls fan blade animation and sound based on power state

@export var powered_device: PoweredDeviceComponent
@export var animation_player: AnimationPlayer
@export var spin_animation_name: String = "spin"

@export_group("Fan Audio")
@export var running_loop_sound: AudioStream ## Continuous looping sound while running
@export var fade_duration: float = 0.5 ## Duration of fade in/out in seconds

var _loop_player: AudioStreamPlayer3D
var _is_fading: bool = false

func _ready() -> void:
	if not powered_device:
		print("⚠️ FanController: No PoweredDeviceComponent assigned!")
		return
	
	if not animation_player:
		print("⚠️ FanController: No AnimationPlayer assigned!")
		return
	
	# Setup audio players
	_setup_audio()
	
	# Connect to power signals
	powered_device.device_turned_on.connect(_on_fan_turned_on)
	powered_device.device_turned_off.connect(_on_fan_turned_off)
	
	# Set initial state
	if powered_device.is_on and powered_device.has_power:
		animation_player.play(spin_animation_name)
		if _loop_player:
			_loop_player.play()
			_loop_player.volume_db = -5.0  # Already on, no fade needed
	else:
		animation_player.stop()
		if _loop_player:
			_loop_player.stop()

func _setup_audio() -> void:
	"""Create audio player for fan loop sound"""
	if running_loop_sound:
		_loop_player = AudioStreamPlayer3D.new()
		_loop_player.name = "FanLoopAudio"

		# Ensure the stream is set to loop
		if running_loop_sound is AudioStreamOggVorbis:
			running_loop_sound.loop = true
		elif running_loop_sound is AudioStreamWAV:
			running_loop_sound.loop_mode = AudioStreamWAV.LOOP_FORWARD

		_loop_player.stream = running_loop_sound
		_loop_player.max_distance = 15.0
		_loop_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_loop_player.volume_db = -80.0  # Start silent for fade in
		_loop_player.bus = "SFX"
		add_child(_loop_player)

func _on_fan_turned_on() -> void:
	"""Start spinning the fan with fade in"""
	if animation_player:
		animation_player.play(spin_animation_name)

	# Fade in the loop sound
	if _loop_player:
		_fade_in_sound()

func _on_fan_turned_off() -> void:
	"""Stop spinning the fan with fade out"""
	if animation_player:
		animation_player.stop()

	# Fade out the loop sound
	if _loop_player:
		_fade_out_sound()

func _fade_in_sound() -> void:
	"""Fade in the fan loop sound"""
	if _is_fading:
		return
	
	_is_fading = true
	
	if not _loop_player.playing:
		_loop_player.play()
	
	var target_volume: float = -5.0  # Normal running volume
	var start_volume: float = -80.0  # Silent
	_loop_player.volume_db = start_volume

	var tween = create_tween()
	tween.tween_property(_loop_player, "volume_db", target_volume, fade_duration)
	tween.finished.connect(func():
		_is_fading = false
	)

func _fade_out_sound() -> void:
	"""Fade out the fan loop sound"""
	if _is_fading:
		return
	
	_is_fading = true

	var target_volume: float = -80.0  # Silent

	var tween = create_tween()
	tween.tween_property(_loop_player, "volume_db", target_volume, fade_duration)
	tween.finished.connect(func():
		_loop_player.stop()
		_is_fading = false
	)
