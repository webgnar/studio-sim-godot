extends InteractionComponent
class_name CarryableComponent
## Physics-based carrying component for RigidBody3D objects
## Allows player to pick up, carry, and throw objects
## Based on COGITO implementation with simplified features

# --- SIGNALS ---
signal being_carried_changed(is_being_carried: bool)
signal thrown(impulse: Vector3)

# --- EXPORTED VARIABLES ---
@export_group("Carry Settings")
@export var carry_distance_offset: float = 0.0 ## Offset from default carry position (negative = closer, positive = farther)
@export var carry_smoothness: float = 10.0 ## Higher = snappier, lower = floatier (COGITO uses 10)
@export var drop_distance: float = 1.5 ## Auto-drop if object gets this far from carry position
@export var lock_rotation_when_carried: bool = true ## Prevents object from tumbling while held

@export_group("Throw Settings")
@export var throw_power: float = 15.0 ## Force applied when throwing
@export var drop_power: float = 1.0 ## Force applied when gently dropping

@export_group("Audio")
@export var pickup_sound: AudioStream
@export var drop_sound: AudioStream

# --- PRIVATE VARIABLES ---
var parent_rigid_body: RigidBody3D
var player_ref: PlayerInteractionComponent
var is_carried: bool = false
var carry_target: Vector3

# --- GODOT METHODS ---

func _ready() -> void:
	super._ready()  # Call InteractionComponent._ready()
	
	# Validate parent is RigidBody3D
	parent_rigid_body = get_parent() as RigidBody3D
	if not parent_rigid_body:
		push_error("CarryableComponent: Parent must be RigidBody3D! Found: " + get_parent().get_class())
		return
	
	# Connect to collision signal for auto-drop on player collision
	if parent_rigid_body.has_signal("body_entered"):
		parent_rigid_body.body_entered.connect(_on_body_entered)
	
	interaction_text = "Pick Up"
	print("✅ CarryableComponent ready: " + parent_object.name + " (mass: " + str(parent_rigid_body.mass) + "kg)")

func _physics_process(_delta: float) -> void:
	if not is_carried or not player_ref:
		return
	
	# Update carry target position
	carry_target = player_ref.get_carry_position(carry_distance_offset)
	
	# Apply velocity toward target (smooth physics-based movement)
	# This is THE KEY to COGITO's smooth carrying - use velocity, NOT position!
	parent_rigid_body.linear_velocity = (carry_target - parent_rigid_body.global_position) * carry_smoothness
	
	# Auto-drop if object gets too far away (prevents carrying through walls)
	var distance = parent_rigid_body.global_position.distance_to(carry_target)
	if distance >= drop_distance:
		print("⚠️ Auto-dropping " + parent_object.name + " - too far from carry position")
		drop()

func _exit_tree() -> void:
	# Clean up if object is removed while being carried
	if is_carried:
		drop()

# --- INTERACTION METHODS ---

func _on_interacted(player_interaction: PlayerInteractionComponent) -> void:
	# Toggle: drop if already carrying, pickup if not
	if is_carried:
		drop()
	else:
		pickup(player_interaction)

# --- CARRY METHODS ---

func pickup(player_interaction: PlayerInteractionComponent) -> void:
	"""Pick up the object - called when player interacts"""
	if is_carried:
		print("⚠️ Already being carried!")
		return
	
	player_ref = player_interaction
	
	# Disable CCD while carrying (not needed for smooth velocity-based movement)
	parent_rigid_body.continuous_cd = false
	
	# Configure physics state
	if lock_rotation_when_carried:
		parent_rigid_body.lock_rotation = true  # Prevents tumbling
	
	parent_rigid_body.freeze = false  # MUST be false to allow velocity movement
	parent_rigid_body.angular_velocity = Vector3.ZERO  # Stop any spinning
	
	# Tell player to start carrying this object
	player_ref.start_carrying(self)
	
	# CRITICAL: Exclude from raycast so we don't detect the held object
	if player_ref.get_raycast():
		player_ref.get_raycast().add_exception(parent_rigid_body)
	
	# Play pickup sound
	if pickup_sound:
		_play_sound(pickup_sound)
	
	# Update state
	is_carried = true
	interaction_text = "Drop"
	being_carried_changed.emit(true)
	
	print("🤲 Picked up: " + parent_object.name)

