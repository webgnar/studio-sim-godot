@tool
extends Node3D

## Displays the gallery's last Instagram posts as a live slideshow on a 3D screen.
## Fetches post metadata from the backend, then downloads each image directly from
## Instagram's CDN. Refreshes every FETCH_INTERVAL seconds.
## @tool lets the SubViewport preview render on the screen mesh in the editor.

@onready var _sub_viewport: SubViewport = $SubViewport
@onready var _screen: MeshInstance3D = $Screen
@onready var _post_image: TextureRect = $SubViewport/PostImage
@onready var _caption_label: RichTextLabel = $SubViewport/OverlayContainer/MarginContainer/VBoxContainer/CaptionLabel
@onready var _meta_label: Label = $SubViewport/OverlayContainer/MarginContainer/VBoxContainer/MetaLabel
@onready var _status_label: Label = $SubViewport/StatusLabel

const INSTAGRAM_FEED_URL = "https://studio-sim-gallery.vercel.app/api/instagram-feed"
const API_KEY = "jupTtic3qGOULETb2w7E"
const MAX_POSTS = 10
const SLIDE_DURATION = 6.0
const FETCH_INTERVAL = 300.0
const REQUEST_TIMEOUT = 30.0

var _posts: Array[Dictionary] = []
var _textures: Array = []  # Array of ImageTexture or null
var _current_index: int = 0
var _slide_timer: float = 0.0
var _fetch_timer: float = 0.0
var _is_ready: bool = false

var _feed_request: HTTPRequest
var _image_requests: Array[HTTPRequest] = []


func _ready() -> void:
	# Apply TV shader — runs in both editor and game so the SubViewport is visible
	if _screen and _sub_viewport:
		var mat: ShaderMaterial = preload("res://materials/tv.tres").duplicate()
		mat.set_shader_parameter("tv_tex", _sub_viewport.get_texture())
		_screen.material_override = mat

	if Engine.is_editor_hint():
		return  # Skip HTTP and signals in the editor

	# Feed request
	_feed_request = HTTPRequest.new()
	_feed_request.name = "FeedRequest"
	_feed_request.timeout = REQUEST_TIMEOUT
	add_child(_feed_request)
	_feed_request.request_completed.connect(_on_feed_response)

	# One HTTPRequest per post slot
	for i in MAX_POSTS:
		var req := HTTPRequest.new()
		req.name = "ImageRequest%d" % i
		req.timeout = REQUEST_TIMEOUT
		add_child(req)
		req.request_completed.connect(_on_image_response.bind(i))
		_image_requests.append(req)
		_textures.append(null)

	_set_status("Loading feed...")
	_fetch_feed()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _is_ready or _posts.is_empty():
		return

	_slide_timer -= delta
	if _slide_timer <= 0.0:
		_advance_slide()

	_fetch_timer -= delta
	if _fetch_timer <= 0.0:
		_fetch_timer = FETCH_INTERVAL
		_fetch_feed()


func _fetch_feed() -> void:
	_feed_request.cancel_request()
	var headers = [
		"Content-Type: application/json",
		"X-API-Key: " + API_KEY,
	]
	var err := _feed_request.request(INSTAGRAM_FEED_URL, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_set_status("Feed unavailable.")
		push_error("InstagramDisplay: Failed to start feed request: " + str(err))


func _on_feed_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_status("Feed unavailable.")
		push_error("InstagramDisplay: Feed request failed (result: %d, status: %d)" % [result, response_code])
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_set_status("Feed unavailable.")
		push_error("InstagramDisplay: Failed to parse feed JSON")
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY or not data.has("posts"):
		_set_status("No posts found.")
		return

	_posts = []
	for post in data["posts"]:
		if typeof(post) == TYPE_DICTIONARY:
			_posts.append(post)

	if _posts.is_empty():
		_set_status("No posts found.")
		return

	print("InstagramDisplay: received %d posts from backend" % _posts.size())

	# Reset textures for new fetch
	for i in MAX_POSTS:
		_textures[i] = null

	# Download all images in parallel
	for i in _posts.size():
		_download_image(i)

	_is_ready = true
	_current_index = 0
	_slide_timer = SLIDE_DURATION
	_fetch_timer = FETCH_INTERVAL
	_show_post(0)


func _download_image(i: int) -> void:
	if i >= _posts.size() or i >= _image_requests.size():
		return
	var image_url: String = _posts[i].get("imageUrl", "")
	if image_url.is_empty():
		return
	_image_requests[i].cancel_request()
	var err := _image_requests[i].request(image_url)
	if err != OK:
		push_error("InstagramDisplay: Failed to start image request %d: %s" % [i, str(err)])


func _on_image_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, slot: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_error("InstagramDisplay: Image %d download failed (result: %d, status: %d)" % [slot, result, response_code])
		return

	var image := Image.new()
	# Instagram serves JPEG via CDN
	var load_err := image.load_jpg_from_buffer(body)
	if load_err != OK:
		# Fallback: try PNG
		load_err = image.load_png_from_buffer(body)
	if load_err != OK:
		push_error("InstagramDisplay: Failed to decode image %d" % slot)
		return

	_textures[slot] = ImageTexture.create_from_image(image)

	# If this is the currently displayed slot, refresh immediately
	if slot == _current_index:
		_show_post(_current_index)


func _advance_slide() -> void:
	if _posts.is_empty():
		return
	_current_index = (_current_index + 1) % _posts.size()
	_slide_timer = SLIDE_DURATION
	_show_post(_current_index)


func _show_post(i: int) -> void:
	if _posts.is_empty() or i >= _posts.size():
		return

	# Image
	var tex = _textures[i] if i < _textures.size() else null
	if tex:
		_post_image.texture = tex
		_post_image.visible = true
		_status_label.visible = false
	else:
		_post_image.visible = false
		_status_label.visible = true
		_status_label.text = "Loading..."

	# Caption
	var caption: String = _posts[i].get("caption", "")
	if caption.length() > 120:
		caption = caption.left(117) + "..."
	_caption_label.text = caption

	# Likes + counter
	var likes: int = _posts[i].get("likes", -1)
	var likes_str := "♥ %d" % likes if likes >= 0 else ""
	_meta_label.text = "%s   %d / %d" % [likes_str, i + 1, _posts.size()]


func _set_status(text: String) -> void:
	_post_image.visible = false
	_status_label.visible = true
	_status_label.text = text
	_caption_label.text = ""
	_meta_label.text = ""
