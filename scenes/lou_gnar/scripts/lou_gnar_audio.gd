class_name LouGnarAudio
extends Node
## Music + one-voice-per-effect SFX (same behaviour as audio-manager.ts).
## Plays on the project's "SFX"/"Music" buses when they exist, else "Master".
## While `enabled` is false nothing is audible; the wanted music is remembered
## and resumes when re-enabled.

const MUSIC_VOLUME := {"title": 0.4, "gameplay": 0.5}
const SFX_VOLUME := {
	"ollie": 0.8, "trick": 0.4, "impact": 0.9, "grind": 0.5,
	"die": 0.8, "coinCollect": 0.6, "ufoExplode": 1.0, "gameStart": 1.0,
}

var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		if not is_node_ready():
			return
		if enabled:
			if _wanted_music != "":
				play_music(_wanted_music)
		else:
			_stop_everything()

var _sfx: Dictionary = {}
var _music: AudioStreamPlayer
var _wanted_music: String = ""


func _ready() -> void:
	var streams := {
		"ollie": LouGnarAssets.SFX_OLLIE, "trick": LouGnarAssets.SFX_TRICK,
		"impact": LouGnarAssets.SFX_IMPACT, "grind": LouGnarAssets.SFX_GRIND,
		"die": LouGnarAssets.SFX_DIE, "coinCollect": LouGnarAssets.SFX_COIN,
		"ufoExplode": LouGnarAssets.SFX_UFO_EXPLODE, "gameStart": LouGnarAssets.SFX_GAME_START,
	}
	for key: String in streams:
		var player := AudioStreamPlayer.new()
		player.stream = streams[key]
		player.bus = _bus("SFX")
		add_child(player)
		_sfx[key] = player
	_music = AudioStreamPlayer.new()
	_music.bus = _bus("Music")
	add_child(_music)
	(LouGnarAssets.MUSIC_TITLE as AudioStreamOggVorbis).loop = true
	(LouGnarAssets.MUSIC_GAMEPLAY as AudioStreamOggVorbis).loop = true


func play_music(kind: String) -> void:
	_wanted_music = kind
	if not enabled:
		return
	_music.stream = LouGnarAssets.MUSIC_TITLE if kind == "title" else LouGnarAssets.MUSIC_GAMEPLAY
	_music.volume_db = linear_to_db(MUSIC_VOLUME[kind])
	_music.play()


func stop_music() -> void:
	_wanted_music = ""
	_music.stop()


## `volume` is linear 0..1; negative uses the preset for that effect.
func play_sfx(sfx_name: String, volume: float = -1.0) -> void:
	if not enabled or not _sfx.has(sfx_name):
		return
	var player: AudioStreamPlayer = _sfx[sfx_name]
	var v: float = SFX_VOLUME[sfx_name] if volume < 0.0 else clampf(volume, 0.0, 1.0)
	player.volume_db = linear_to_db(v)
	player.play()


func stop_sfx(sfx_name: String) -> void:
	if _sfx.has(sfx_name):
		(_sfx[sfx_name] as AudioStreamPlayer).stop()


func stop_all() -> void:
	stop_music()
	for player: AudioStreamPlayer in _sfx.values():
		player.stop()


func _stop_everything() -> void:
	_music.stop()
	for player: AudioStreamPlayer in _sfx.values():
		player.stop()


static func _bus(bus_name: String) -> String:
	return bus_name if AudioServer.get_bus_index(bus_name) != -1 else "Master"
