extends CanvasLayer

## Manual test rig for PioneerAPI (TTS) and MicRecorder (STT).
## Toggle with F5. While visible: T = speak a test line, hold V = record then
## transcribe and speak the transcript back (full STT -> TTS round trip).

var panel: PanelContainer
var label: Label
var player: AudioStreamPlayer

var _visible_state: bool = false
var _log_lines: Array[String] = []
const MAX_LOG_LINES := 8

var _state: String = "idle"  # idle | recording | recording_local | transcribing | speaking
var _stream_request_ms: int = 0

func _ready() -> void:
	_create_ui()
	visible = _visible_state

	player = AudioStreamPlayer.new()
	add_child(player)

	if OS.has_feature("editor"):
		print("[PioneerVoiceDebugOverlay] Ready - Press F5 to toggle, T/Y to test speak (buffered/streaming), hold V for STT round trip, hold M for local mic test")

func _create_ui() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(10, 250)
	panel.modulate = Color(1, 1, 1, 0.9)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	label = Label.new()
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	layer = 128

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		_visible_state = not _visible_state
		visible = _visible_state
		if visible:
			_refresh_label()

	if not visible:
		return

	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_T and event.pressed:
			_test_speak()
		elif event.keycode == KEY_Y and event.pressed:
			_test_speak_streaming()
		elif event.keycode == KEY_V:
			if event.pressed and _state == "idle":
				_start_recording()
			elif not event.pressed and _state == "recording":
				_stop_recording_and_transcribe()
		elif event.keycode == KEY_M:
			if event.pressed and _state == "idle":
				_start_local_mic_test()
			elif not event.pressed and _state == "recording_local":
				_stop_local_mic_test()

func _test_speak() -> void:
	if _state != "idle":
		return
	_state = "speaking"
	_log("Speaking test line...")
	_connect_speech_signals_once()
	PioneerAPI.speak("Hello, this is a test of the Pioneer voice API.")

func _test_speak_streaming() -> void:
	if _state != "idle":
		return
	_state = "speaking"
	_log("Speaking test line (streaming)...")
	_stream_request_ms = Time.get_ticks_msec()
	if not PioneerAPI.stream_started.is_connected(_on_stream_started):
		PioneerAPI.stream_started.connect(_on_stream_started, CONNECT_ONE_SHOT)
	if not PioneerAPI.stream_finished.is_connected(_on_stream_finished):
		PioneerAPI.stream_finished.connect(_on_stream_finished, CONNECT_ONE_SHOT)
	if not PioneerAPI.stream_failed.is_connected(_on_stream_failed):
		PioneerAPI.stream_failed.connect(_on_stream_failed, CONNECT_ONE_SHOT)
	PioneerAPI.speak_streaming("Hello, this is a test of the Pioneer streaming voice API.", "", player)

func _start_recording() -> void:
	_state = "recording"
	MicRecorder.start_recording()
	_log("Recording... (release V to stop)")

func _stop_recording_and_transcribe() -> void:
	var wav_bytes := MicRecorder.stop_recording()
	if wav_bytes.is_empty():
		_log("ERROR: no audio captured - check 'Mic' bus / mic permissions")
		_state = "idle"
		return
	_state = "transcribing"
	_log("Transcribing %d bytes..." % wav_bytes.size())
	_connect_transcript_signals_once()
	PioneerAPI.transcribe(wav_bytes)

func _start_local_mic_test() -> void:
	_state = "recording_local"
	MicRecorder.start_recording()
	_log("Recording (local test, no API call)... release M to stop")

