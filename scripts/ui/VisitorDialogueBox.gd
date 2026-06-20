extends CanvasLayer
class_name VisitorDialogueBox

## Bottom-screen dialogue box for gallery visitor conversations.
## Place one instance in the scene. Visitors find it via the "visitor_dialogue_box" group.

signal dialogue_finished

@onready var _panel: PanelContainer = $Control/PanelContainer
@onready var _personality_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/PersonalityLabel
@onready var _dialogue_label: RichTextLabel = $Control/PanelContainer/MarginContainer/VBoxContainer/DialogueLabel
@onready var _continue_hint: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/HintContainer/ContinueHint

var _chunks: Array[String] = []
var _chunk_index: int = 0
var _open: bool = false
var _typewriter_active: bool = false
var _typewriter_gen: int = 0
var _speech: ProceduralSpeech

const PUNCTUATION_DELAY := 0.02

const PERSONALITY_PITCH := {
	"casual": 1.0,
	"pretentious": 0.85,
	"confused": 1.05,
	"enthusiastic": 1.25,
	"streetwise": 1.1,
	"spiritual": 0.92,
	"fabulous": 1.15,
	"conspiracist": 1.08,
	"agent": 0.88,
}


func _ready() -> void:
	add_to_group("visitor_dialogue_box")
	_panel.modulate.a = 0.0
	_panel.visible = false
	_speech = ProceduralSpeech.new()
	add_child(_speech)


func show_dialogue(chunks: Array[String], personality: String, display_name: String = "") -> void:
	_stop_speech_and_typewriter()
	_chunks = chunks
	_chunk_index = 0
	_open = true

	_speech.base_pitch = PERSONALITY_PITCH.get(personality, 1.0)
	_personality_label.text = "— %s —" % (display_name if display_name != "" else personality)
	_show_chunk()

	_panel.visible = true
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.15)


func advance() -> bool:
	if _typewriter_active:
		_stop_speech_and_typewriter()
		_dialogue_label.visible_characters = -1
		return true

	_chunk_index += 1
	if _chunk_index >= _chunks.size():
		hide_dialogue()
		return false
	_show_chunk()
	return true


func hide_dialogue() -> void:
	_stop_speech_and_typewriter()
	_open = false
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		_panel.visible = false
		dialogue_finished.emit()
	)


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("interact"):
		advance()
		get_viewport().set_input_as_handled()


func _show_chunk() -> void:
	var chunk := _chunks[_chunk_index]
	var is_last := _chunk_index >= _chunks.size() - 1
	_continue_hint.visible = not is_last
	_typewrite_chunk(chunk)


func _stop_speech_and_typewriter() -> void:
	_typewriter_active = false
	_speech.stop()


func _typewrite_chunk(text: String) -> void:
	_typewriter_active = true
	_typewriter_gen += 1
	var my_gen := _typewriter_gen
	_dialogue_label.text = text
	_dialogue_label.visible_characters = 0

	for ch in text:
		if not _typewriter_active or _typewriter_gen != my_gen:
			return
		_dialogue_label.visible_characters += 1
		var wait := _speech.play_char(ch)
		if wait <= 0.0:
			wait = PUNCTUATION_DELAY
		await get_tree().create_timer(wait).timeout

	if _typewriter_active and _typewriter_gen == my_gen:
		_dialogue_label.visible_characters = -1
