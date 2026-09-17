extends InteractionComponent
class_name SkateboardComponent

## Attaches to a skateboard prop. Interacting mounts the player into
## PlayerController's skate mode and hands off to the scripted side-scroll
## camera tagged with the "skate_camera" group in the scene. A group lookup
## is used instead of an exported NodePath because a NodePath override on a
## node nested inside this instanced prop scene doesn't reliably survive
## editor re-saves of the parent scene.

func _on_ready() -> void:
	interaction_text = "Ride Skateboard"

func _on_interacted(player_interaction_component: PlayerInteractionComponent) -> void:
	is_disabled = true
	var player := player_interaction_component.get_parent()
	var skate_cam := get_tree().get_first_node_in_group("skate_camera") as Camera3D
	var board_anim := find_animation_player()
	var board_model := parent_object.get_node_or_null("model") as Node3D
	var board_collision := parent_object.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	player.start_skating(skate_cam, board_anim, board_model, board_collision)
