extends InteractionComponent
class_name OpenURLButton

@export var url: String = ""

func _on_ready() -> void:
	interaction_text = "Open Link"

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	if url != "":
		OS.shell_open(url)
