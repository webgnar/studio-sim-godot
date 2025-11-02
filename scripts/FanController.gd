extends Node3D
## Controls fan blade animation and sound based on power state

@export var powered_device: PoweredDeviceComponent
@export var animation_player: AnimationPlayer
@export var spin_animation_name: String = "spin"

@export_group("Fan Audio")
@export var startup_sound: AudioStream ## Sound when fan starts spinning
@export var shutdown_sound: AudioStream ## Sound when fan stops spinning
@export var running_loop_sound: AudioStream ## Continuous looping sound while running

var _audio_player: AudioStreamPlayer3D
var _loop_player: AudioStreamPlayer3D

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
	powered_device.powered_off.connect(_on_power_lost)
	
	# Set initial state
	if powered_device.is_on and powered_device.has_power:
		animation_player.play(spin_animation_name)
		_start_loop_sound()
	else:
		animation_player.stop()
		_stop_loop_sound()
	
	print("✅ FanController ready")

func _setup_audio() -> void:
	"""Create audio players for fan sounds"""
	# One-shot sounds (startup/shutdown)
	if startup_sound or shutdown_sound:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "FanAudio"
		_audio_player.max_distance = 15.0
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(_audio_player)
	
	# Looping sound (continuous running)
	if running_loop_sound:
		_loop_player = AudioStreamPlayer3D.new()
		_loop_player.name = "FanLoopAudio"
		_loop_player.stream = running_loop_sound
		_loop_player.max_distance = 15.0
		_loop_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_loop_player.volume_db = -5.0  # Slightly quieter for ambience
		add_child(_loop_player)

func _on_fan_turned_on() -> void:
	"""Start spinning the fan"""
	if animation_player:
		animation_player.play(spin_animation_name)
		print("🌀 Fan spinning")
	
	# Play startup sound and wait for it to finish
	if startup_sound and _audio_player:
		_audio_player.stream = startup_sound
		_audio_player.play()
		print("🔊 Playing fan startup sound")
		# Wait for startup sound to finish before starting loop
		await _audio_player.finished
	
	# Start loop sound after startup finishes
	if running_loop_sound and _loop_player:
		_start_loop_sound()

func _on_fan_turned_off() -> void:
	"""Stop spinning the fan"""
	if animation_player:
		animation_player.stop()
		print("⏹️ Fan stopped")
	
	# Stop loop sound immediately
	_stop_loop_sound()
	
	# Play shutdown sound right after loop stops
	if shutdown_sound and _audio_player:
		_audio_player.stream = shutdown_sound
		_audio_player.play()
		print("🔊 Playing fan shutdown sound")

func _on_power_lost() -> void:
	"""Power cut - stop the fan without shutdown sound"""
	if animation_player:
		animation_player.stop()
		print("⚡ Fan lost power")
	
	# Stop loop sound immediately (no shutdown sound when power is lost)
	_stop_loop_sound()
	print("⚡ Fan stopped due to power loss (no shutdown sound)")

func _start_loop_sound() -> void:
	"""Start the continuous fan running loop"""
	if _loop_player and not _loop_player.playing:
		_loop_player.play()
		print("🔊 Fan loop sound started")

func _stop_loop_sound() -> void:
	"""Stop the continuous fan running loop"""
	if _loop_player and _loop_player.playing:
		_loop_player.stop()
		print("🔇 Fan loop sound stopped")
