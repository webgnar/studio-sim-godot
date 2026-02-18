extends InteractionComponent
class_name OpenStickerFolderButton

## Opens the custom stickers folder in the user's file explorer

func _on_ready() -> void:
	interaction_text = "Open Sticker Folder"

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	var path = ProjectSettings.globalize_path("user://custom_stickers/")
	OS.shell_open(path)

	var anim_player = find_animation_player()
	if anim_player and anim_player.has_animation("press"):
		anim_player.play("press")
		anim_player.animation_finished.connect(
			func(_name): anim_player.play("release"),
			CONNECT_ONE_SHOT
		)
