extends Node3D

## Displays art critiques on a TV screen near the elevator.
## Connects to ElevatorController.export_started to cache painting metadata,
## then to GalleryUploader.upload_completed to generate the critique.

@export var elevator_controller: ElevatorController
@onready var _sub_viewport: SubViewport = $SubViewport
@onready var _screen: MeshInstance3D = $Screen
@onready var critique_label: RichTextLabel = $SubViewport/MarginContainer/RichTextLabel
@onready var avatar_sprite: Sprite3D = $Sprite3D
@onready var dial_up_sound: AudioStreamPlayer3D = $DialUpSound
@onready var _pipe_generator: Node3D = $SubViewport/PipeScreensaver/PipeGenerator
@onready var _color_rect: ColorRect = $SubViewport/ColorRect

enum State { IDLE, WAITING_FOR_UPLOAD, DISPLAYING }
var _state: State = State.IDLE

var _cached_painting_id: String = ""
var _cached_painting_name: String = ""
var _cached_artist_statement: String = ""
var _cached_artist_name: String = ""
var _cached_process: Dictionary = {}

const AI_CRITIQUE_URL = "https://studio-sim-gallery.vercel.app/api/critique"
var _http_request: HTTPRequest

# --- Talking back to the critic ---
# After an AI review the player can answer once, by voice (press interact to
# record, again to send) or, if no speech comes through, by picking Agree /
# Argue / Shrug (each press cycles, it sends after a short pause). The critic
# answers in character and the exchange goes into that critic's memory.
const CRITIQUE_REPLY_URL = "https://studio-sim-gallery.vercel.app/api/critique-reply"
const TALK_MAX_RECORD_SECONDS := 20.0
const CHOICE_CONFIRM_SECONDS := 3.0
const TALK_CHOICES: Array[Dictionary] = [
	{"key": "agree", "label": "Agree", "memory": "(agreed with your review)"},
	{"key": "argue", "label": "Argue", "memory": "(argued that you got it wrong)"},
	{"key": "shrug", "label": "Shrug", "memory": "(shrugged it off)"},
]
enum Talk { NONE, READY, RECORDING, THINKING, CHOOSING, DONE }
var _talk: Talk = Talk.NONE
const CritiqueTalkBack := preload("res://scripts/CritiqueTalkBack.gd")
var _talk_body: CritiqueTalkBack
var _talk_request: HTTPRequest
var _reply_player: AudioStreamPlayer3D
var _talk_gen: int = 0 # invalidates timers and callbacks from an earlier review
var _choice_index: int = 0
var _critique_text: String = ""
var _critic_type: String = ""
var _reply_speech_gen: int = -1

const CRITICS: Array[Dictionary] = [
	{"avatar": "res://sprites/art critics/bum.png", "type": "bum"},
	{"avatar": "res://sprites/art critics/general.png", "type": "general"},
	{"avatar": "res://sprites/art critics/govtpig.png", "type": "govtpig"},
	{"avatar": "res://sprites/art critics/guy.png", "type": "guy"},
	{"avatar": "res://sprites/art critics/woman.png", "type": "woman"},
]

var _current_critic: Dictionary = {}
var _critic_bag: Array[Dictionary] = []

const CRITIC_VOICE_DESCRIPTIONS: Dictionary = {
	"bum": "a gruff, world-weary washed-up artist, rough smoker's voice, a little slurred and bitter, speaks plainly and crudely",
	"general": "a calm, mystical astrologer speaking with slow, quiet authority and an ancient, knowing tone",
	"govtpig": "a dry, monotone government bureaucrat reading a policy memo out loud, flat and administrative",
	"guy": "an overly enthusiastic young art school graduate, fast-talking and breathless with nervous excitement",
	"woman": "a heavyset, warm Southern Black woman with a slow, direct storyteller's rhythm",
}
var _voice_player: AudioStreamPlayer3D

var _scroll_offset: float = 0.0
var _scroll_pause_timer: float = 0.0
var _waiting_at_bottom: bool = false
const SCROLL_SPEED = 10.0 # pixels per second
const SCROLL_PAUSE = 10.0 # seconds to pause at top and bottom

