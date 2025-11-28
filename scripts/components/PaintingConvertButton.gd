extends Node3D
class_name PaintingConvertButton

## Standalone button component for converting paintings
## Simpler than InteractionComponent - just handles button press

@export var button_cooldown: float = 1.0
@export var interaction_text: String = "Convert Painting"

var last_pressed: float = 0.0

func _ready() -> void:
	print("🔵 PaintingConvertButton _ready() called")
	# Add parent to interactable group
	var parent = get_parent()
	print("🔵 Parent: " + str(parent.name if parent else "NULL"))
	if parent and not parent.is_in_group("interactable"):
		parent.add_to_group("interactable")
		print("✅ Added " + parent.name + " to 'interactable' group")
	else:
		print("🔵 Parent already in interactable group or parent is null")

## Called by PlayerInteractionComponent when player interacts
func interact(player_interaction_component) -> void:
	print("🟢 Button interact() called!")

	# Cooldown check
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_pressed < button_cooldown:
		print("🟡 Button on cooldown, ignoring")
		return

	last_pressed = current_time
	print("🟢 Triggering painting conversion!")

	# Trigger conversion
	PaintingSpawner.replace_painting_with_carryable(get_tree().current_scene)

	# Play animation if available
	var anim_player = _find_animation_player()
	if anim_player and anim_player.has_animation("press"):
		print("🟢 Playing press animation")
		anim_player.play("press")
	else:
		print("🟡 No animation player found or no 'press' animation")

func _find_animation_player() -> AnimationPlayer:
	"""Recursively search for AnimationPlayer in parent hierarchy"""
	return _find_animation_player_recursive(get_parent())

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var result = _find_animation_player_recursive(child)
		if result:
			return result

	return null
