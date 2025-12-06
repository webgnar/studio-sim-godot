extends InteractionComponent
class_name WeaponComponent

## Weapon component for first-person gun mechanics
## Handles equipped state, shooting, animations, and state transitions

# --- ENUMS ---
enum State { WORLD, EQUIPPED }

# --- EXPORTED VARIABLES ---
@export_group("Weapon Settings")
@export var fire_rate: float = 0.5  ## Seconds between shots
@export var bullet_scene: PackedScene  ## Bullet.tscn scene
@export var equipped_position: Vector3 = Vector3(0.5, -0.3, -0.5)  ## Local position when equipped (right, down, forward)
@export var equipped_rotation: Vector3 = Vector3(0, 0, 0)  ## Local rotation degrees when equipped

@export_group("Audio")
@export var shoot_sound: AudioStream
@export var pickup_sound: AudioStream

# --- STATE VARIABLES ---
var state: State = State.WORLD
var player_ref: PlayerInteractionComponent = null

# --- COMPONENT REFERENCES ---
var slide_animator: AnimationPlayer = null
var flash_animator: AnimationPlayer = null
var bullet_spawn_marker: Marker3D = null
var carryable_component: CarryableComponent = null
var original_parent: Node3D = null

# --- SHOOTING VARIABLES ---
var last_shot_time: float = 0.0

# --- GODOT METHODS ---

func _ready() -> void:
	super._ready()  # Call InteractionComponent._ready()

	# Find animation players
	_find_animators()

	# Find bullet spawn marker
	bullet_spawn_marker = parent_object.get_node_or_null("bullet")
	if not bullet_spawn_marker:
		push_error("WeaponComponent: No 'bullet' Marker3D found in gun!")

	# Get CarryableComponent reference
	carryable_component = _find_carryable_component(parent_object)
	if not carryable_component:
		push_warning("WeaponComponent: No CarryableComponent found - gun won't work as carryable object when dropped")

	# Set initial interaction text
	interaction_text = "Pick Up Gun"

func _find_animators() -> void:
	"""Search for slide and flash AnimationPlayers in the gun hierarchy"""
	# Look for slide animator in model/top/AnimationPlayer
	var model = parent_object.get_node_or_null("model")
	if model:
		var top = model.get_node_or_null("top")
		if top:
			slide_animator = top.get_node_or_null("AnimationPlayer")

	# Look for flash animator in Sprite3D/AnimationPlayer
	var sprite3d = parent_object.get_node_or_null("Sprite3D")
	if sprite3d:
		flash_animator = sprite3d.get_node_or_null("AnimationPlayer")

	# Debug warnings
	if not slide_animator:
		push_warning("WeaponComponent: Slide AnimationPlayer not found")
	if not flash_animator:
		push_warning("WeaponComponent: Flash AnimationPlayer not found")

func _find_carryable_component(node: Node) -> CarryableComponent:
	"""Search for CarryableComponent in node hierarchy"""
	for child in node.get_children():
		if child is CarryableComponent:
			return child

	return null

# --- INTERACTION METHODS ---

func _on_interacted(player_interaction: PlayerInteractionComponent) -> void:
	"""Handle E key interaction"""
	if state == State.WORLD:
		# Pick up and equip gun
		pickup(player_interaction)
	elif state == State.EQUIPPED:
		# Drop gun back to world
		drop()

# --- WEAPON METHODS ---

