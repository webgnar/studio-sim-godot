extends StaticBody3D

## Invisible interaction body over the critic TV screen. Lets the player talk
## back to the critic after a review; all the logic lives in CritiqueDisplay.
## It is only in the "interactable" group while talking back is possible, so
## the TV shows no prompt the rest of the time.

var display: Node = null
var interaction_text: String = ""


func set_available(available: bool) -> void:
	if available and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not available and is_in_group("interactable"):
		remove_from_group("interactable")


func interact(_player: Node) -> void:
	if display and display.has_method("on_talk_back_pressed"):
		display.on_talk_back_pressed()
