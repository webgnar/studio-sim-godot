extends InteractionComponent

## Toggle button that switches between the square (3x3) and landscape (5x3) painting canvases.
## Both canvases live in the world at the same position; only one is active at a time.
## Each canvas retains its sticker state while inactive.
## Locked (and auto-switched to square) while a mission is active.

@export var square_canvas: Node3D
@export var landscape_canvas: Node3D
@export var painting_ui: PaintingUI

var _active_is_square: bool = true
var _click_sound: AudioStreamPlayer3D
var _click_stream: AudioStream = preload("res://sounds/picotron/closemenu.ogg")
var _error_sound: AudioStreamPlayer3D
var _error_stream: AudioStream = preload("res://sounds/picotron/error.ogg")


func _ready() -> void:
	super._ready()
	_click_sound = AudioStreamPlayer3D.new()
	_click_sound.name = "ClickSound"
	_click_sound.max_distance = 15.0
	_click_sound.bus = "SFX"
	_click_sound.stream = _click_stream
	add_child(_click_sound)

	_error_sound = AudioStreamPlayer3D.new()
	_error_sound.name = "ErrorSound"
	_error_sound.max_distance = 15.0
	_error_sound.bus = "SFX"
	_error_sound.stream = _error_stream
	add_child(_error_sound)

	if MissionManager:
		MissionManager.mission_started.connect(_on_mission_started)
		MissionManager.mission_completed.connect(_on_mission_ended)
		MissionManager.mission_aborted.connect(_on_mission_aborted)
		MissionManager.mission_failed.connect(_on_mission_ended)

	if PaintingSpawner:
		PaintingSpawner.canvas_replaced.connect(_on_canvas_replaced)

	if not square_canvas or not landscape_canvas:
		push_warning("CanvasFormatToggle: canvas exports not configured yet.")
		return
	# Landscape starts hidden and disabled
	landscape_canvas.visible = false
	landscape_canvas.process_mode = Node.PROCESS_MODE_DISABLED
	_update_text()


func _on_interacted(_player: PlayerInteractionComponent) -> void:
	if MissionManager and MissionManager.current_mission:
		_error_sound.play()
		return
	if not square_canvas or not landscape_canvas:
		push_warning("CanvasFormatToggle: canvas exports not configured.")
		return
	_active_is_square = not _active_is_square
	_apply_canvas_state()
	_update_text()
	_click_sound.play()
	_play_button_animation()


func _on_canvas_replaced(new_root: Node3D, is_landscape: bool) -> void:
	if is_landscape:
		landscape_canvas = new_root
	else:
		square_canvas = new_root
	_apply_canvas_state()


func _on_mission_started(_mission: PaintingMission) -> void:
	if not _active_is_square:
		_switch_to_square()
	_update_text()


func _on_mission_ended(_mission, _result) -> void:
	_update_text()


func _on_mission_aborted(_mission: PaintingMission) -> void:
	_update_text()


func _switch_to_square() -> void:
	_active_is_square = true
	_apply_canvas_state()


func _apply_canvas_state() -> void:
	if not square_canvas or not landscape_canvas:
		return
	square_canvas.visible = _active_is_square
	square_canvas.process_mode = Node.PROCESS_MODE_INHERIT if _active_is_square else Node.PROCESS_MODE_DISABLED
	landscape_canvas.visible = not _active_is_square
	landscape_canvas.process_mode = Node.PROCESS_MODE_INHERIT if not _active_is_square else Node.PROCESS_MODE_DISABLED
	var active := square_canvas if _active_is_square else landscape_canvas
	var system: PaintingSystem2D = active.get_node("CanvasViewport/CanvasRoot")
	PaintingModeManager.register_2d_system(system, active)
	if painting_ui:
		painting_ui.set_active_system(system)


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
	if MissionManager and MissionManager.current_mission:
		interaction_text = "Not During Mission!"
		return
	interaction_text = "Switch to Landscape" if _active_is_square else "Switch to Square"
