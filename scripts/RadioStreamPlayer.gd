class_name RadioStreamPlayer
extends Node

signal chunk_ready(stream: AudioStreamMP3)
signal station_name_resolved(name: String)
signal now_playing_changed(track_info: String)
signal stream_error

const INITIAL_CHUNK_SIZE := 245760  # 240KB — ~15s at 128kbps
const CHUNK_SIZE := 245760          # 240KB — gaps every ~15s

enum State { IDLE, CONNECTING, REQUESTING, STREAMING, ERROR }

var _state: State = State.IDLE
var _http: HTTPClient
var _buffer: PackedByteArray
var _metaint: int = 0
var _bytes_until_meta: int = 0
var _in_meta: bool = false
var _meta_bytes_left: int = 0
var _meta_read_length: bool = false
var _headers_read: bool = false
var _first_chunk_sent: bool = false
var _hold: bool = false  # pauses accumulation until caller is ready for next chunk
var _tls: bool = false


func connect_to_stream(url: String) -> void:
	disconnect_stream()
	_buffer = PackedByteArray()
	_metaint = 0
	_bytes_until_meta = 0
	_in_meta = false
	_meta_bytes_left = 0
	_meta_read_length = false
	_headers_read = false
	_first_chunk_sent = false
	_hold = false

	var parsed := _parse_url(url)
	_tls = parsed["scheme"] == "https"
	_http = HTTPClient.new()

	var tls_options: TLSOptions = TLSOptions.client_unsafe() if _tls else null
	var err := _http.connect_to_host(parsed["host"], parsed["port"], tls_options)
	if err != OK:
		_emit_error("connect_to_host failed: " + str(err))
		return

	_state = State.CONNECTING
	set_meta("_pending_url", parsed)


func disconnect_stream() -> void:
	if _http:
		_http.close()
		_http = null
	_state = State.IDLE
	_buffer = PackedByteArray()


func _process(_delta: float) -> void:
	if _state == State.IDLE or _state == State.ERROR or _http == null:
		return

	var poll_err := _http.poll()
	if poll_err != OK and poll_err != ERR_BUSY:
		_emit_error("poll error: " + str(poll_err))
		return

	var status := _http.get_status()

	match status:
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
			pass  # still connecting (TLS handshake is transparent within CONNECTING)

		HTTPClient.STATUS_CONNECTED:
			if _state == State.CONNECTING:
				_send_request()

		HTTPClient.STATUS_REQUESTING:
			pass  # waiting for response

		HTTPClient.STATUS_BODY:
			if not _headers_read:
				_read_headers()
				_headers_read = true
				_state = State.STREAMING
			_accumulate()

		HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_emit_error("connection failed (status %d)" % status)

		HTTPClient.STATUS_DISCONNECTED:
			if _state == State.STREAMING:
				# stream ended unexpectedly — flush any remaining buffer
				if _buffer.size() > 0:
					_emit_chunk()
				_emit_error("stream disconnected")


func _send_request() -> void:
	var parsed: Dictionary = get_meta("_pending_url")
	var path: String = parsed["path"]
	var host: String = parsed["host"]
	var port: int = parsed["port"]
	var default_port: int = 443 if _tls else 80
	var host_header := host if port == default_port else "%s:%d" % [host, port]

	var headers := PackedStringArray([
		"Host: " + host_header,
		"Icy-MetaData: 1",
		"User-Agent: GodotRadio/1.0",
		"Connection: keep-alive",
	])

	var err := _http.request(HTTPClient.METHOD_GET, path, headers)
	if err != OK:
		_emit_error("request failed: " + str(err))
		return

	_state = State.REQUESTING


