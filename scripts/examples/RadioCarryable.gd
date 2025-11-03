extends CarryableComponent

## Example: Radio that can be picked up AND toggled with E key
## Just enable has_e_key_interaction and override _on_e_key_interacted()

@export var audio_player: AudioStreamPlayer3D
var is_playing: bool = false

func _ready() -> void:
	# Enable E-key interaction
	has_e_key_interaction = true
	can_interact_while_carried = true  # Can toggle while carrying
	e_key_interaction_text = "Toggle Power"
	
	super._ready()

func _on_e_key_interacted(_player: PlayerInteractionComponent) -> void:
	is_playing = !is_playing
	
	if audio_player:
		if is_playing:
			audio_player.play()
		else:
			audio_player.stop()
	
	e_key_interaction_text = "Turn " + ("Off" if is_playing else "On")
	print("📻 Radio " + ("ON" if is_playing else "OFF"))
