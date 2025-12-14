extends InteractionComponent

# SaveComputerInteraction - Enables manual save when interacting with computer
# Attach this to a Node3D as a child (will auto-add parent to "interactable" group)

func _on_ready():
	"""Called by InteractionComponent base class"""
	interaction_text = "Save Game"

func _on_interacted(player_interaction: PlayerInteractionComponent):
	"""Called when player presses E while looking at this object"""
	if not WorldStateManager:
		push_error("SaveComputerInteraction: WorldStateManager not found!")
		return

	print("Saving game...")
	var success = await WorldStateManager.save_world_state()

	if success:
		print("Game saved successfully!")
		# Show save notification
		var save_notification = get_tree().root.get_node_or_null("World/GameplayUI_Layer/SaveNotification")
		if save_notification and save_notification.has_method("show_notification"):
			save_notification.show_notification()
		else:
			push_warning("SaveComputerInteraction: SaveNotification not found in scene tree")
	else:
		print("Failed to save game")
