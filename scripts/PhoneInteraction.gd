extends InteractionComponent
class_name PhoneInteraction

func _on_ready() -> void:
	if interaction_text.is_empty():
		interaction_text = "Check Phone"

func _on_interacted(_player: PlayerInteractionComponent) -> void:
	var anim_player = find_animation_player()
	if anim_player == null:
		return
	if anim_player.is_playing():
		return
	if anim_player.has_animation("kickflip"):
		anim_player.play("kickflip")
