extends InteractionComponent

## Green button near the AssistantFinishedCanvas.
## Bakes the current canvas (background + player stickers) into a CarryablePainting5x3,
## then resets the canvas for the next collaborative session.

var _is_converting: bool = false
var _convert_stream: AudioStream = preload("res://sounds/picotron/lougnar_sound.ogg")
var _convert_sound: AudioStreamPlayer3D
var _canvas: AssistantFinishedCanvas


func _ready() -> void:
	super._ready()
	interaction_text = "Convert to Painting"

	_convert_sound = AudioStreamPlayer3D.new()
	_convert_sound.name = "ConvertSound"
	_convert_sound.max_distance = 15.0
	_convert_sound.bus = "SFX"
	_convert_sound.stream = _convert_stream
	add_child(_convert_sound)

	# Cache canvas reference
	_canvas = get_tree().get_first_node_in_group("assistant_canvas") as AssistantFinishedCanvas

	# Gate visibility behind assistant purchase
	_set_button_active(AutomationManager.is_assistant_active())
	AutomationManager.assistant_purchased.connect(_on_assistant_purchased)


func _on_assistant_purchased() -> void:
	_set_button_active(true)


func _set_button_active(active: bool) -> void:
	get_parent().visible = active
	var body = get_node_or_null("../StaticBody3D")
	if body:
		body.collision_layer = 8 if active else 0


func _on_hover_started() -> void:
	_refresh_text()


func _refresh_text() -> void:
	if _is_converting:
		return
	if _canvas and not _canvas.has_content():
		interaction_text = "Canvas is Empty"
	else:
		interaction_text = "Convert to Painting"


func _on_interacted(_player: PlayerInteractionComponent) -> void:
	if _is_converting:
		return

	if not _canvas:
		_canvas = get_tree().get_first_node_in_group("assistant_canvas") as AssistantFinishedCanvas

	if not _canvas or not _canvas.has_content():
		interaction_text = "Canvas is Empty"
		return

	_is_converting = true
	interaction_text = "Converting..."
	_convert_sound.play()
	_play_button_animation()

	await PaintingSpawner.replace_painting_from_root(get_tree().current_scene, _canvas)
	_canvas.reset_canvas()

	_is_converting = false
	_refresh_text()


func _play_button_animation() -> void:
	var anim_player = get_node_or_null("../green button/AnimationPlayer")
	if not anim_player:
		return
	anim_player.play("press")
	await anim_player.animation_finished
	anim_player.play("release")
