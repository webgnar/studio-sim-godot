extends Node

## Handles all sticker marketplace API communication.
## Listing, buying, and credit claiming are async operations driven by HTTPRequest signals.

signal marketplace_loaded(listings: Array)
signal listing_step(message: String)
signal listing_complete(listing_id: String)
signal listing_failed(error: String)
signal purchase_complete(sticker_name: String)
signal purchase_failed(error: String)
signal credits_received(amount: int)

const API_BASE = "https://studio-sim-gallery.vercel.app/api"
const API_KEY = "jupTtic3qGOULETb2w7E"
const MARKETPLACE_STICKERS_FOLDER = "user://custom_stickers/marketplace/"
const REQUEST_TIMEOUT = 30.0

var is_listing: bool = false
var is_buying: bool = false
var is_fetching: bool = false

# Pending state for multi-step listing flow
var _pending_listing_name: String = ""
var _pending_listing_price: int = 0
var _pending_listing_png_bytes: PackedByteArray
var _pending_listing_id: String = ""

# Pending state for buy flow
var _pending_buy_listing_id: String = ""
var _pending_buy_price: int = 0
var _pending_buy_png_url: String = ""
var _pending_buy_sticker_name: String = ""

var _marketplace_request: HTTPRequest
var _presign_request: HTTPRequest
var _upload_request: HTTPRequest
var _confirm_request: HTTPRequest
var _buy_request: HTTPRequest
var _download_request: HTTPRequest
var _credits_request: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_marketplace_folder()
	_marketplace_request = _make_request("MarketplaceRequest")
	_presign_request = _make_request("PresignRequest")
	_upload_request = _make_request("UploadRequest")
	_confirm_request = _make_request("ConfirmRequest")
	_buy_request = _make_request("BuyRequest")
	_download_request = _make_request("DownloadRequest")
	_credits_request = _make_request("CreditsRequest")

	_marketplace_request.request_completed.connect(_on_marketplace_loaded)
	_presign_request.request_completed.connect(_on_presign_completed)
	_upload_request.request_completed.connect(_on_upload_completed)
	_confirm_request.request_completed.connect(_on_confirm_completed)
	_buy_request.request_completed.connect(_on_buy_completed)
	_download_request.request_completed.connect(_on_download_completed)
	_credits_request.request_completed.connect(_on_credits_completed)


func _make_request(node_name: String) -> HTTPRequest:
	var req = HTTPRequest.new()
	req.name = node_name
	req.timeout = REQUEST_TIMEOUT
	add_child(req)
	return req


# ============================================================================
# Public API
# ============================================================================

func fetch_marketplace() -> void:
	if is_fetching:
		return
	is_fetching = true
	var headers = ["X-API-Key: " + API_KEY]
	_marketplace_request.request(API_BASE + "/stickers/marketplace", headers, HTTPClient.METHOD_GET)


func fetch_pending_credits() -> void:
	var player_id = WorldStateManager.get_player_id()
	var headers = ["X-API-Key: " + API_KEY]
	_credits_request.request(API_BASE + "/stickers/credits?player_id=" + player_id, headers, HTTPClient.METHOD_GET)


func list_sticker(sticker_filename: String, price: int, png_bytes: PackedByteArray) -> void:
	if is_listing:
		push_warning("StickerMarketplaceManager: Already listing a sticker")
		return
	is_listing = true
	_pending_listing_name = sticker_filename.get_basename()
	_pending_listing_price = price
	_pending_listing_png_bytes = png_bytes

	# Step 1: get presigned upload URL
	var headers = [
		"X-API-Key: " + API_KEY,
		"Content-Type: application/json",
	]
	var body = JSON.stringify({
		"name": _pending_listing_name,
		"price": price,
		"seller_id": WorldStateManager.get_player_id(),
	})
	listing_step.emit("Contacting server...")
	print("[Marketplace] Sending list request: name=%s price=%d seller=%s" % [_pending_listing_name, price, WorldStateManager.get_player_id()])
	_presign_request.request(API_BASE + "/stickers/list", headers, HTTPClient.METHOD_POST, body)


func buy_sticker(listing_id: String, price: int, png_url: String, sticker_name: String) -> void:
	if is_buying:
		push_warning("StickerMarketplaceManager: Already buying a sticker")
		return

	if not EconomyManager.can_afford(price):
		purchase_failed.emit("Not enough money")
		return

	is_buying = true
	_pending_buy_listing_id = listing_id
	_pending_buy_price = price
	_pending_buy_png_url = png_url
	_pending_buy_sticker_name = sticker_name

	EconomyManager.spend_money(price, "sticker_marketplace")

	var headers = [
		"X-API-Key: " + API_KEY,
		"Content-Type: application/json",
	]
	var body = JSON.stringify({
		"listing_id": listing_id,
		"buyer_id": WorldStateManager.get_player_id(),
	})
	_buy_request.request(API_BASE + "/stickers/buy", headers, HTTPClient.METHOD_POST, body)


# ============================================================================
# Marketplace fetch response
# ============================================================================

func _on_marketplace_loaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_fetching = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("StickerMarketplaceManager: Failed to fetch marketplace (code %d)" % response_code)
		marketplace_loaded.emit([])
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed or not parsed is Array:
		marketplace_loaded.emit([])
		return

	marketplace_loaded.emit(parsed)


