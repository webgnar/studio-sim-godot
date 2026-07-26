extends StaticBody3D

## Lets the player have a spoken conversation with the Studio Assistant NPC:
## press interact to start recording, press again to stop - that recording is
## queued for transcribe -> generate reply -> speak, processed one at a time
## in order. Voice-only - no on-screen caption box (status/errors surface
## briefly through the interaction prompt text instead).
##
## Recording is independent of reply processing: the player can start a new
## recording immediately after stopping the previous one, even while earlier
## messages are still being transcribed/replied to/spoken - those queue up
## and get answered in order rather than being dropped.

const ASSISTANT_CHAT_URL := "https://studio-sim-gallery.vercel.app/api/assistant-chat"
const VOICE_DESCRIPTION := "a friendly, upbeat male studio assistant"
const IDLE_TEXT := "Talk to Assistant"
const STATUS_MESSAGE_DURATION := 2.0
## Vercel Functions cap request bodies at 4.5MB, and 16-bit/48kHz mono WAV runs
## ~93.75 KB/sec, so anything longer than ~47s risks a 413 from /api/voice/stt
## before it even reaches Pioneer. Capping well under that.
const MAX_RECORDING_SECONDS := 30.0
## How often the floating "..." indicator's dot count advances while thinking.
const THINKING_DOT_INTERVAL := 0.4

## Exposed so PlayerInteractionComponent can show a prompt label.
var interaction_text: String = IDLE_TEXT

var _is_recording: bool = false
var _is_processing_queue: bool = false
var _pending_audio_queue: Array[PackedByteArray] = []
var _http_request: HTTPRequest
var _voice_player: AudioStreamPlayer3D
var _status_message_gen: int = 0

## Floating billboarded label above the NPC's head, visible across the room,
## so the player doesn't need to be looking directly at the crosshair prompt
## to tell a reply is being generated.
var _thinking_indicator: Label3D
var _thinking_dot_timer: float = 0.0
var _thinking_dot_count: int = 0

func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 15.0
	add_child(_http_request)

	_voice_player = AudioStreamPlayer3D.new()
	_voice_player.name = "VoicePlayer"
	_voice_player.max_distance = 15.0
	_voice_player.bus = "SFX"
	add_child(_voice_player)

	_thinking_indicator = get_node_or_null("ThinkingIndicator")

func _process(delta: float) -> void:
	if not _is_processing_queue or not _thinking_indicator:
		return
	_thinking_dot_timer += delta
	if _thinking_dot_timer >= THINKING_DOT_INTERVAL:
		_thinking_dot_timer = 0.0
		_thinking_dot_count = (_thinking_dot_count % 3) + 1
		_thinking_indicator.text = ".".repeat(_thinking_dot_count)

func interact(_player: Node) -> void:
	if not _is_generative_ai_enabled():
		_show_status_message("Turn on Generative AI Dialogue in Options to talk to me.")
		return

	if _is_recording:
		_stop_recording_and_enqueue()
	else:
		_start_recording()

func _start_recording() -> void:
	_is_recording = true
	MicRecorder.start_recording()
	_refresh_status_text()
	get_tree().create_timer(MAX_RECORDING_SECONDS).timeout.connect(func() -> void:
		if _is_recording:
			_stop_recording_and_enqueue()
	, CONNECT_ONE_SHOT)

func _stop_recording_and_enqueue() -> void:
	_is_recording = false
	var bytes := MicRecorder.stop_recording()
	if bytes.is_empty():
		_refresh_status_text()
		_show_status_message("Didn't catch that - try again.")
		return

	_pending_audio_queue.append(bytes)
	_refresh_status_text()
	if not _is_processing_queue:
		_is_processing_queue = true
		_thinking_dot_timer = 0.0
		_thinking_dot_count = 0
		_process_next_in_queue()

func _process_next_in_queue() -> void:
	if _pending_audio_queue.is_empty():
		_is_processing_queue = false
		if _thinking_indicator:
			_thinking_indicator.visible = false
		_refresh_status_text()
		return

	var bytes: PackedByteArray = _pending_audio_queue.pop_front()
	if _thinking_indicator:
		_thinking_indicator.visible = true
	_refresh_status_text()

	if not PioneerAPI.transcript_ready.is_connected(_on_transcript_ready):
		PioneerAPI.transcript_ready.connect(_on_transcript_ready, CONNECT_ONE_SHOT)
	if not PioneerAPI.transcript_failed.is_connected(_on_transcript_failed):
		PioneerAPI.transcript_failed.connect(_on_transcript_failed, CONNECT_ONE_SHOT)
	PioneerAPI.transcribe(bytes)

func _on_transcript_ready(text: String) -> void:
	if text.is_empty():
		_show_status_message("Didn't catch that - try again.", _process_next_in_queue)
		return
	_fetch_reply(text)

func _on_transcript_failed(error: String) -> void:
	push_warning("StudioAssistantVoiceChat: transcription failed: %s" % error)
	_show_status_message("Couldn't hear you - try again.", _process_next_in_queue)

