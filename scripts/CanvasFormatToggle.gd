extends InteractionComponent

## Toggle button that switches between the square (3x3) and landscape (5x3) painting canvases.
## Both canvases live in the world at the same position; only one is active at a time.
## Each canvas retains its sticker state while inactive.

@export var square_canvas: Node3D
@export var landscape_canvas: Node3D
@export var painting_ui: PaintingUI

var _active_is_square: bool = true
var _click_sound: AudioStreamPlayer3D
var _click_stream: AudioStream = preload("res://sounds/picotron/closemenu.ogg")


func _ready() -> void:
	super._ready()
	_click_sound = AudioStreamPlayer3D.new()
	_click_sound.name = "ClickSound"
	_click_sound.max_distance = 15.0
	_click_sound.bus = "SFX"
	_click_sound.stream = _click_stream
	add_child(_click_sound)

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
	if painting_ui:
		painting_ui.set_active_system(system)

	_update_text()
	_click_sound.play()
	_play_button_animation()


func _play_button_animation() -> void:
	var anim_player := _find_animation_player(get_parent())
	if not anim_player:
		return
	anim_player.play("press")
	anim_player.animation_finished.connect(
		func(_name): anim_player.play("release"), CONNECT_ONE_SHOT
	)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


func _update_text() -> void:
	interaction_text = "Switch to Landscape" if _active_is_square else "Switch to Square"
