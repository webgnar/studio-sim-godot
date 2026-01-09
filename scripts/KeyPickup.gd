extends InteractionComponent
class_name KeyPickup

## Interactable key that sets a player flag when picked up and then disappears

@export var key_flag_name: String = "studio_key"  # Flag name to set in WorldStateManager
@export var pickup_text: String = "Pick Up Key"

func _on_ready() -> void:
	interaction_text = pickup_text

func _on_interacted(_player: PlayerInteractionComponent) -> void:
	# Set the key flag in WorldStateManager
	WorldStateManager.set_flag(key_flag_name, true)

	print("Key picked up! Flag '%s' set to true" % key_flag_name)

	# Remove the key from the scene
	if parent_object:
		parent_object.queue_free()
	else:
		# Fallback: remove self
		get_parent().queue_free()