# ============================================================================
# Listing flow (3 steps: presign → upload → confirm)
# ============================================================================

func _on_presign_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_str = body.get_string_from_utf8()
	print("[Marketplace] Presign response: result=%d code=%d body=%s" % [result, response_code, body_str])
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_listing_fail("Presign failed (code %d)" % response_code)
		return

	var parsed = JSON.parse_string(body_str)
	if not parsed or not parsed.has("upload_url") or not parsed.has("listing_id"):
		_listing_fail("Presign response missing fields: " + body_str)
		return

	_pending_listing_id = parsed["listing_id"]
	var upload_url = parsed["upload_url"]

	listing_step.emit("Uploading PNG (%d KB)..." % (_pending_listing_png_bytes.size() / 1024))
	print("[Marketplace] Uploading PNG to R2 (%d bytes)..." % _pending_listing_png_bytes.size())
	var headers = ["Content-Type: image/png"]
	_upload_request.request_raw(upload_url, headers, HTTPClient.METHOD_PUT, _pending_listing_png_bytes)


func _on_upload_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	print("[Marketplace] Upload response: result=%d code=%d" % [result, response_code])
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_listing_fail("PNG upload failed (code %d)" % response_code)
		return

	listing_step.emit("Saving listing to database...")
	print("[Marketplace] PNG uploaded, confirming listing %s..." % _pending_listing_id)
	var headers = [
		"X-API-Key: " + API_KEY,
		"Content-Type: application/json",
	]
	var body = JSON.stringify({"listing_id": _pending_listing_id})
	_confirm_request.request(API_BASE + "/stickers/list/confirm", headers, HTTPClient.METHOD_POST, body)


func _on_confirm_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("[Marketplace] Confirm response: result=%d code=%d body=%s" % [result, response_code, body.get_string_from_utf8()])
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_listing_fail("Listing confirm failed (code %d)" % response_code)
		return

	# Mark sticker as listed locally
	var ids = WorldStateManager.get_listed_sticker_ids()
	if _pending_listing_name not in ids:
		ids.append(_pending_listing_name)
		WorldStateManager.set_listed_sticker_ids(ids)
		WorldStateManager.save_world_state()

	StickerLibrary.reload()

	var lid = _pending_listing_id
	_reset_listing_state()
	listing_complete.emit(lid)


func _listing_fail(msg: String) -> void:
	push_error("StickerMarketplaceManager: " + msg)
	_reset_listing_state()
	listing_failed.emit(msg)


func _reset_listing_state() -> void:
	is_listing = false
	_pending_listing_name = ""
	_pending_listing_price = 0
	_pending_listing_png_bytes = PackedByteArray()
	_pending_listing_id = ""


# ============================================================================
# Buy flow (2 steps: POST buy → download PNG)
# ============================================================================

func _on_buy_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# Refund the money
		EconomyManager.add_money(_pending_buy_price, "sticker_marketplace_refund")
		_buy_fail("Buy request failed (code %d)" % response_code)
		return

	# Download the PNG
	_download_request.request(_pending_buy_png_url)


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		EconomyManager.add_money(_pending_buy_price, "sticker_marketplace_refund")
		_buy_fail("PNG download failed (code %d)" % response_code)
		return

	# Save PNG to marketplace subfolder
	_ensure_marketplace_folder()
	var filename = _pending_buy_sticker_name + ".png"
	var save_path = MARKETPLACE_STICKERS_FOLDER + filename
	var absolute_path = ProjectSettings.globalize_path(save_path)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		# Try absolute path
		file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()
	else:
		EconomyManager.add_money(_pending_buy_price, "sticker_marketplace_refund")
		_buy_fail("Failed to save sticker PNG")
		return

	StickerLibrary.reload()

	var name_copy = _pending_buy_sticker_name
	_reset_buy_state()
	purchase_complete.emit(name_copy)


func _buy_fail(msg: String) -> void:
	push_error("StickerMarketplaceManager: " + msg)
	_reset_buy_state()
	purchase_failed.emit(msg)


func _reset_buy_state() -> void:
	is_buying = false
	_pending_buy_listing_id = ""
	_pending_buy_price = 0
	_pending_buy_png_url = ""
	_pending_buy_sticker_name = ""


# ============================================================================
# Credits flow
# ============================================================================

func _on_credits_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed or not parsed is Dictionary:
		return

	var pending = int(parsed.get("pending", 0))
	if pending > 0:
		EconomyManager.add_money(pending, "sticker_sales")
		credits_received.emit(pending)

	# Remove local files for sold stickers
	var sold_ids: Array = parsed.get("sold_listing_names", [])
	if sold_ids.size() > 0:
		var listed_ids = WorldStateManager.get_listed_sticker_ids()
		var changed = false
		for sold_name in sold_ids:
			var local_path = StickerLibrary.CUSTOM_STICKERS_FOLDER + sold_name + ".png"
			if FileAccess.file_exists(local_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
			var idx = listed_ids.find(sold_name)
			if idx >= 0:
				listed_ids.remove_at(idx)
				changed = true
		if changed:
			WorldStateManager.set_listed_sticker_ids(listed_ids)
			StickerLibrary.reload()


# ============================================================================
# Helpers
# ============================================================================

func _ensure_marketplace_folder() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(MARKETPLACE_STICKERS_FOLDER)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MARKETPLACE_STICKERS_FOLDER))
