extends Node

## PioneerAPI - Singleton wrapper for voice (TTS/STT) via the studio-sim-gallery
## backend, which proxies to the Pioneer hosted AI API (alpha.pioneers.dev).
## The Pioneer key lives server-side only (PIONEER_API_KEY env var on Vercel) -
## players never see or enter a key, matching GalleryUploader's upload flow.

const API_BASE := "https://studio-sim-gallery.vercel.app/api/voice"
const API_HOST := "studio-sim-gallery.vercel.app"
const STREAM_PATH := "/api/voice/tts-stream"
const API_KEY := "jupTtic3qGOULETb2w7E"
const REQUEST_TIMEOUT := 30.0

## Pioneer's streaming endpoint sends headerless 16-bit signed PCM, mono, at
## this sample rate - confirmed empirically against the buffered /tts WAV
## response (which reports "16 bit, mono 48000 Hz" via the same voice model).
const STREAM_MIX_RATE := 48000.0
const STREAM_BUFFER_LENGTH := 0.5  # AudioStreamGenerator ring buffer, seconds
const STREAM_PREBUFFER_BYTES := 24000  # ~0.25s @ 48kHz/16-bit before playback starts

signal speech_ready(stream: AudioStream)
signal speech_failed(error: String)
signal transcript_ready(text: String)
signal transcript_failed(error: String)
signal stream_started
signal stream_finished
signal stream_failed(error: String)

var _stream_http: HTTPClient
var _stream_state: String = "idle"  # idle | connecting | requesting | body | draining_error
var _stream_playback: AudioStreamGeneratorPlayback
var _stream_body: String
var _stream_leftover: PackedByteArray
var _stream_prebuffer: PackedByteArray
var _stream_pending_frames: PackedVector2Array
var _stream_started_playing: bool = false

func _ready() -> void:
	set_process(false)

func _make_request() -> HTTPRequest:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	return http

## Low-latency alternative to speak(): starts audible playback as soon as the
## first chunk of generated speech arrives, instead of waiting for the whole
## clip. target_player must be an AudioStreamPlayer/2D/3D the caller owns -
## this drives it directly via AudioStreamGenerator rather than handing back
## a finished AudioStream. Only one stream can be in flight at a time.
func speak_streaming(text: String, voice_description: String, target_player: Node) -> void:
	if _stream_state != "idle":
		stream_failed.emit("a stream is already in progress")
		return
	if text.is_empty():
		stream_failed.emit("no text to speak")
		return

	var payload := {"text": text}
	if not voice_description.is_empty():
		payload["voice_description"] = voice_description
	_stream_body = JSON.stringify(payload)

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = STREAM_MIX_RATE
	generator.buffer_length = STREAM_BUFFER_LENGTH
	target_player.stream = generator
	target_player.play()
	_stream_playback = target_player.get_stream_playback()
	if _stream_playback == null:
		stream_failed.emit("couldn't start AudioStreamGeneratorPlayback")
		return

	_stream_leftover = PackedByteArray()
	_stream_prebuffer = PackedByteArray()
	_stream_started_playing = false

	_stream_http = HTTPClient.new()
	var err := _stream_http.connect_to_host(API_HOST, 443, TLSOptions.client())
	if err != OK:
		_fail_stream("connect_to_host failed: %s" % err)
		return

	_stream_state = "connecting"
	set_process(true)

func _process(_delta: float) -> void:
	if _stream_state == "idle":
		set_process(false)
		return

	if _stream_state == "draining":
		_drain_pending_frames()
		if _stream_pending_frames.is_empty():
			_reset_stream_state()
			stream_finished.emit()
		return

	_stream_http.poll()
	var status := _stream_http.get_status()

	match _stream_state:
		"connecting":
			match status:
				HTTPClient.STATUS_CONNECTED:
					var headers := ["Content-Type: application/json", "X-API-Key: " + API_KEY]
					var err := _stream_http.request(HTTPClient.METHOD_POST, STREAM_PATH, headers, _stream_body)
					if err != OK:
						_fail_stream("request failed: %s" % err)
						return
					_stream_state = "requesting"
				HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
					pass
				_:
					_fail_stream("connection failed, status: %d" % status)

		"requesting":
			match status:
				HTTPClient.STATUS_BODY:
					_stream_state = "body" if _stream_http.get_response_code() == 200 else "draining_error"
				HTTPClient.STATUS_CONNECTED:
					# Body-less 200 (shouldn't happen for audio, but handle it)
					_begin_draining()
				HTTPClient.STATUS_REQUESTING:
					pass
				_:
					_fail_stream("request failed, status: %d" % status)

		"body":
			var chunk := _stream_http.read_response_body_chunk()
			if chunk.size() > 0:
				_feed_stream_bytes(chunk)
			_drain_pending_frames()
			if status != HTTPClient.STATUS_BODY:
				_begin_draining()

		"draining_error":
			var chunk := _stream_http.read_response_body_chunk()
			if status != HTTPClient.STATUS_BODY:
				_fail_stream("tts stream failed, status %d" % _stream_http.get_response_code())
			elif chunk.size() == 0:
				pass

