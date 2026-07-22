extends Node

## MicRecorder - Captures microphone input as WAV bytes for PioneerAPI.transcribe()
## Requires a "Mic" audio bus whose first effect is an AudioEffectRecord (see default_bus_layout.tres)

const RECORD_BUS_NAME := "Mic"
const _TEMP_WAV_PATH := "user://_pioneer_mic_take.wav"
const _LEVEL_MIN_DB := -60.0

var is_recording: bool = false

## The raw AudioStreamWAV from the most recent recording - handy for local
## playback tests without round-tripping through PackedByteArray/PioneerAPI.
var last_recording: AudioStreamWAV

var _record_effect: AudioEffectRecord
var _mic_player: AudioStreamPlayer
var _bus_idx: int = -1

func _ready() -> void:
	_bus_idx = AudioServer.get_bus_index(RECORD_BUS_NAME)
	if _bus_idx == -1:
		push_warning("MicRecorder: '%s' audio bus not found - add one with an AudioEffectRecord to enable voice input" % RECORD_BUS_NAME)
		return

	var effect := AudioServer.get_bus_effect(_bus_idx, 0)
	if not (effect is AudioEffectRecord):
		push_warning("MicRecorder: first effect on '%s' bus must be an AudioEffectRecord" % RECORD_BUS_NAME)
		return
	_record_effect = effect

	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicInput"
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = RECORD_BUS_NAME
	add_child(_mic_player)

## Current input loudness (0.0-1.0) for a live voice-recording visualizer.
## Only meaningful while is_recording is true (that's when the mic is
## actually feeding the bus this reads the peak meter from).
func get_current_level() -> float:
	if _bus_idx == -1:
		return 0.0
	var db := maxf(
		AudioServer.get_bus_peak_volume_left_db(_bus_idx, 0),
		AudioServer.get_bus_peak_volume_right_db(_bus_idx, 0)
	)
	return clampf((db - _LEVEL_MIN_DB) / -_LEVEL_MIN_DB, 0.0, 1.0)

func start_recording() -> void:
	if not _record_effect or is_recording:
		return
	_mic_player.play()
	_record_effect.set_recording_active(true)
	is_recording = true

## Stops recording and returns the captured audio as raw WAV bytes (empty on failure)
func stop_recording() -> PackedByteArray:
	if not _record_effect or not is_recording:
		return PackedByteArray()

	_record_effect.set_recording_active(false)
	_mic_player.stop()
	is_recording = false

	var recording: AudioStreamWAV = _record_effect.get_recording()
	last_recording = recording
	if recording == null:
		return PackedByteArray()

	if recording.save_to_wav(_TEMP_WAV_PATH) != OK:
		return PackedByteArray()

	var bytes := FileAccess.get_file_as_bytes(_TEMP_WAV_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TEMP_WAV_PATH))
	return bytes
