extends InteractionComponent
class_name ButtonInteractionComponent

## Button that converts mission painting to carryable object
## Triggers PaintingSpawner conversion with cooldown prevention

@export var button_cooldown: float = 1.0  ## Prevent spam clicking
var last_pressed: float = 0.0

func _ready() -> void:
	super._ready()

	# Set default interaction text
	if interaction_text.is_empty():
		interaction_text = "Convert Painting"

func _on_interacted(player_interaction_component: PlayerInteractionComponent) -> void:
	# Cooldown check
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_pressed < button_cooldown:
		return

	last_pressed = current_time

	# Trigger conversion
	PaintingSpawner.replace_painting_with_carryable(get_tree().current_scene)

	# Play button press animation if available
	var anim_player = find_animation_player()
	if anim_player and anim_player.has_animation("press"):
		anim_player.play("press")