func _feed_stream_bytes(chunk: PackedByteArray) -> void:
	var combined := _stream_leftover
	combined.append_array(chunk)
	var usable_len := combined.size() - (combined.size() % 2)
	var usable := combined.slice(0, usable_len)
	_stream_leftover = combined.slice(usable_len, combined.size())

	if not _stream_started_playing:
		_stream_prebuffer.append_array(usable)
		if _stream_prebuffer.size() < STREAM_PREBUFFER_BYTES:
			return
		usable = _stream_prebuffer
		_stream_prebuffer = PackedByteArray()
		_stream_started_playing = true
		stream_started.emit()

	_enqueue_pcm_bytes(usable)

## Decodes raw PCM bytes into frames and appends them to a client-side pending
## queue (unbounded) rather than pushing straight into the AudioStreamGenerator's
## fixed-size ring buffer. Network chunks arrive in uneven bursts - pushing
## a whole burst atomically and dropping it if it doesn't fit was silently
## discarding audio (audible as choppiness). Draining a little each frame in
## _drain_pending_frames() smooths that out without ever losing samples.
func _enqueue_pcm_bytes(bytes: PackedByteArray) -> void:
	@warning_ignore("integer_division")  # Intentional: 2 bytes per 16-bit PCM sample
	var frame_count := bytes.size() / 2
	if frame_count == 0:
		return
	var frames := PackedVector2Array()
	frames.resize(frame_count)
	for i in range(frame_count):
		var sample := bytes.decode_s16(i * 2) / 32768.0
		frames[i] = Vector2(sample, sample)
	_stream_pending_frames.append_array(frames)
	_drain_pending_frames()

func _drain_pending_frames() -> void:
	if not is_instance_valid(_stream_playback) or _stream_pending_frames.is_empty():
		return
	var available := _stream_playback.get_frames_available()
	if available <= 0:
		return
	var to_push: int = min(available, _stream_pending_frames.size())
	_stream_playback.push_buffer(_stream_pending_frames.slice(0, to_push))
	_stream_pending_frames = _stream_pending_frames.slice(to_push, _stream_pending_frames.size())

func _begin_draining() -> void:
	# HTTP transfer is done, but there may still be decoded frames waiting
	# to be fed into the generator at playback speed - keep processing until
	# the pending queue is empty instead of cutting the tail off.
	if is_instance_valid(_stream_http):
		_stream_http.close()
	if not _stream_started_playing and not _stream_prebuffer.is_empty():
		_enqueue_pcm_bytes(_stream_prebuffer)
		_stream_prebuffer = PackedByteArray()
		_stream_started_playing = true
		stream_started.emit()
	_stream_state = "draining"

func _fail_stream(error: String) -> void:
	_reset_stream_state()
	stream_failed.emit(error)

func _reset_stream_state() -> void:
	_stream_state = "idle"
	_stream_playback = null
	_stream_leftover = PackedByteArray()
	_stream_prebuffer = PackedByteArray()
	_stream_pending_frames = PackedVector2Array()
	if is_instance_valid(_stream_http):
		_stream_http.close()
	set_process(false)

func speak(text: String, voice_description: String = "") -> void:
	if text.is_empty():
		speech_failed.emit("no text to speak")
		return

	var payload := {"text": text}
	if not voice_description.is_empty():
		payload["voice_description"] = voice_description

	var http := _make_request()
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			speech_failed.emit("tts request failed (result: %d)" % result)
			return
		if code != 200:
			speech_failed.emit("tts failed: %d" % code)
			return
		var stream := AudioStreamWAV.load_from_buffer(body)
		if stream == null:
			speech_failed.emit("tts: couldn't decode wav")
			return
		speech_ready.emit(stream)
	)
	var headers := ["X-API-Key: " + API_KEY, "Content-Type: application/json"]
	var error := http.request(API_BASE + "/tts", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		http.queue_free()
		speech_failed.emit("failed to start tts request: %s" % error)

func transcribe(wav_bytes: PackedByteArray) -> void:
	if wav_bytes.is_empty():
		transcript_failed.emit("no audio to transcribe")
		return

	var boundary := "PioneerBoundary%d" % Time.get_ticks_msec()
	var body := PackedByteArray()
	var head := "--%s\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"take.wav\"\r\nContent-Type: audio/wav\r\n\r\n" % boundary
	body.append_array(head.to_utf8_buffer())
	body.append_array(wav_bytes)
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())

	var http := _make_request()
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			transcript_failed.emit("stt request failed (result: %d)" % result)
			return
		if code != 200:
			transcript_failed.emit("stt failed: %d" % code)
			return
		var json := JSON.new()
		if json.parse(resp_body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
			transcript_failed.emit("stt: couldn't parse response")
			return
		transcript_ready.emit(str(json.data.get("text", "")).strip_edges())
	)
	var headers := ["X-API-Key: " + API_KEY, "Content-Type: multipart/form-data; boundary=%s" % boundary]
	var error := http.request_raw(API_BASE + "/stt", headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		http.queue_free()
		transcript_failed.emit("failed to start stt request: %s" % error)