func _ready() -> void:
	# Apply the TV shader material and feed it the SubViewport texture
	if _screen and _sub_viewport:
		var mat: ShaderMaterial = preload("res://materials/tv.tres").duplicate()
		mat.set_shader_parameter("tv_tex", _sub_viewport.get_texture())
		_screen.material_override = mat

	if elevator_controller:
		elevator_controller.export_started.connect(_on_export_started)
		print("CritiqueDisplay: Connected to elevator_controller")
	else:
		push_warning("CritiqueDisplay: No elevator_controller assigned!")

	GalleryUploader.upload_completed.connect(_on_upload_completed)
	GalleryUploader.upload_failed.connect(_on_upload_failed)

	_http_request = HTTPRequest.new()
	_http_request.timeout = 30.0
	add_child(_http_request)

	_voice_player = AudioStreamPlayer3D.new()
	_voice_player.name = "CritiqueVoicePlayer"
	_voice_player.max_distance = 6.0  # short range - player needs to be close to the TV to hear it
	_voice_player.unit_size = 1.5  # steep falloff near the source, not a gentle taper
	_voice_player.bus = "SFX"
	add_child(_voice_player)

	_setup_talk_back()

	# Pipes are always the background — ColorRect no longer needed
	_color_rect.visible = false

	# Hide the scrollbar visually but keep scroll functionality
	if critique_label:
		critique_label.get_v_scroll_bar().modulate.a = 0

	_set_text(tr("Awaiting next painting..."))

func _process(delta: float) -> void:
	if _state != State.DISPLAYING or not critique_label:
		return

	var max_scroll = critique_label.get_v_scroll_bar().max_value - critique_label.size.y
	if max_scroll <= 0:
		return # text fits on screen, no scrolling needed

	if _scroll_pause_timer > 0:
		_scroll_pause_timer -= delta
		if _scroll_pause_timer <= 0 and _waiting_at_bottom:
			# Bottom pause finished — reset to top and pause there too
			_waiting_at_bottom = false
			_scroll_offset = 0.0
			_scroll_pause_timer = SCROLL_PAUSE
			critique_label.get_v_scroll_bar().value = 0
		return

	_scroll_offset += SCROLL_SPEED * delta
	if _scroll_offset >= max_scroll:
		# Reached bottom — hold here and pause
		_scroll_offset = max_scroll
		critique_label.get_v_scroll_bar().value = max_scroll
		_waiting_at_bottom = true
		_scroll_pause_timer = SCROLL_PAUSE
	else:
		critique_label.get_v_scroll_bar().value = _scroll_offset

func _on_export_started(painting: CarryablePainting) -> void:
	print("CritiqueDisplay: Export started for painting: ", painting.painting_name)
	_cached_painting_id = painting.painting_id
	_cached_painting_name = painting.painting_name
	_cached_artist_statement = painting.artist_statement
	_cached_artist_name = SteamManager.persona_name
	_cached_process = painting.process_stats.duplicate() if "process_stats" in painting else {}
	_set_talk(Talk.NONE)
	_state = State.WAITING_FOR_UPLOAD
	_set_text(tr("Uploading painting..."))

func _on_upload_completed(_gallery_id: String, image_url: String = "") -> void:
	if _state != State.WAITING_FOR_UPLOAD:
		return

	_pipe_generator.reset()
	dial_up_sound.play()
	_current_critic = _pick_next_critic()
	var critic_type: String = _current_critic.get("type", "guy")

	var critique_text: String
	var note := ""
	if _is_generative_ai_enabled():
		var split: Array = CriticMemory.split_note(await _generate_ai_critique(critic_type, image_url))
		critique_text = split[0]
		note = split[1]
	else:
		critique_text = _generate_template_critique(critic_type)

	_state = State.DISPLAYING
	_show_critic()
	_set_text(critique_text)
	# Remember before saving the critique, which writes the save file
	CriticMemory.remember(critic_type, _cached_painting_name, critique_text, note)
	if _cached_painting_id != "":
		WorldStateManager.save_critique_for_painting(_cached_painting_id, critique_text)

	if _is_generative_ai_enabled():
		var voice_description: String = CRITIC_VOICE_DESCRIPTIONS.get(critic_type, "")
		PioneerAPI.speak_streaming(critique_text, voice_description, _voice_player)
		_critique_text = critique_text
		_critic_type = critic_type
		_set_talk(Talk.READY)

func _generate_template_critique(critic_type: String) -> String:
	return CritiqueGenerator.generate(
		critic_type,
		_cached_painting_name,
		_cached_artist_name,
		_cached_artist_statement,
		CriticMemory.times_reviewed(critic_type),
		CriticMemory.last_title(critic_type),
	)

