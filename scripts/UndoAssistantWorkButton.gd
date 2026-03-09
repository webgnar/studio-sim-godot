extends InteractionComponent

## Undo button in the Studio Assistant room.
## Reverts the AssistantFinishedCanvas to the state before the last "Add to Canvas" operation.
## Undo is session-only — history is lost on save/quit.

var _canvas: AssistantFinishedCanvas = null


func _ready() -> void:
	super._ready()
	_canvas = get_tree().get_first_node_in_group("assistant_canvas")
	if _canvas:
		_canvas.canvas_updated.connect(_update_interaction_text)
	_update_interaction_text()


func _on_interacted(_player: PlayerInteractionComponent) -> void:
	if not _canvas:
		return
	_canvas.undo_last_chunk()


func _update_interaction_text() -> void:
	if _canvas and _canvas.has_undo():
		interaction_text = "Undo Last Addition"
	else:
		interaction_text = "Nothing to Undo"