func drop() -> void:
	"""Drop the object gently - called when player releases or auto-drop triggers"""
	if not is_carried:
		return
	
	# Reset velocities BEFORE restoring physics to prevent tunneling
	parent_rigid_body.linear_velocity = Vector3.ZERO
	parent_rigid_body.angular_velocity = Vector3.ZERO
	
	# Restore physics state
	if lock_rotation_when_carried:
		parent_rigid_body.lock_rotation = false  # Allow natural rotation again
	
	# Tell player to stop carrying
	if player_ref and is_instance_valid(player_ref):
		player_ref.stop_carrying()
		
		# Remove raycast exception
		if player_ref.get_raycast():
			player_ref.get_raycast().remove_exception(parent_rigid_body)
	
	# Play drop sound
	if drop_sound:
		_play_sound(drop_sound)
	
	# Update state
	is_carried = false
	interaction_text = "Pick Up"
	being_carried_changed.emit(false)
	player_ref = null
	
	print("📦 Dropped: " + parent_object.name)

func throw(power: float) -> void:
	"""Throw the object with force - called by player input"""
	if not is_carried or not player_ref or not is_instance_valid(player_ref):
		return
	
	# Get throw direction (where player is looking)
	var throw_direction = player_ref.get_look_direction()
	
	# Reset velocities first to get clean throw
	parent_rigid_body.linear_velocity = Vector3.ZERO
	parent_rigid_body.angular_velocity = Vector3.ZERO
	
	# Enable continuous collision detection for fast-moving throws
	parent_rigid_body.continuous_cd = true
	
	# Drop first (cleans up state)
	drop()
	
	# Calculate and apply impulse AFTER drop has reset velocities
	var impulse = throw_direction * power
	parent_rigid_body.apply_central_impulse(impulse)
	
	# Emit signal for potential VFX/audio
	thrown.emit(impulse)
	
	# Disable CCD after object comes to rest (check in physics process)
	_monitor_throw_velocity()
	
	print("🎯 Threw: " + parent_object.name + " with power: " + str(power))

func _monitor_throw_velocity() -> void:
	"""Monitor velocity after throw and disable CCD when object settles"""
	# Wait a frame to let physics start
	await get_tree().physics_frame
	
	# Check velocity over several frames
	var settle_threshold = 0.5  # Speed below which we consider it "settled"
	var check_frames = 10  # Number of frames to check
	
	for i in range(check_frames):
		await get_tree().physics_frame
		
		if not is_instance_valid(parent_rigid_body):
			return
		
		var speed = parent_rigid_body.linear_velocity.length()
		
		# If settled, disable CCD and stop monitoring
		if speed < settle_threshold:
			parent_rigid_body.continuous_cd = false
			print("💤 " + parent_object.name + " settled, CCD disabled")
			return
	
	# If still moving after check frames, keep CCD enabled but stop monitoring
	# It will get disabled on next pickup/drop cycle
	print("⚡ " + parent_object.name + " still moving fast, keeping CCD enabled")

# --- COLLISION HANDLING ---

func _on_body_entered(body: Node) -> void:
	"""Auto-drop if carried object collides with player"""
	if body.is_in_group("Player") and is_carried:
		print("⚠️ Carried object hit player - auto-dropping")
		drop()

# --- PUBLIC METHODS ---

func is_being_carried() -> bool:
	"""Check if this object is currently being carried"""
	return is_carried

func get_carrying_player() -> PlayerInteractionComponent:
	"""Get reference to player carrying this object (or null)"""
	return player_ref if is_carried else null

func force_drop() -> void:
	"""Force drop (for external systems like save/load)"""
	if is_carried:
		drop()