func _stop_local_mic_test() -> void:
	MicRecorder.stop_recording()
	_state = "idle"

	var recording := MicRecorder.last_recording
	if recording == null or recording.data.is_empty():
		_log("ERROR: captured 0 bytes - check System Settings > Privacy > Microphone, and OS input device")
		return

	var duration := recording.get_length()
	var peak := _peak_level(recording)
	var peak_text := "%.0f%%" % (peak * 100.0) if peak >= 0.0 else "unknown format"
	_log("Captured %.2fs, peak level %s" % [duration, peak_text])
	if peak == 0.0:
		_log("WARNING: recording is pure silence - wrong input device selected, or mic muted/blocked at the OS level")
	elif peak >= 0.0 and peak < 0.02:
		_log("WARNING: peak level very low - check mic gain / distance from mic")

	player.stream = recording
	player.play()
	_log("Playing back your recording locally...")

func _peak_level(recording: AudioStreamWAV) -> float:
	# Only handles the common 16-bit PCM case AudioEffectRecord produces by default.
	if recording.format != AudioStreamWAV.FORMAT_16_BITS:
		return -1.0
	var bytes := recording.data
	var peak := 0
	var i := 0
	while i + 1 < bytes.size():
		var sample := bytes.decode_s16(i)
		peak = max(peak, abs(sample))
		i += 2
	return peak / 32768.0

func _on_speech_ready(stream: AudioStream) -> void:
	player.stream = stream
	player.play()
	_log("Speech ready, playing back.")
	_state = "idle"

func _on_speech_failed(error: String) -> void:
	_log("TTS failed: %s" % error)
	_state = "idle"

func _on_stream_started() -> void:
	var elapsed_ms := Time.get_ticks_msec() - _stream_request_ms
	_log("Stream audio started after %d ms" % elapsed_ms)

func _on_stream_finished() -> void:
	_log("Stream finished.")
	_state = "idle"

func _on_stream_failed(error: String) -> void:
	_log("Streaming TTS failed: %s" % error)
	_state = "idle"

func _on_transcript_ready(text: String) -> void:
	_log("You said: \"%s\"" % text)
	if text.is_empty():
		_state = "idle"
		return
	_state = "speaking"
	_connect_speech_signals_once()
	PioneerAPI.speak(text)

func _on_transcript_failed(error: String) -> void:
	_log("STT failed: %s" % error)
	_state = "idle"

func _connect_speech_signals_once() -> void:
	# One-shot per call so this overlay only reacts to its own requests -
	# PioneerAPI's signals are global/broadcast, so a permanent connection here
	# would also fire (and speak) for unrelated callers like StudioAssistantVoiceChat.
	if not PioneerAPI.speech_ready.is_connected(_on_speech_ready):
		PioneerAPI.speech_ready.connect(_on_speech_ready, CONNECT_ONE_SHOT)
	if not PioneerAPI.speech_failed.is_connected(_on_speech_failed):
		PioneerAPI.speech_failed.connect(_on_speech_failed, CONNECT_ONE_SHOT)

func _connect_transcript_signals_once() -> void:
	if not PioneerAPI.transcript_ready.is_connected(_on_transcript_ready):
		PioneerAPI.transcript_ready.connect(_on_transcript_ready, CONNECT_ONE_SHOT)
	if not PioneerAPI.transcript_failed.is_connected(_on_transcript_failed):
		PioneerAPI.transcript_failed.connect(_on_transcript_failed, CONNECT_ONE_SHOT)

func _log(line: String) -> void:
	var timestamp := Time.get_time_string_from_system()
	_log_lines.append("[%s] %s" % [timestamp, line])
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	print("[PioneerVoiceDebugOverlay] %s" % line)
	_refresh_label()

func _refresh_label() -> void:
	var text := "PIONEER VOICE TEST (F5)\n"
	text += "Backend: %s\n" % PioneerAPI.API_BASE
	text += "State: %s\n" % _state
	text += "T = speak test line (buffered) | Y = speak test line (streaming, shows latency)\n"
	text += "Hold V = record+transcribe+speak back (uses API)\n"
	text += "Hold M = record + play back locally (no API, tests mic only)\n"
	text += "----------------------------------------\n"
	for line in _log_lines:
		text += line + "\n"
	label.text = text

func _process(_delta: float) -> void:
	if visible and (_state == "recording" or _state == "recording_local"):
		_refresh_label()
