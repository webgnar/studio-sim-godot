extends InteractionComponent

## Red button in the Studio Assistant room.
## Bakes the sticker wall's current state to a PNG, sends it to the finished canvas
## in the adjacent room, then clears the sticker wall for the next session.

var _is_saving: bool = false
var _save_stream: AudioStream = preload("res://sounds/picotron/darkneb.ogg")
var _save_sound: AudioStreamPlayer3D
var _sticker_wall: Node


func _ready() -> void:
	super._ready()
	interaction_text = "Transfer Assistant's Work"
	print("SaveAssistantWorkButton: ready. Node path: ", get_path())

	_save_sound = AudioStreamPlayer3D.new()
	_save_sound.name = "SaveSound"
	_save_sound.max_distance = 15.0
	_save_sound.bus = "SFX"
	_save_sound.stream = _save_stream
	add_child(_save_sound)

	# Cache sticker wall reference
	var studio = get_parent().get_parent()
	_sticker_wall = studio.get_node_or_null("StickerWall") if studio else null


func _on_hover_started() -> void:
	_refresh_text()


func _refresh_text() -> void:
	if _is_saving:
		return
	if _sticker_wall and not _sticker_wall.has_stickers():
		interaction_text = "Nothing to Transfer Yet"
	else:
		interaction_text = "Transfer Assistant's Work"


func _on_interacted(_player: PlayerInteractionComponent) -> void:
	print("SaveAssistantWorkButton: _on_interacted fired!")

	if _is_saving:
		print("SaveAssistantWorkButton: already saving, ignoring.")
		return

	if not _sticker_wall:
		push_error("SaveAssistantWorkButton: StickerWall not found!")
		return

	print("SaveAssistantWorkButton: has_stickers = ", _sticker_wall.has_stickers())
	if not _sticker_wall.has_stickers():
		interaction_text = "Nothing to Transfer Yet"
		return

	_is_saving = true
	interaction_text = "Saving..."
	_execute_save(_sticker_wall)


func _execute_save(sticker_wall: Node) -> void:
	print("SaveAssistantWorkButton: starting bake...")
	_save_sound.play()
	_play_button_animation()

	var image: Image = await sticker_wall.bake_to_image()
	print("SaveAssistantWorkButton: bake done, image size = ", image.get_size())

	var canvas = get_tree().get_first_node_in_group("assistant_canvas")
	print("SaveAssistantWorkButton: canvas node = ", canvas)
	if canvas:
		await canvas.set_background_composite(image)

	sticker_wall.clear_stickers()
	print("SaveAssistantWorkButton: stickers cleared.")

	_is_saving = false
	_refresh_text()


func _play_button_animation() -> void:
	var anim_player = get_node_or_null("../green button/AnimationPlayer")
	print("SaveAssistantWorkButton: anim_player = ", anim_player)
	if not anim_player:
		return
	anim_player.play("press")
	await anim_player.animation_finished
	anim_player.play("release")
