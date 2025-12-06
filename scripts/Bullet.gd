extends RigidBody3D
class_name Bullet

## Physics-based bullet projectile
## Flies forward, collides with objects, and despawns on impact or after lifetime

# --- EXPORTED VARIABLES ---
@export_group("Bullet Settings")
@export var speed: float = 5.0  ## Bullet speed (slow for testing, increase later)
@export var lifetime: float = 10.0  ## Seconds before auto-despawn
@export var damage: float = 25.0  ## Damage dealt to hit objects
@export var impact_effect: PackedScene  ## Optional impact particle effect
@export var visual_rotation_offset: Vector3 = Vector3(0, 90, 0)  ## Model rotation offset (degrees) to fix orientation

# --- PRIVATE VARIABLES ---
var _lifetime_timer: float = 0.0
var fire_direction: Vector3 = Vector3.FORWARD  ## Direction to fire (set by WeaponComponent)

# --- GODOT METHODS ---

func _ready() -> void:
	# Apply visual rotation offset to model
	var model = get_node_or_null("model")
	if model:
		model.rotation_degrees = visual_rotation_offset

	# Apply impulse in the fire_direction (passed from WeaponComponent)
	var impulse = fire_direction * speed

	print("=== BULLET _ready() DEBUG ===")
	print("  Bullet position: ", global_position)
	print("  Fire direction: ", fire_direction)
	print("  Impulse (fire_direction * speed): ", impulse)
	print("  Speed: ", speed)

	apply_central_impulse(impulse)

	# Connect collision signal
	if has_signal("body_entered"):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Track lifetime
	_lifetime_timer += delta

	# Auto-despawn after lifetime
	if _lifetime_timer >= lifetime:
		queue_free()

# --- COLLISION HANDLING ---

func _on_body_entered(body: Node) -> void:
	"""Handle collision - apply damage and despawn"""

	# Try to apply damage to the hit object
	_try_apply_damage(body)

	# Spawn impact effect if available
	if impact_effect:
		_spawn_impact_effect()

	# Despawn bullet
	queue_free()

func _try_apply_damage(body: Node) -> void:
	"""Attempt to apply damage to the hit object"""
	# Check if body has a damage method (common patterns)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_method("damage"):
		body.damage(damage)

	# Check for BreakableComponent
	var breakable = _find_breakable_component(body)
	if breakable and breakable.has_method("take_damage"):
		breakable.take_damage(damage)

func _find_breakable_component(node: Node) -> Node:
	"""Search for BreakableComponent in node hierarchy"""
	# Check children
	for child in node.get_children():
		if child.get_class() == "BreakableComponent" or child.name.contains("Breakable"):
			return child

	return null

func _spawn_impact_effect() -> void:
	"""Spawn impact particle effect at bullet position"""
	var effect = impact_effect.instantiate()
	get_tree().root.add_child(effect)
	effect.global_position = global_position
