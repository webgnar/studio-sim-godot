extends InteractionComponent

## Red button in the Studio Assistant room.
## Bakes the sticker wall's current state to a PNG, sends it to the finished canvas
## in the adjacent room, then clears the sticker wall for the next session.

var _is_saving: bool = false


func _ready() -> void:
	super._ready()
	interaction_text = "Take Assistant's Work"
	print("SaveAssistantWorkButton: ready. Node path: ", get_path())


func _on_interacted(_player: PlayerInteractionComponent) -> void:
	print("SaveAssistantWorkButton: _on_interacted fired!")

	if _is_saving:
		print("SaveAssistantWorkButton: already saving, ignoring.")
		return

	# SaveInteraction (self) → SaveAssistantWorkButton → AssistantStudio
	var studio = get_parent().get_parent()
	print("SaveAssistantWorkButton: studio node = ", studio.name if studio else "NULL")

	var sticker_wall = studio.get_node_or_null("StickerWall") if studio else null
	print("SaveAssistantWorkButton: sticker_wall = ", sticker_wall)

	if not sticker_wall:
		push_error("SaveAssistantWorkButton: StickerWall not found! Parent chain: %s → %s" % [get_parent().name, studio.name if studio else "?"])
		return

	print("SaveAssistantWorkButton: has_stickers = ", sticker_wall.has_stickers())
	if not sticker_wall.has_stickers():
		interaction_text = "Nothing to save yet"
		return

	_is_saving = true
	interaction_text = "Saving..."
	_execute_save(sticker_wall)


func _execute_save(sticker_wall: Node) -> void:
	print("SaveAssistantWorkButton: starting bake...")
	_play_button_animation()

	var image: Image = await sticker_wall.bake_to_image()
	print("SaveAssistantWorkButton: bake done, image size = ", image.get_size())

	var canvas = get_tree().get_first_node_in_group("assistant_canvas")
	print("SaveAssistantWorkButton: canvas node = ", canvas)
	if canvas:
		canvas.display_painting(image)

	sticker_wall.clear_stickers()
	print("SaveAssistantWorkButton: stickers cleared.")

	interaction_text = "Take Assistant's Work"
	_is_saving = false


func _play_button_animation() -> void:
	var anim_player = get_node_or_null("../green button/AnimationPlayer")
	print("SaveAssistantWorkButton: anim_player = ", anim_player)
	if not anim_player:
		return
	anim_player.play("press")
	await anim_player.animation_finished
	anim_player.play("release")
