extends InteractionComponent
class_name AssistantStyleWheel

## The Psy Wheel in the Studio Assistant room switches how the assistant
## paints (AutomationManager.ASSISTANT_STYLES). Each turn of it reverses the
## wheel's spin. StickerWallManager adds this to its sibling Psywheel, which
## has no collision of its own, so this gives it one (only while it's out).

const STYLE_NAMES := {"studio": "Studio", "hall_of_fame": "Hall of Fame", "random": "Random"}

var _shape: CollisionShape3D


func _on_ready() -> void:
	# Wheel-local units (the prop is scaled down to 0.05): the spinner sits
	# about 7 units up on its base
	var body := StaticBody3D.new()
	body.name = "StyleWheelBody"
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = Vector3(0.0, 4.5, 0.0)
	_shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 3.0
	cylinder.height = 9.0
	_shape.shape = cylinder
	body.add_child(_shape)
	parent_object.add_child(body)
	# Hidden until it's bought (ShopManager): no collision while hidden
	parent_object.visibility_changed.connect(_sync_shape)
	_sync_shape()
	_refresh_text()


func _sync_shape() -> void:
	_shape.set_deferred("disabled", not parent_object.is_visible_in_tree())


func _on_hover_started() -> void:
	_refresh_text()


func _on_interacted(_player: PlayerInteractionComponent) -> void:
	AutomationManager.next_assistant_style()
	var spin := parent_object.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if spin:
		spin.speed_scale = -spin.speed_scale
	_refresh_text()


func _refresh_text() -> void:
	interaction_text = "Assistant Style: %s" % STYLE_NAMES.get(AutomationManager.assistant_style, "Studio")
