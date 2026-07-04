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

const AI_CRITIQUE_URL = "https://studio-sim-gallery.vercel.app/api/critique"
var _http_request: HTTPRequest

const CRITICS: Array[Dictionary] = [
	{"avatar": "res://sprites/art critics/bum.png", "type": "bum"},
	{"avatar": "res://sprites/art critics/general.png", "type": "general"},
	{"avatar": "res://sprites/art critics/govtpig.png", "type": "govtpig"},
	{"avatar": "res://sprites/art critics/guy.png", "type": "guy"},
	{"avatar": "res://sprites/art critics/woman.png", "type": "woman"},
]

var _current_critic: Dictionary = {}
var _critic_bag: Array[Dictionary] = []

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
	_http_request.timeout = 10.0
	add_child(_http_request)

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
	if _is_generative_ai_enabled():
		critique_text = await _generate_ai_critique(critic_type, image_url)
	else:
		critique_text = _generate_template_critique(critic_type)

	_state = State.DISPLAYING
	_show_critic()
	_set_text(critique_text)
	if _cached_painting_id != "":
		WorldStateManager.save_critique_for_painting(_cached_painting_id, critique_text)

func _generate_template_critique(critic_type: String) -> String:
	return CritiqueGenerator.generate(
		critic_type,
		_cached_painting_name,
		_cached_artist_name,
		_cached_artist_statement,
	)

func _generate_ai_critique(critic_type: String, image_url: String = "") -> String:
	var body := JSON.stringify({
		"imageUrl": image_url,
		"title": _cached_painting_name,
		"artistName": _cached_artist_name,
		"artistStatement": _cached_artist_statement,
		"locale": LocaleManager.current_locale,
		"criticType": critic_type,
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
