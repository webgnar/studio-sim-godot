extends Node
class_name ProceduralSpeech

## Animal Crossing-style procedural speech synthesizer.
## Plays syllable samples sequentially, one per letter, with vowel emphasis and pitch variation.

const SYLLABLES: Array[AudioStream] = [
	preload("res://sounds/voice/ba.ogg"),
	preload("res://sounds/voice/da.ogg"),
	preload("res://sounds/voice/ka.ogg"),
	preload("res://sounds/voice/la.ogg"),
	preload("res://sounds/voice/ma.ogg"),
	preload("res://sounds/voice/na.ogg"),
	preload("res://sounds/voice/sa.ogg"),
	preload("res://sounds/voice/wa.ogg"),
	preload("res://sounds/voice/ya.ogg"),
]

const VOWELS := "aeiou"

## Base pitch for this NPC — modify per character personality.
## casual=1.0, pretentious=0.85, confused=1.05, enthusiastic=1.25
var base_pitch: float = 1.0

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "SFX"
	_player.volume_db = 0.0
	add_child(_player)


## Play a syllable for a single character and return how long to wait before the next character.
## Returns 0.0 for punctuation (no sound, no delay).
## Returns 0.07 for spaces (pause only, no sound).
func play_char(ch: String) -> float:
	var lower := ch.to_lower()

	if lower == " ":
		return 0.07

	if lower < "a" or lower > "z":
		return 0.0

	var index := ch.unicode_at(0) % SYLLABLES.size()
	var is_vowel := lower in VOWELS

	var pitch := base_pitch + randf_range(-0.05, 0.05)
	var duration: float
	if is_vowel:
		pitch *= randf_range(1.1, 1.2)
		duration = 0.08
	else:
		pitch *= randf_range(0.9, 1.1)
		duration = 0.04

	_player.stream = SYLLABLES[index]
	_player.pitch_scale = pitch
	_player.play()
	return duration


## Stop any in-progress speech immediately.
func stop() -> void:
	_player.stop()
