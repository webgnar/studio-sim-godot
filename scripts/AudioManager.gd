extends Node

## AudioManager - Singleton for managing audio bus volumes and settings

# Default volume levels (in dB) - adjust these for testing
const DEFAULT_SFX_VOLUME: float = 0.0  # 0 dB = full volume
const DEFAULT_MUSIC_VOLUME: float = 0.0  # 0 dB = full volume

# Audio bus indices
var sfx_bus_index: int = -1
var music_bus_index: int = -1

# Current volume levels (0-100 for UI sliders)
var sfx_volume: float = 100.0
var music_volume: float = 100.0
var painting_sounds_enabled: bool = true

func _ready():
	# Get audio bus indices
	sfx_bus_index = AudioServer.get_bus_index("SFX")
	music_bus_index = AudioServer.get_bus_index("Music")
	
	if sfx_bus_index == -1:
		push_error("AudioManager: SFX bus not found!")
	if music_bus_index == -1:
		push_error("AudioManager: Music bus not found!")
	
	# Load settings from disk
	load_settings()
	
	# Apply loaded volumes to audio buses
	apply_sfx_volume()
	apply_music_volume()

func set_sfx_volume(value: float) -> void:
	"""Set SFX volume (0-100)"""
	sfx_volume = clamp(value, 0.0, 100.0)
	apply_sfx_volume()

func set_music_volume(value: float) -> void:
	"""Set Music volume (0-100)"""
	music_volume = clamp(value, 0.0, 100.0)
	apply_music_volume()

func apply_sfx_volume() -> void:
	"""Apply SFX volume to audio bus"""
	if sfx_bus_index != -1:
		var db = linear_to_db(sfx_volume / 100.0)
		AudioServer.set_bus_volume_db(sfx_bus_index, db)

func apply_music_volume() -> void:
	"""Apply Music volume to audio bus"""
	if music_bus_index != -1:
		var db = linear_to_db(music_volume / 100.0)
		AudioServer.set_bus_volume_db(music_bus_index, db)

func linear_to_db(linear: float) -> float:
	"""Convert linear volume (0-1) to decibels"""
	if linear <= 0.0:
		return -80.0  # Mute
	return 20.0 * log(linear) / log(10.0)

func save_settings() -> void:
	"""Save audio settings to disk"""
	var settings = {
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"painting_sounds": painting_sounds_enabled
	}
	
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()
		print("AudioManager: Settings saved")
	else:
		push_error("AudioManager: Failed to save settings")

func load_settings() -> void:
	"""Load audio settings from disk"""
	if not FileAccess.file_exists("user://settings.json"):
		# Use defaults
		sfx_volume = db_to_linear(DEFAULT_SFX_VOLUME) * 100.0
		music_volume = db_to_linear(DEFAULT_MUSIC_VOLUME) * 100.0
		print("AudioManager: No settings file found, using defaults")
		return
	
	var file = FileAccess.open("user://settings.json", FileAccess.READ)
	if not file:
		push_error("AudioManager: Failed to open settings file")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("AudioManager: Failed to parse settings JSON")
		return
	
	var settings = json.data
	if typeof(settings) != TYPE_DICTIONARY:
		push_error("AudioManager: Settings is not a dictionary")
		return
	
	# Load volume settings
	if settings.has("sfx_volume"):
		sfx_volume = float(settings.sfx_volume)
	else:
		sfx_volume = db_to_linear(DEFAULT_SFX_VOLUME) * 100.0
	
	if settings.has("music_volume"):
		music_volume = float(settings.music_volume)
	else:
		music_volume = db_to_linear(DEFAULT_MUSIC_VOLUME) * 100.0

	if settings.has("painting_sounds"):
		painting_sounds_enabled = bool(settings["painting_sounds"])

	print("AudioManager: Settings loaded - SFX: %s, Music: %s" % [sfx_volume, music_volume])

func db_to_linear(db: float) -> float:
	"""Convert decibels to linear volume (0-1)"""
	if db <= -80.0:
		return 0.0
	return pow(10.0, db / 20.0)
