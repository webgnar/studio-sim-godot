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
		# Optional: Show UI feedback
		# UIManager.show_notification("Game Saved")
	else:
		print("Failed to save game")
		# Optional: Show error feedback
		# UIManager.show_notification("Save Failed")