func _fetch_reply(message: String) -> void:
	var body := JSON.stringify({
		"message": message,
		"locale": LocaleManager.current_locale,
		"assistantHired": has_node("/root/AutomationManager") and AutomationManager.is_assistant_active(),
		"hasPsywheel": has_node("/root/WorldStateManager") and WorldStateManager.get_purchased_items().has("psywheel"),
		"playerName": SteamManager.persona_name if has_node("/root/SteamManager") else "",
		"money": EconomyManager.get_money() if has_node("/root/EconomyManager") else 0,
		"reputationLevel": ReputationManager.get_reputation_level() if has_node("/root/ReputationManager") else 0,
		"missionsCompleted": _count_missions_completed(),
		"totalMissions": MissionManager.available_missions.size() if has_node("/root/MissionManager") else 0,
		"paintingsShipped": _count_paintings_shipped(),
		"galleryVisitorCount": WorldStateManager.get_gallery_visitor_count() if has_node("/root/WorldStateManager") else 0,
	})
	var headers := ["Content-Type: application/json", "x-api-key: " + GalleryUploader.API_KEY]
	var error := _http_request.request(ASSISTANT_CHAT_URL, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_show_status_message("Couldn't reach the studio backend.", _process_next_in_queue)
		return

	var result: Array = await _http_request.request_completed
	var reply := _parse_reply(result)
	if reply.is_empty():
		_show_status_message("...", _process_next_in_queue)
		return
	_show_reply(reply)

func _count_missions_completed() -> int:
	if not has_node("/root/MissionManager"):
		return 0
	var count := 0
	for entry in MissionManager.progression.values():
		if typeof(entry) == TYPE_DICTIONARY and entry.get("completed", false):
			count += 1
	return count

func _count_paintings_shipped() -> int:
	if not has_node("/root/WorldStateManager"):
		return 0
	var count := 0
	for painting in WorldStateManager.get_all_paintings():
		if typeof(painting) == TYPE_DICTIONARY and painting.get("status", "") == "SHIPPED":
			count += 1
	return count

func _parse_reply(result: Array) -> String:
	var http_result: int = result[0]
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	if http_result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return ""

	var json := JSON.new()
	if json.parse(response_body.get_string_from_utf8()) != OK:
		return ""
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	return str(data.get("reply", "")).strip_edges()

func _show_reply(reply: String) -> void:
	if reply.findn("fuck") != -1 and has_node("/root/SteamManager"):
		SteamManager.unlock_achievement("ACH_MADE_ZACK_SWEAR")

	if not PioneerAPI.speech_ready.is_connected(_on_speech_ready):
		PioneerAPI.speech_ready.connect(_on_speech_ready, CONNECT_ONE_SHOT)
	if not PioneerAPI.speech_failed.is_connected(_on_speech_failed):
		PioneerAPI.speech_failed.connect(_on_speech_failed, CONNECT_ONE_SHOT)
	PioneerAPI.speak(reply, VOICE_DESCRIPTION)

func _on_speech_ready(stream: AudioStream) -> void:
	if _thinking_indicator:
		_thinking_indicator.visible = false
	_voice_player.stream = stream
	_voice_player.play()
	_refresh_status_text()
	if not _voice_player.finished.is_connected(_on_voice_finished):
		_voice_player.finished.connect(_on_voice_finished, CONNECT_ONE_SHOT)

func _on_speech_failed(error: String) -> void:
	push_warning("StudioAssistantVoiceChat: speech failed: %s" % error)
	_process_next_in_queue()

func _on_voice_finished() -> void:
	_process_next_in_queue()

func _refresh_status_text() -> void:
	if _is_recording:
		interaction_text = "Listening... (press to stop)"
	elif _is_processing_queue:
		var queued := _pending_audio_queue.size()
		interaction_text = "Thinking... (%d queued)" % queued if queued > 0 else "Thinking..."
	else:
		interaction_text = IDLE_TEXT

## Shows a transient message in the interaction prompt. If `then` is given,
## it's called after STATUS_MESSAGE_DURATION instead of resetting to idle -
## used to keep a mid-queue error visible for a moment before advancing to
## the next queued message (calling `then` immediately, before the message
## had time to display, would make it flash for less than a frame).
func _show_status_message(message: String, then: Callable = Callable()) -> void:
	if message.is_empty():
		if then.is_valid():
			then.call()
		return
	interaction_text = message
	_status_message_gen += 1
	var my_gen := _status_message_gen
	get_tree().create_timer(STATUS_MESSAGE_DURATION).timeout.connect(func() -> void:
		if then.is_valid():
			then.call()
		elif my_gen == _status_message_gen and not _is_recording and not _is_processing_queue:
			interaction_text = IDLE_TEXT
	, CONNECT_ONE_SHOT)

func _is_generative_ai_enabled() -> bool:
	if not FileAccess.file_exists("user://settings.json"):
		return false
	var file := FileAccess.open("user://settings.json", FileAccess.READ)
	if not file:
		return false
	var json_string := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return false
	var settings = json.data
	if typeof(settings) != TYPE_DICTIONARY:
		return false
	return bool(settings.get("generative_ai_enabled", false))
