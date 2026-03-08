extends Node3D

## Displays AI art critiques on a TV screen near the elevator.
## Connects to ElevatorController.export_started to cache painting metadata,
## then to GalleryUploader.upload_completed to fetch the critique.

@export var elevator_controller: ElevatorController
@onready var _sub_viewport: SubViewport = $SubViewport
@onready var _screen: MeshInstance3D = $Screen
@onready var critique_label: RichTextLabel = $SubViewport/MarginContainer/RichTextLabel
@onready var avatar_sprite: Sprite3D = $Sprite3D
@onready var dial_up_sound: AudioStreamPlayer3D = $DialUpSound

const R2_BASE_URL = "https://pub-eba211d5cf614843a0f1582ec6c62c2e.r2.dev/paintings/"
const CRITIQUE_API_URL = "https://studio-sim-gallery.vercel.app/api/critique"
const REQUEST_TIMEOUT = 30.0

enum State { IDLE, WAITING_FOR_UPLOAD, LOADING_CRITIQUE, DISPLAYING }
var _state: State = State.IDLE

var _cached_painting_id: String = ""
var _cached_painting_name: String = ""
var _cached_artist_statement: String = ""
var _cached_artist_name: String = ""

const CRITICS: Array[Dictionary] = [
	{"avatar": "res://sprites/art critics/bum.png", "type": "bum"},
	{"avatar": "res://sprites/art critics/general.png", "type": "general"},
	{"avatar": "res://sprites/art critics/govtpig.png", "type": "govtpig"},
	{"avatar": "res://sprites/art critics/guy.png", "type": "guy"},
	{"avatar": "res://sprites/art critics/woman.png", "type": "woman"},
]

var _current_critic: Dictionary = {}

var _critique_request: HTTPRequest
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

	_critique_request = HTTPRequest.new()
	_critique_request.name = "CritiqueRequest"
	_critique_request.timeout = REQUEST_TIMEOUT
	add_child(_critique_request)
	_critique_request.request_completed.connect(_on_critique_response)

	if elevator_controller:
		elevator_controller.export_started.connect(_on_export_started)
		print("CritiqueDisplay: Connected to elevator_controller")
	else:
		push_warning("CritiqueDisplay: No elevator_controller assigned!")

	GalleryUploader.upload_completed.connect(_on_upload_completed)
	GalleryUploader.upload_failed.connect(_on_upload_failed)

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

func _on_upload_completed(gallery_id: String) -> void:
	print("CritiqueDisplay: Upload completed, gallery_id=", gallery_id, " state=", _state)
	if _state != State.WAITING_FOR_UPLOAD:
		return

	# Check if the player has critique generation enabled
	var generate_critique: bool = true
	if FileAccess.file_exists("user://settings.json"):
		var sf = FileAccess.open("user://settings.json", FileAccess.READ)
		if sf:
			var sj = JSON.new()
			if sj.parse(sf.get_as_text()) == OK and typeof(sj.data) == TYPE_DICTIONARY:
				if sj.data.has("generate_npc_critique"):
					generate_critique = bool(sj.data["generate_npc_critique"])
			sf.close()

	if not generate_critique:
		_state = State.DISPLAYING
		_set_text("Nothing to see here folks!")
		return

	_state = State.LOADING_CRITIQUE
	_set_text(tr("Getting critique..."))
	dial_up_sound.play()
	_current_critic = CRITICS[randi() % CRITICS.size()]
	_request_critique(gallery_id)

func _on_upload_failed(_error_message: String) -> void:
	if _state == State.WAITING_FOR_UPLOAD or _state == State.LOADING_CRITIQUE:
		_state = State.IDLE
		_set_text(tr("Upload failed — no critique available."))

func _request_critique(gallery_id: String) -> void:
	# Cancel any in-flight request
	_critique_request.cancel_request()

	var image_url = R2_BASE_URL + gallery_id + ".png"
	var body = JSON.stringify({
		"imageUrl": image_url,
		"title": _cached_painting_name,
		"artistName": _cached_artist_name,
		"artistStatement": _cached_artist_statement,
		"locale": LocaleManager.current_locale,
		"criticType": _current_critic.get("type", "guy"),
	})
	var headers = [
		"Content-Type: application/json",
	]
	var error = _critique_request.request(CRITIQUE_API_URL, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_state = State.IDLE
		_set_text(tr("Failed to request critique."))
		push_error("CritiqueDisplay: Failed to start request: " + str(error))

func _on_critique_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_state = State.IDLE
		var err_msg: String
		if result == HTTPRequest.RESULT_TIMEOUT:
			err_msg = "The Sumerian AI Demons have been destroyed, there is no Critique for You today..."
		else:
			err_msg = "Critique unavailable.\n[result: %d, status: %d]" % [result, response_code]
		_set_text(err_msg)
		push_error("CritiqueDisplay: Request failed (result: " + str(result) + ", status: " + str(response_code) + ")")
		return

	var critique_text = body.get_string_from_utf8()
	_state = State.DISPLAYING
	_show_critic()
	_set_text(critique_text)
	if _cached_painting_id != "":
		WorldStateManager.save_critique_for_painting(_cached_painting_id, critique_text)

func _show_critic() -> void:
	if _current_critic.is_empty():
		_current_critic = CRITICS[randi() % CRITICS.size()]
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
