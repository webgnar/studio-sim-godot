extends InteractionComponent
class_name KeyPickup

## Interactable key that sets a player flag when picked up and then disappears

@export var key_flag_name: String = "studio_key"  # Flag name to set in WorldStateManager
@export var pickup_text: String = "Pick Up Key"

func _on_ready() -> void:
	interaction_text = pickup_text

func _on_interacted(_player: PlayerInteractionComponent) -> void:
	print("========== KEY PICKUP DEBUG ==========")
	print("🔑 Player is picking up key...")
	print("🔑 Key flag name: '%s'" % key_flag_name)

	# Set the key flag in WorldStateManager
	WorldStateManager.set_flag(key_flag_name, true)

	# Verify the flag was set
	var flag_value = WorldStateManager.has_flag(key_flag_name)
	print("🔑 Flag '%s' set to: %s" % [key_flag_name, flag_value])
	print("🔑 Removing key from scene...")
	print("======================================")

	# Remove the key from the scene
	if parent_object:
		parent_object.queue_free()
	else:
		# Fallback: remove self
		get_parent().queue_free()
