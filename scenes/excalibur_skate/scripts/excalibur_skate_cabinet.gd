extends StaticBody3D
class_name ExSkateCabinet
## Placeholder arcade cabinet for ExcaliburSkate.
##
## Look at it and press interact to play: the player is locked, the camera
## blends to the cabinet's PlayCamera and the game gets input + sound. Press
## interact (E / gamepad X) or go_back to step away. Out of play the screen
## shows the (silent) attract/title card.

@export var game: ExSkateGame
@export var screen: MeshInstance3D
@export var play_camera: Camera3D
@export var screen_material: Material
@export var blend_time: float = 0.5

var interaction_text: String = "Play ExcaliburSkate"

var _playing: bool = false
var _enter_frame: int = 0
var _interactor: PlayerInteractionComponent
var _hint_layer: CanvasLayer


func _ready() -> void:
	game.input_enabled = false
	game.audio_enabled = false
	var mat := screen_material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("tv_tex", game.get_texture())
	screen.material_override = mat
	set_process(false)


func interact(interactor: Variant) -> void:
	if _playing or not interactor is PlayerInteractionComponent:
		return
	_begin_play(interactor)


func _process(_delta: float) -> void:
	# Ignore the press that started the session (it is still "just pressed" this frame).
	if Engine.get_process_frames() <= _enter_frame:
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("go_back"):
		_end_play()


func _exit_tree() -> void:
	if _playing:
		_end_play()


func _begin_play(interactor: PlayerInteractionComponent) -> void:
	_playing = true
	_enter_frame = Engine.get_process_frames()
	_interactor = interactor

	# Park the interaction component so clicks/E don't leak into the world.
	interactor._clear_interactable()
	interactor.set_process_input(false)
	interactor.set_physics_process(false)

	CameraManager.set_player_input(false)
	CameraManager.switch_to_camera(play_camera, blend_time)

	game.return_to_title()
	game.input_enabled = true
	game.audio_enabled = true
	_show_hint(true)
	set_process(true)


func _end_play() -> void:
	_playing = false
	set_process(false)
	_show_hint(false)
	game.input_enabled = false
	game.audio_enabled = false
	game.return_to_title()

	if is_instance_valid(_interactor):
		_interactor.set_process_input(true)
		_interactor.set_physics_process(true)
	if CameraManager.player_camera:
		CameraManager.switch_to_camera(CameraManager.player_camera, blend_time)
	CameraManager.set_player_input(true)
	_interactor = null


func _show_hint(on: bool) -> void:
	if on and _hint_layer == null:
		_hint_layer = CanvasLayer.new()
		_hint_layer.layer = 50
		add_child(_hint_layer)
		var label := Label.new()
		label.text = "%s Leave" % InputDeviceManager.get_formatted_prompt("interact")
		label.add_theme_font_override("font", ExSkateAssets.FONT)
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		label.position = Vector2(40, -70)
		_hint_layer.add_child(label)
	if _hint_layer:
		_hint_layer.visible = on
