extends Node3D

## Displays AI art critiques on a TV screen near the elevator.
## Connects to ElevatorController.export_started to cache painting metadata,
## then to GalleryUploader.upload_completed to fetch the critique.

@export var elevator_controller: ElevatorController
@onready var _sub_viewport: SubViewport = $SubViewport
@onready var _screen: MeshInstance3D = $Screen
@onready var critique_label: RichTextLabel = $SubViewport/MarginContainer/RichTextLabel

const R2_BASE_URL = "https://pub-eba211d5cf614843a0f1582ec6c62c2e.r2.dev/paintings/"
const CRITIQUE_API_URL = "https://studio-sim-gallery.vercel.app/api/critique"
const REQUEST_TIMEOUT = 15.0

enum State { IDLE, WAITING_FOR_UPLOAD, LOADING_CRITIQUE, DISPLAYING }
var _state: State = State.IDLE

var _cached_painting_name: String = ""
var _cached_artist_statement: String = ""
var _cached_artist_name: String = ""

var _critique_request: HTTPRequest
var _scroll_offset: float = 0.0
var _scroll_pause_timer: float = 0.0
const SCROLL_SPEED = 10.0 # pixels per second
const SCROLL_PAUSE = 10.0 # seconds to pause at top and bottom

func _ready() -> void:
	# Set up ViewportTexture from SubViewport.get_texture() (most reliable method)
	if _screen and _sub_viewport:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = _sub_viewport.get_texture()
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

	_set_text("Awaiting next painting...")

func _process(delta: float) -> void:
	if _state != State.DISPLAYING or not critique_label:
		return

	var max_scroll = critique_label.get_v_scroll_bar().max_value - critique_label.size.y
	if max_scroll <= 0:
		return # text fits on screen, no scrolling needed

	if _scroll_pause_timer > 0:
		_scroll_pause_timer -= delta
		return

	_scroll_offset += SCROLL_SPEED * delta
	if _scroll_offset >= max_scroll:
		# Reached bottom — pause then reset to top
		_scroll_offset = 0.0
		_scroll_pause_timer = SCROLL_PAUSE
		critique_label.get_v_scroll_bar().value = 0
	else:
		critique_label.get_v_scroll_bar().value = _scroll_offset

func _on_export_started(painting: CarryablePainting) -> void:
	print("CritiqueDisplay: Export started for painting: ", painting.painting_name)
	_cached_painting_name = painting.painting_name
	_cached_artist_statement = painting.artist_statement
	_cached_artist_name = SteamManager.persona_name
	_state = State.WAITING_FOR_UPLOAD
	_set_text("Uploading painting...")

func _on_upload_completed(gallery_id: String) -> void:
	print("CritiqueDisplay: Upload completed, gallery_id=", gallery_id, " state=", _state)
	if _state != State.WAITING_FOR_UPLOAD:
		return
	_state = State.LOADING_CRITIQUE
	_set_text("Getting critique...")
	_request_critique(gallery_id)

func _on_upload_failed(_error_message: String) -> void:
	if _state == State.WAITING_FOR_UPLOAD or _state == State.LOADING_CRITIQUE:
		_state = State.IDLE
		_set_text("Upload failed — no critique available.")

func _request_critique(gallery_id: String) -> void:
	# Cancel any in-flight request
	_critique_request.cancel_request()

	var image_url = R2_BASE_URL + gallery_id + ".png"
	var body = JSON.stringify({
		"imageUrl": image_url,
		"title": _cached_painting_name,
		"artistName": _cached_artist_name,
		"artistStatement": _cached_artist_statement
	})
	var headers = [
		"Content-Type: application/json",
	]
	var error = _critique_request.request(CRITIQUE_API_URL, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_state = State.IDLE
		_set_text("Failed to request critique.")
		push_error("CritiqueDisplay: Failed to start request: " + str(error))

func _on_critique_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_state = State.IDLE
		_set_text("Critique unavailable.")
		push_error("CritiqueDisplay: Request failed (result: " + str(result) + ", status: " + str(response_code) + ")")
		return

	var critique_text = body.get_string_from_utf8()
	_state = State.DISPLAYING
	_set_text(critique_text)

func _set_text(text: String) -> void:
	if critique_label:
		critique_label.text = text
		critique_label.get_v_scroll_bar().value = 0
		_scroll_offset = 0.0
		_scroll_pause_timer = SCROLL_PAUSE
