extends WeaponComponent
class_name PencilWeaponComponent
## Equippable pencil, following the same pattern as NailGunComponent: equip
## with E (reparents into the camera's GunMarker, like a held weapon).
## Purely decorative/static otherwise — no CarryableComponent, no physics;
## it stays frozen on the desk until equipped, and snaps back there on drop.
## Drawing on the 2D painting canvas is driven by PaintingModeManager, which
## polls is_weapon_equipped + held input each frame — shoot() is unused here
## since drawing is continuous, not a single per-click action.

var home_transform: Transform3D

func _ready() -> void:
	super._ready()
	interaction_text = "Pick Up Pencil"
	home_transform = parent_object.global_transform

func _process(_delta: float) -> void:
	# Continuously re-apply the equipped transform (rather than only once, at pickup)
	# so equipped_position/equipped_rotation can be tuned live while the pencil is
	# equipped and playing — e.g. via the editor's Debugger > Remote scene tree.
	# Also keeps _gun_rest_position in sync so WeaponComponent's own wall-clip
	# prevention (base _physics_process) doesn't snap back to a stale value.
	if state == State.EQUIPPED:
		_gun_rest_position = equipped_position
		parent_object.position = equipped_position
		parent_object.rotation_degrees = equipped_rotation

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Keep the pencil frozen whenever it isn't actively equipped. This also guards
	# against ShopManager._reveal_prop() unfreezing + impulsing RigidBody3D props on
	# purchase (meant for physics-based props) — the pencil has no physics by design,
	# so it self-corrects back to frozen within one physics tick instead of falling
	# or rolling off the desk the moment it's bought.
	if state != State.EQUIPPED:
		var parent_rb := parent_object as RigidBody3D
		if parent_rb and not parent_rb.freeze:
			parent_rb.freeze = true

func shoot() -> void:
	pass  # No-op: drawing is handled by PaintingModeManager polling, not a per-click shot

func drop() -> void:
	super.drop()
	var parent_rb := parent_object as RigidBody3D
	if not parent_rb:
		return
	parent_rb.global_transform = home_transform
	parent_rb.linear_velocity = Vector3.ZERO
	parent_rb.angular_velocity = Vector3.ZERO
	parent_rb.freeze = true