func _read_headers() -> void:
	var response_code := _http.get_response_code()
	# Handle redirects (301/302) — basic single-hop
	if response_code == 301 or response_code == 302:
		for h in _http.get_response_headers():
			if h.to_lower().begins_with("location:"):
				var redirect_url := h.substr(h.find(":") + 1).strip_edges()
				call_deferred("connect_to_stream", redirect_url)
				return

	for header in _http.get_response_headers():
		var lower := header.to_lower()
		if lower.begins_with("icy-metaint:"):
			_metaint = int(header.substr(header.find(":") + 1).strip_edges())
			_bytes_until_meta = _metaint
		elif lower.begins_with("icy-name:"):
			var station_name := header.substr(header.find(":") + 1).strip_edges()
			station_name_resolved.emit(station_name)


func _accumulate() -> void:
	if _hold:
		return

	var raw := _http.read_response_body_chunk()
	if raw.is_empty():
		return

	var audio_bytes := _strip_icy(raw)
	_buffer.append_array(audio_bytes)

	var threshold := INITIAL_CHUNK_SIZE if not _first_chunk_sent else CHUNK_SIZE
	if _buffer.size() >= threshold:
		_emit_chunk()


func resume() -> void:
	_hold = false


func _emit_chunk() -> void:
	var stream := AudioStreamMP3.new()
	stream.data = _buffer.duplicate()
	_buffer = PackedByteArray()
	_first_chunk_sent = true
	_hold = true  # pause until BoomboxInteraction calls resume()
	chunk_ready.emit(stream)


func _strip_icy(raw: PackedByteArray) -> PackedByteArray:
	if _metaint == 0:
		return raw

	var out := PackedByteArray()
	var i := 0

	while i < raw.size():
		if _in_meta:
			if not _meta_read_length:
				_meta_bytes_left = raw[i] * 16
				_meta_read_length = true
				i += 1
				if _meta_bytes_left == 0:
					_in_meta = false
					_bytes_until_meta = _metaint
			else:
				var to_skip := mini(raw.size() - i, _meta_bytes_left)
				# optionally parse StreamTitle here for now_playing_changed
				_parse_meta_bytes(raw, i, to_skip)
				i += to_skip
				_meta_bytes_left -= to_skip
				if _meta_bytes_left == 0:
					_in_meta = false
					_meta_read_length = false
					_bytes_until_meta = _metaint
		else:
			var audio_available := mini(raw.size() - i, _bytes_until_meta)
			out.append_array(raw.slice(i, i + audio_available))
			i += audio_available
			_bytes_until_meta -= audio_available
			if _bytes_until_meta == 0:
				_in_meta = true
				_meta_read_length = false

	return out


func _parse_meta_bytes(raw: PackedByteArray, offset: int, length: int) -> void:
	# Extract StreamTitle from ICY metadata for now_playing signal
	var meta_str := raw.slice(offset, offset + length).get_string_from_utf8()
	var title_start := meta_str.find("StreamTitle='")
	if title_start >= 0:
		title_start += 13
		var title_end := meta_str.find("'", title_start)
		if title_end > title_start:
			var title := meta_str.substr(title_start, title_end - title_start)
			if title.length() > 0:
				now_playing_changed.emit(title)


func _emit_error(msg: String) -> void:
	push_warning("RadioStream: " + msg)
	_state = State.ERROR
	stream_error.emit()


func _parse_url(url: String) -> Dictionary:
	var result := {"scheme": "http", "host": "", "port": 80, "path": "/"}
	var rest := url

	if rest.begins_with("https://"):
		result["scheme"] = "https"
		result["port"] = 443
		rest = rest.substr(8)
	elif rest.begins_with("http://"):
		rest = rest.substr(7)

	var path_start := rest.find("/")
	var host_part := rest
	if path_start >= 0:
		result["path"] = rest.substr(path_start)
		host_part = rest.substr(0, path_start)
	else:
		result["path"] = "/"

	var colon_pos := host_part.rfind(":")
	if colon_pos >= 0:
		result["host"] = host_part.substr(0, colon_pos)
		result["port"] = int(host_part.substr(colon_pos + 1))
	else:
		result["host"] = host_part

	return result
