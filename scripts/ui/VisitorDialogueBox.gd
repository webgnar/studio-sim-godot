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


func _ready() -> void:
	add_to_group("visitor_dialogue_box")
	_panel.modulate.a = 0.0
	_panel.visible = false


func show_dialogue(chunks: Array[String], personality: String) -> void:
	_chunks = chunks
	_chunk_index = 0
	_open = true

	_personality_label.text = "— %s —" % personality
	_show_chunk()

	_panel.visible = true
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.15)


func advance() -> bool:
	_chunk_index += 1
	if _chunk_index >= _chunks.size():
		hide_dialogue()
		return false
	_show_chunk()
	return true


func hide_dialogue() -> void:
	_open = false
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		_panel.visible = false
		dialogue_finished.emit()
	)


func is_open() -> bool:
	return _open


func _show_chunk() -> void:
	_dialogue_label.text = _chunks[_chunk_index]
	var is_last := _chunk_index >= _chunks.size() - 1
	_continue_hint.visible = not is_last