func _generate_ai_critique(critic_type: String, image_url: String = "") -> String:
	var body := JSON.stringify({
		"imageUrl": image_url,
		"title": _cached_painting_name,
		"artistName": _cached_artist_name,
		"artistStatement": _cached_artist_statement,
		"locale": LocaleManager.current_locale,
		"criticType": critic_type,
		"memory": CriticMemory.to_request(critic_type),
		"process": _cached_process,
		"paintingsShipped": WorldStateManager.shipped_count(),
	})
	var headers := ["Content-Type: application/json"]
	var error := _http_request.request(AI_CRITIQUE_URL, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		return _generate_template_critique(critic_type)

	var result: Array = await _http_request.request_completed
	var http_result: int = result[0]
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	if http_result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return _generate_template_critique(critic_type)

	var text := response_body.get_string_from_utf8().strip_edges()
	if text == "":
		return _generate_template_critique(critic_type)
	return text

func _is_generative_ai_enabled() -> bool:
	# On by default: only an explicit false in settings turns it off
	if not FileAccess.file_exists("user://settings.json"):
		return true
	var file := FileAccess.open("user://settings.json", FileAccess.READ)
	if not file:
		return true
	var json_string := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return true
	var settings = json.data
	if typeof(settings) != TYPE_DICTIONARY:
		return true
	return bool(settings.get("generative_ai_enabled", true))

func _on_upload_failed(error_message: String) -> void:
	push_error("CritiqueDisplay: Upload failed: " + error_message)
	if _state == State.WAITING_FOR_UPLOAD:
		_state = State.IDLE
		_set_text(tr("Upload failed — no critique available."))

func _pick_next_critic() -> Dictionary:
	if _critic_bag.is_empty():
		_critic_bag = CRITICS.duplicate()
		_critic_bag.shuffle()
	return _critic_bag.pop_back()

func _show_critic() -> void:
	if _current_critic.is_empty():
		_current_critic = _pick_next_critic()
	avatar_sprite.texture = load(_current_critic["avatar"])
	avatar_sprite.visible = true

func _set_text(text: String) -> void:
	if critique_label:
		critique_label.text = text
		critique_label.get_v_scroll_bar().value = 0
		_scroll_offset = 0.0
		_scroll_pause_timer = SCROLL_PAUSE
		_waiting_at_bottom = false
	if _state != State.DISPLAYING:
		avatar_sprite.visible = false


# ============================================================================
# Talking back to the critic
# ============================================================================

func _setup_talk_back() -> void:
	_talk_request = HTTPRequest.new()
	_talk_request.timeout = 30.0
	add_child(_talk_request)

	_reply_player = AudioStreamPlayer3D.new()
	_reply_player.name = "CriticReplyPlayer"
	_reply_player.max_distance = 6.0
	_reply_player.unit_size = 1.5
	_reply_player.bus = "SFX"
	add_child(_reply_player)

	# Invisible body over the screen (it encloses the wall collider the world
	# scene puts behind the TV, so the interaction ray reaches it first).
	_talk_body = CritiqueTalkBack.new()
	_talk_body.name = "TalkBackBody"
	_talk_body.collision_layer = 8
	_talk_body.collision_mask = 0
	_talk_body.display = self
	_talk_body.add_to_group("no_outline")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 1.06, 0.26)
	shape.shape = box
	shape.position = Vector3(0.0, 0.0, -0.02)
	_talk_body.add_child(shape)
	add_child(_talk_body)
	_set_talk(Talk.NONE)


func _set_talk(state: Talk) -> void:
	_talk = state
	if state == Talk.NONE or state == Talk.READY:
		_talk_gen += 1 # a new review: drop anything still pending from the last one
	if not _talk_body:
		return
	_talk_body.set_available(state != Talk.NONE and state != Talk.DONE)
	match state:
		Talk.READY:
			_talk_body.interaction_text = tr("Talk back to the critic")
		Talk.RECORDING:
			_talk_body.interaction_text = tr("Listening... (press to send)")
		Talk.THINKING:
			_talk_body.interaction_text = tr("The critic is thinking...")
		Talk.CHOOSING:
			_talk_body.interaction_text = _choice_prompt()
		_:
			_talk_body.interaction_text = ""


func on_talk_back_pressed() -> void:
	match _talk:
		Talk.READY:
			_start_talk_recording()
		Talk.RECORDING:
			_stop_talk_recording()
		Talk.CHOOSING:
			_choice_index = (_choice_index + 1) % TALK_CHOICES.size()
			_set_talk(Talk.CHOOSING)
			_arm_choice_timer()


func _start_talk_recording() -> void:
	_set_talk(Talk.RECORDING)
	MicRecorder.start_recording()
	var gen := _talk_gen
	get_tree().create_timer(TALK_MAX_RECORD_SECONDS).timeout.connect(func() -> void:
		if gen == _talk_gen and _talk == Talk.RECORDING:
			_stop_talk_recording()
	, CONNECT_ONE_SHOT)


func _stop_talk_recording() -> void:
	var bytes: PackedByteArray = MicRecorder.stop_recording()
	if bytes.is_empty():
		_start_choosing()
		return
	_set_talk(Talk.THINKING)
	var gen := _talk_gen
	PioneerAPI.transcript_ready.connect(func(text: String) -> void:
		if gen != _talk_gen or _talk != Talk.THINKING:
			return
		if text.strip_edges().is_empty():
			_start_choosing()
		else:
			_send_talk_back(text.strip_edges(), "")
	, CONNECT_ONE_SHOT)
	PioneerAPI.transcript_failed.connect(func(_error: String) -> void:
		if gen == _talk_gen and _talk == Talk.THINKING:
			_start_choosing()
	, CONNECT_ONE_SHOT)
	PioneerAPI.transcribe(bytes)


