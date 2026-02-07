extends Node

## Uploads exported paintings (PNG + GLB) to the online gallery
## Uses a 3-step presigned URL flow: get URLs → upload files → confirm

signal upload_started(png_path: String, glb_path: String)
signal upload_completed(gallery_id: String)
signal upload_failed(error_message: String)

const API_BASE_URL = "https://studio-sim-gallery.vercel.app/api"
const API_KEY = "jupTtic3qGOULETb2w7E"
const REQUEST_TIMEOUT = 30.0

var is_uploading: bool = false

# HTTPRequest nodes for each step
var _presign_request: HTTPRequest
var _image_request: HTTPRequest
var _model_request: HTTPRequest
var _confirm_request: HTTPRequest

# Current upload state
var _current_id: String = ""
var _current_png_path: String = ""
var _current_glb_path: String = ""
var _image_uploaded: bool = false
var _model_uploaded: bool = false
var _current_painting_name: String = ""
var _current_artist_statement: String = ""

func _ready() -> void:
	_presign_request = _create_http_request("PresignRequest")
	_presign_request.request_completed.connect(_on_presign_completed)

	_image_request = _create_http_request("ImageUploadRequest")
	_image_request.request_completed.connect(_on_image_upload_completed)

	_model_request = _create_http_request("ModelUploadRequest")
	_model_request.request_completed.connect(_on_model_upload_completed)

	_confirm_request = _create_http_request("ConfirmRequest")
	_confirm_request.request_completed.connect(_on_confirm_completed)

func _create_http_request(node_name: String) -> HTTPRequest:
	var req = HTTPRequest.new()
	req.name = node_name
	req.timeout = REQUEST_TIMEOUT
	add_child(req)
	return req

func upload_painting(png_path: String, glb_path: String, painting_name: String = "", artist_statement: String = "") -> void:
	if is_uploading:
		push_warning("GalleryUploader: Already uploading, skipping")
		return

	if not FileAccess.file_exists(png_path):
		push_error("GalleryUploader: PNG file not found: " + png_path)
		return

	if not FileAccess.file_exists(glb_path):
		push_error("GalleryUploader: GLB file not found: " + glb_path)
		return

	is_uploading = true
	_current_png_path = png_path
	_current_glb_path = glb_path
	_image_uploaded = false
	_model_uploaded = false
	_current_id = ""
	_current_painting_name = painting_name
	_current_artist_statement = artist_statement

	upload_started.emit(png_path, glb_path)
	print("GalleryUploader: Starting upload...")

	# Step 1: Get presigned URLs
	var headers = [
		"X-API-Key: " + API_KEY,
	]
	var error = _presign_request.request(API_BASE_URL + "/upload", headers, HTTPClient.METHOD_POST)
	if error != OK:
		_fail("Failed to start presign request: " + str(error))

func _on_presign_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("Presign request failed (result: " + str(result) + ")")
		return

	if response_code != 200:
		_fail("Presign request returned status " + str(response_code))
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json or not json is Dictionary:
		_fail("Failed to parse presign response")
		return

	_current_id = json.get("id", "")
	var image_url = json.get("imageUploadUrl", "")
	var model_url = json.get("modelUploadUrl", "")

	if _current_id.is_empty() or image_url.is_empty() or model_url.is_empty():
		_fail("Presign response missing required fields")
		return

	print("GalleryUploader: Got presigned URLs (id: " + _current_id + ")")

	# Step 2: Upload both files in parallel
	_upload_file(_current_png_path, image_url, "image/png", _image_request)
	_upload_file(_current_glb_path, model_url, "model/gltf-binary", _model_request)

func _upload_file(file_path: String, upload_url: String, content_type: String, request_node: HTTPRequest) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		_fail("Failed to open file: " + file_path)
		return

	var file_bytes = file.get_buffer(file.get_length())
	file.close()

	var headers = [
		"Content-Type: " + content_type,
	]
	var error = request_node.request_raw(upload_url, headers, HTTPClient.METHOD_PUT, file_bytes)
	if error != OK:
		_fail("Failed to start upload for " + file_path + ": " + str(error))

func _on_image_upload_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_fail("Image upload failed (result: " + str(result) + ", status: " + str(response_code) + ")")
		return

	print("GalleryUploader: PNG uploaded")
	_image_uploaded = true
	_check_uploads_complete()

func _on_model_upload_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_fail("Model upload failed (result: " + str(result) + ", status: " + str(response_code) + ")")
		return

	print("GalleryUploader: GLB uploaded")
	_model_uploaded = true
	_check_uploads_complete()

func _check_uploads_complete() -> void:
	if not _image_uploaded or not _model_uploaded:
		return

	# Step 3: Confirm upload
	print("GalleryUploader: Both files uploaded, confirming...")
	var headers = [
		"X-API-Key: " + API_KEY,
		"Content-Type: application/json",
	]
	var confirm_data = {"id": _current_id}
	if _current_painting_name != "":
		confirm_data["name"] = _current_painting_name
	if _current_artist_statement != "":
		confirm_data["artistStatement"] = _current_artist_statement
	var body = JSON.stringify(confirm_data)
	var error = _confirm_request.request(API_BASE_URL + "/upload/confirm", headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_fail("Failed to start confirm request: " + str(error))

func _on_confirm_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_fail("Confirm request failed (result: " + str(result) + ", status: " + str(response_code) + ")")
		return

	print("GalleryUploader: Upload completed! Gallery ID: " + _current_id)
	var gallery_id = _current_id
	_reset_state()
	upload_completed.emit(gallery_id)

func _fail(message: String) -> void:
	push_error("GalleryUploader: " + message)
	_reset_state()
	upload_failed.emit(message)

func _reset_state() -> void:
	is_uploading = false
	_current_id = ""
	_current_png_path = ""
	_current_glb_path = ""
	_image_uploaded = false
	_model_uploaded = false
	_current_painting_name = ""
	_current_artist_statement = ""