func pickup(player: PlayerInteractionComponent) -> void:
	"""Equip gun to player"""
	if state == State.EQUIPPED:
		return

	print("WeaponComponent: Picking up gun")
	player_ref = player
	state = State.EQUIPPED

	# Get parent RigidBody3D
	var parent_rb = parent_object as RigidBody3D
	if not parent_rb:
		push_error("WeaponComponent: Parent must be RigidBody3D!")
		return

	# Store original parent for returning to world
	original_parent = parent_rb.get_parent()

	# Disable CarryableComponent (prevent physics carrying)
	if carryable_component:
		carryable_component.is_disabled = true

	# Freeze RigidBody3D physics
	parent_rb.freeze = true

	# Disable collision while equipped (prevents bumping into things)
	var collision_shape = parent_rb.get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = true

	# Try to find GunMarker first (user's custom marker), then fall back to CarryMarker
	var camera = player.get_camera()
	var gun_marker = camera.get_node_or_null("GunMarker")

	if not gun_marker:
		# Try player node
		var player_node = player.get_parent()
		gun_marker = player_node.get_node_or_null("GunMarker")

		if not gun_marker:
			# Fall back to CarryMarker
			gun_marker = player.carry_marker
			print("WeaponComponent: No GunMarker found, using CarryMarker")

	if not gun_marker:
		push_error("WeaponComponent: Player has no GunMarker or CarryMarker!")
		return

	print("WeaponComponent: Reparenting to marker at: ", gun_marker.global_position)
	print("WeaponComponent: Marker path: ", gun_marker.get_path())
	parent_rb.reparent(gun_marker)

	# Set first-person position/rotation
	parent_rb.position = equipped_position
	parent_rb.rotation_degrees = equipped_rotation

	print("WeaponComponent: Gun equipped!")
	print("  - Local position: ", parent_rb.position)
	print("  - Global position: ", parent_rb.global_position)
	print("  - Rotation: ", parent_rb.rotation_degrees)
	print("  - Parent: ", parent_rb.get_parent().name)
	print("  - Visible: ", parent_rb.visible)

	# Force visibility
	parent_rb.visible = true

	# Check if model child is visible
	var model = parent_rb.get_node_or_null("model")
	if model:
		print("  - Model visible: ", model.visible)
		model.visible = true

	# Tell player we're equipped
	player_ref.equip_weapon(self)

	# Play pickup sound
	if pickup_sound:
		_play_sound(pickup_sound)

	# Update interaction text
	interaction_text = "Drop Gun"

func drop() -> void:
	"""Return gun to world"""
	if state != State.EQUIPPED or not player_ref:
		return

	state = State.WORLD

	# Get parent RigidBody3D
	var parent_rb = parent_object as RigidBody3D
	if not parent_rb:
		return

	# Get drop position (in front of player)
	var camera = player_ref.get_camera()
	var drop_pos = camera.global_position + player_ref.get_look_direction() * 2.0

	# Reparent back to original parent (or world root)
	var target_parent = original_parent if original_parent and is_instance_valid(original_parent) else get_tree().root
	parent_rb.reparent(target_parent)

	# Restore position
	parent_rb.global_position = drop_pos

	# Unfreeze physics
	parent_rb.freeze = false

	# Re-enable collision
	var collision_shape = parent_rb.get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = false

	# Re-enable CarryableComponent
	if carryable_component:
		carryable_component.is_disabled = false

	# Tell player we're unequipped
	player_ref.unequip_weapon()
	player_ref = null

	# Update interaction text
	interaction_text = "Pick Up Gun"

func shoot() -> void:
	"""Fire weapon - spawn bullet, play animations, play sound"""
	if state != State.EQUIPPED:
		return

	# Check fire rate cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < fire_rate:
		return  # Too soon to shoot again

	last_shot_time = current_time

	# Spawn bullet
	_spawn_bullet()

	# Play animations
	_play_shoot_animations()

	# Play sound
	if shoot_sound:
		_play_sound(shoot_sound)

func _spawn_bullet() -> void:
	"""Instantiate bullet at spawn marker and launch it"""
	if not bullet_scene or not bullet_spawn_marker:
		return

	# Instantiate bullet
	var bullet = bullet_scene.instantiate()

	# Add to world (not as child of gun)
	get_tree().root.add_child(bullet)

	# Position bullet at spawn marker global position
	bullet.global_position = bullet_spawn_marker.global_position

	# Orient bullet to face camera forward (not gun's rotation)
	var camera = player_ref.get_camera()
	if camera:
		var forward = -camera.global_transform.basis.z
		bullet.look_at(bullet.global_position + forward, Vector3.UP)

	print("Bullet spawned at: ", bullet.global_position, " facing direction: ", -bullet.global_transform.basis.z)

	# Bullet.gd will apply impulse in its _ready()

func _play_shoot_animations() -> void:
	"""Play slide and muzzle flash animations simultaneously"""
	if slide_animator and slide_animator.has_animation("slide"):
		slide_animator.play("slide")

	if flash_animator and flash_animator.has_animation("flash"):
		flash_animator.play("flash")
