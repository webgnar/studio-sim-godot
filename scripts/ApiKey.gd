class_name ApiKey
extends RefCounted

## Loads the gallery server key (studio-sim-gallery, checked there as
## UPLOAD_API_KEY) from a local file that is NOT committed to git.
##
## The file is res://data/api_key.json:   {"api_key": "..."}
## Copy data/api_key.example.json to data/api_key.json and put the real key in.
## Exports pick it up through each preset's include_filter (export_presets.cfg).
##
## If the file is missing or empty, the game prints one warning and keeps
## running: online features (gallery upload, sticker market, voice, visitor
## chat, fortune teller...) just get "unauthorized" back and fail quietly.

const KEY_PATH := "res://data/api_key.json"

static var _key: String = ""
static var _loaded: bool = false


## The key to send as the X-API-Key header. Empty string if not configured.
static func get_key() -> String:
	if not _loaded:
		_loaded = true
		_key = _read_key()
		if _key == "":
			push_warning("ApiKey: no server key found at %s. Online features will be unavailable. Copy data/api_key.example.json to data/api_key.json and fill in api_key." % KEY_PATH)
	return _key


static func has_key() -> bool:
	return get_key() != ""


static func _read_key() -> String:
	if not FileAccess.file_exists(KEY_PATH):
		return ""
	var text := FileAccess.get_file_as_string(KEY_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("ApiKey: %s is not valid JSON." % KEY_PATH)
		return ""
	return str(data.get("api_key", "")).strip_edges()