## No speech came through (no mic, silence, or transcription failed): offer the
## three canned answers instead.
func _start_choosing() -> void:
	_choice_index = 0
	_set_talk(Talk.CHOOSING)
	_arm_choice_timer()


func _choice_prompt() -> String:
	var parts: Array[String] = []
	for i in TALK_CHOICES.size():
		var label: String = tr(TALK_CHOICES[i]["label"])
		parts.append("[%s]" % label if i == _choice_index else label)
	return "%s  %s" % [" / ".join(parts), tr("(press to change)")]


func _arm_choice_timer() -> void:
	var index := _choice_index
	var gen := _talk_gen
	get_tree().create_timer(CHOICE_CONFIRM_SECONDS).timeout.connect(func() -> void:
		if gen == _talk_gen and _talk == Talk.CHOOSING and _choice_index == index:
			var choice: Dictionary = TALK_CHOICES[index]
			_send_talk_back("", choice["key"])
	, CONNECT_ONE_SHOT)


func _send_talk_back(player_said: String, choice_key: String) -> void:
	_set_talk(Talk.THINKING)
	var gen := _talk_gen
	var critic_type := _critic_type
	var shown_said := player_said
	var memory_said := player_said
	if player_said == "":
		for c in TALK_CHOICES:
			if c["key"] == choice_key:
				shown_said = "*%s*" % tr(c["label"])
				memory_said = c["memory"]
	var body := JSON.stringify({
		"criticType": critic_type,
		"critique": _critique_text,
		"title": _cached_painting_name,
		"note": CriticMemory.get_note(critic_type),
		"locale": LocaleManager.current_locale,
		"playerSaid": player_said,
		"choice": choice_key,
	})
	var error := _talk_request.request(CRITIQUE_REPLY_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		_set_talk(Talk.DONE)
		return
	var result: Array = await _talk_request.request_completed
	if gen != _talk_gen:
		return # a new painting came in meanwhile
	var reply := ""
	var note := ""
	if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] >= 200 and result[1] < 300:
		var data = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY:
			reply = str(data.get("reply", "")).strip_edges()
			note = str(data.get("note", "")).strip_edges()
	_set_talk(Talk.DONE)
	if reply == "":
		return

	# Show the exchange under the review and jump to it
	if critique_label:
		critique_label.text = "%s\n\n%s: %s\n\n%s" % [_critique_text, tr("You"), shown_said, reply]
		await get_tree().process_frame
		_scroll_offset = maxf(0.0, critique_label.get_v_scroll_bar().max_value - critique_label.size.y)
		critique_label.get_v_scroll_bar().value = _scroll_offset
		_scroll_pause_timer = SCROLL_PAUSE * 2.0 # hold the answer on screen a while
		_waiting_at_bottom = true

	CriticMemory.remember_exchange(critic_type, memory_said, reply, note)
	WorldStateManager.save_world_state()
	_speak_reply(reply, critic_type, gen)


## Speaks the critic's answer once the review itself has finished playing.
func _speak_reply(reply: String, critic_type: String, gen: int) -> void:
	var waited := 0.0
	while PioneerAPI._stream_state != "idle" and waited < 90.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if gen != _talk_gen:
		return
	_reply_speech_gen = gen
	if not PioneerAPI.speech_ready.is_connected(_on_reply_speech_ready):
		PioneerAPI.speech_ready.connect(_on_reply_speech_ready, CONNECT_ONE_SHOT)
	if not PioneerAPI.speech_failed.is_connected(_on_reply_speech_failed):
		PioneerAPI.speech_failed.connect(_on_reply_speech_failed, CONNECT_ONE_SHOT)
	PioneerAPI.speak(reply, CRITIC_VOICE_DESCRIPTIONS.get(critic_type, ""))


func _on_reply_speech_ready(stream: AudioStream) -> void:
	if PioneerAPI.speech_failed.is_connected(_on_reply_speech_failed):
		PioneerAPI.speech_failed.disconnect(_on_reply_speech_failed)
	if _reply_speech_gen == _talk_gen:
		_reply_player.stream = stream
		_reply_player.play()


func _on_reply_speech_failed(error: String) -> void:
	if PioneerAPI.speech_ready.is_connected(_on_reply_speech_ready):
		PioneerAPI.speech_ready.disconnect(_on_reply_speech_ready)
	push_warning("CritiqueDisplay: critic reply speech failed: %s" % error)

