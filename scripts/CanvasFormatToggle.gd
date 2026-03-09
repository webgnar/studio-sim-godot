extends InteractionComponent

## Toggle button that switches between the square (3x3) and landscape (5x3) painting canvases.
## Both canvases live in the world at the same position; only one is active at a time.
## Each canvas retains its sticker state while inactive.

@export var square_canvas: Node3D
@export var landscape_canvas: Node3D

var _active_is_square: bool = true


func _ready() -> void:
	super._ready()
	if not square_canvas or not landscape_canvas:
		push_warning("CanvasFormatToggle: canvas exports not configured yet.")
		return
	# Landscape starts hidden and disabled
	landscape_canvas.visible = false
	landscape_canvas.process_mode = Node.PROCESS_MODE_DISABLED
	_update_text()


func _on_interacted(_player: PlayerInteractionComponent) -> void:
	if not square_canvas or not landscape_canvas:
		push_warning("CanvasFormatToggle: canvas exports not configured.")
		return
	_active_is_square = not _active_is_square

	square_canvas.visible = _active_is_square
	square_canvas.process_mode = Node.PROCESS_MODE_INHERIT if _active_is_square else Node.PROCESS_MODE_DISABLED

	landscape_canvas.visible = not _active_is_square
	landscape_canvas.process_mode = Node.PROCESS_MODE_INHERIT if not _active_is_square else Node.PROCESS_MODE_DISABLED

	var active := square_canvas if _active_is_square else landscape_canvas
	var system: PaintingSystem2D = active.get_node("CanvasViewport/CanvasRoot")
	PaintingModeManager.register_2d_system(system, active)

	_update_text()


func _update_text() -> void:
	interaction_text = "Switch to 5×3" if _active_is_square else "Switch to Square"
