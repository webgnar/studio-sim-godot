extends InteractionComponent
class_name CycloneButton

@export var cyclone: Cyclone
@export_range(1, 3) var button_number: int = 1

func _on_ready() -> void:
	interaction_text = "Press Button"

func _on_interacted(_player: PlayerInteractionComponent) -> void:
	if not cyclone:
		return
	if cyclone.stopped:
		cyclone.stopped = false
		cyclone.clear_all_labels()
	else:
		cyclone.stopped = true
		var lbl := cyclone.get_result_label(button_number)
		if lbl:
			lbl.text = "Winner!" if cyclone.is_winner(button_number) else "Loser!"
