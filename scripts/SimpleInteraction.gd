extends InteractionComponent
class_name SimpleInteraction

## Simple interaction component for testing
## Just prints a message and plays a sound when interacted with

@export var message: String = "Simple interaction triggered!"

func _on_interacted(player_interaction_component: PlayerInteractionComponent) -> void:
	print("🎯 " + message)
	print("   Interacted by: " + str(player_interaction_component.get_parent().name))
