extends CarryableComponent
class_name PowerCordPlugComponent
## Physics-based power cord plug that can be carried and plugged into outlets
## Extends CarryableComponent to reuse carrying mechanics

# --- SIGNALS ---
signal plugged_into(outlet: OutletComponent)
signal unplugged_from(outlet: OutletComponent)
signal near_outlet(outlet: OutletComponent)
signal left_outlet()

# --- EXPORTED VARIABLES ---
@export_group("Plug Settings")
@export var snap_distance: float = 0.5 ## How close to outlet before showing plug hint
@export var plug_force: float = 2.0 ## Force applied when snapping to outlet
@export var auto_plug_on_release: bool = true ## Automatically plug when releasing near outlet

@export_group("Cord References")
@export var cord_segments: Array[RigidBody3D] = [] ## All segments of the cord (for visual feedback)
@export var anchor_point: Node3D ## Fixed point where cord is attached (wall/device)

# --- PRIVATE VARIABLES ---
var current_outlet: OutletComponent = null
var nearby_outlet: OutletComponent = null
var is_plugged: bool = false
var was_near_outlet: bool = false
var outlet_check_timer: float = 0.0
var outlet_check_interval: float = 0.1 ## Only check every 0.1 seconds to avoid performance issues

# --- GODOT METHODS ---

func _ready() -> void:
	super._ready()
	interaction_text = "Pick Up Plug"
	
	# Reduce carry smoothness for cord (less aggressive than boxes)
	carry_smoothness = 3.0  # Much slower, gentler movement
	drop_distance = 3.0  # Allow more slack
	lock_rotation_when_carried = false  # Never lock rotation on cords!
	
	# Add to group for easy finding
	add_to_group("power_plugs")
	
	print("✅ PowerCordPlugComponent ready: " + parent_object.name)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Only check for outlets when being carried
	if is_carried and not is_plugged:
		outlet_check_timer += delta
		if outlet_check_timer >= outlet_check_interval:
			outlet_check_timer = 0.0
			_check_for_nearby_outlets()

# --- OUTLET DETECTION ---

func _check_for_nearby_outlets() -> void:
	"""Check if we're near any outlets while being carried"""
	
	# Safety check
	if not is_instance_valid(parent_rigid_body) or not get_tree():
		return
	
	var closest_outlet: OutletComponent = null
	var closest_distance: float = snap_distance
	
	# Find all outlets (with safety check)
	var outlets = get_tree().get_nodes_in_group("outlets")
	if outlets == null:
		return
	
	for outlet in outlets:
		if not is_instance_valid(outlet):
			continue
			
		if outlet is OutletComponent and not outlet.is_occupied:
			var distance = parent_rigid_body.global_position.distance_to(outlet.plug_socket_position)
			
			if distance < closest_distance:
				closest_distance = distance
				closest_outlet = outlet
	
	# Update nearby outlet state
	if closest_outlet != nearby_outlet:
		if nearby_outlet:
			left_outlet.emit()
			was_near_outlet = false
		
		nearby_outlet = closest_outlet
		
		if nearby_outlet:
			near_outlet.emit(nearby_outlet)
			was_near_outlet = true
			
			# Show hint to player
			if is_instance_valid(player_ref):
				player_ref.show_hint(null, "Press E to Plug In • Click to Throw")
	elif not closest_outlet and was_near_outlet:
		left_outlet.emit()
		was_near_outlet = false
		nearby_outlet = null

# --- PLUG/UNPLUG METHODS ---

func plug_into(outlet: OutletComponent) -> bool:
	"""Plug this cord into an outlet"""
	if is_plugged:
		print("⚠️ Already plugged into an outlet!")
		return false
	
	if not outlet or outlet.is_occupied:
		print("⚠️ Outlet is occupied or invalid!")
		return false
	
	# Safety check
	if not is_instance_valid(parent_rigid_body):
		print("⚠️ Invalid parent RigidBody3D!")
		return false
	
	# Drop from player's hands if being carried
	if is_carried and is_instance_valid(player_ref):
		# Disable physics updates temporarily
		is_carried = false
		if player_ref:
			player_ref.carried_object = null
			player_ref.is_carrying = false
	
	# Snap to outlet position
	parent_rigid_body.global_position = outlet.plug_socket_position
	parent_rigid_body.freeze = true  # Lock in place
	parent_rigid_body.lock_rotation = true
	
	# Update state
	is_plugged = true
	current_outlet = outlet
	interaction_text = "Unplug"
	
	# Clear nearby outlet
	nearby_outlet = null
	was_near_outlet = false
	
	# Don't play sound here - outlet will play the plug in sound
	
	# Emit signal
	plugged_into.emit(outlet)
	
	print("🔌 Plugged into outlet: " + outlet.parent_object.name)
	return true

func unplug() -> bool:
	"""Unplug this cord from its outlet"""
	if not is_plugged:
		print("⚠️ Not plugged in!")
		return false
	
	# Safety check
	if not is_instance_valid(parent_rigid_body):
		print("⚠️ Invalid parent RigidBody3D!")
		return false
	
	var outlet = current_outlet
	
	print("🔌 UNPLUGGING - Before state:")
	print("  - Freeze: " + str(parent_rigid_body.freeze))
	print("  - Lock rotation: " + str(parent_rigid_body.lock_rotation))
	print("  - Collision layer: " + str(parent_rigid_body.collision_layer))
	print("  - Collision mask: " + str(parent_rigid_body.collision_mask))
	print("  - In interactable group: " + str(parent_object.is_in_group("interactable")))
	
	# Move plug slightly away from outlet BEFORE unfreezing to avoid clipping
	if is_instance_valid(outlet):
		var push_dir = (parent_rigid_body.global_position - outlet.global_position).normalized()
		# Move it out a bit before unfreezing
		parent_rigid_body.global_position += push_dir * 0.2
	
	# Restore physics AFTER repositioning
	parent_rigid_body.freeze = false
	parent_rigid_body.lock_rotation = false
	
	# Reset velocities to prevent sudden movements
	parent_rigid_body.linear_velocity = Vector3.ZERO
	parent_rigid_body.angular_velocity = Vector3.ZERO
	
	# Update state
	is_plugged = false
	current_outlet = null
	interaction_text = "Pick Up Plug"
	
	# Give a gentle push away from outlet (smaller impulse)
	if is_instance_valid(outlet):
		var push_dir = (parent_rigid_body.global_position - outlet.global_position).normalized()
		parent_rigid_body.apply_central_impulse(push_dir * 0.2)  # Reduced from 0.5
	
	# Don't play sound here - outlet will play the plug out sound
	
	# Emit signal
	unplugged_from.emit(outlet)
	
	print("🔌 UNPLUGGED - After state:")
	print("  - Freeze: " + str(parent_rigid_body.freeze))
	print("  - Lock rotation: " + str(parent_rigid_body.lock_rotation))
	print("  - Collision layer: " + str(parent_rigid_body.collision_layer))
	print("  - Collision mask: " + str(parent_rigid_body.collision_mask))
	print("  - In interactable group: " + str(parent_object.is_in_group("interactable")))
	print("  - Interaction text: " + interaction_text)
	
	return true

# --- OVERRIDE INTERACTION ---

func _on_interacted(player_interaction: PlayerInteractionComponent) -> void:
	"""Override interaction based on plug state"""
	
	if is_plugged:
		# If plugged, unplug it (but don't pick it up yet - player needs to interact again)
		unplug()
		# Player will need to interact again to pick it up after unplugging
	elif is_carried and nearby_outlet:
		# If carrying near outlet, plug it in
		if nearby_outlet.accept_plug(self):
			# Outlet will call our plug_into() method
			pass
	else:
		# Normal pickup/drop behavior (when not plugged and not near outlet)
		super._on_interacted(player_interaction)

# --- OVERRIDE DROP ---

func drop() -> void:
	"""Override drop to check for auto-plug"""
	
	# Check if we should auto-plug
	if auto_plug_on_release and nearby_outlet and not is_plugged:
		if nearby_outlet.accept_plug(self):
			# Successfully plugged, don't drop
			return
	
	# Normal drop behavior
	super.drop()
	
	nearby_outlet = null
	was_near_outlet = false

# --- PUBLIC METHODS ---

func get_is_plugged() -> bool:
	"""Check if plug is currently in an outlet"""
	return is_plugged

func get_current_outlet() -> OutletComponent:
	"""Get the outlet this plug is connected to (or null)"""
	return current_outlet

func get_cord_length() -> float:
	"""Calculate total cord length from anchor"""
	if cord_segments.is_empty() or not anchor_point:
		return 0.0
	
	var total_length = 0.0
	var prev_pos = anchor_point.global_position
	
	for segment in cord_segments:
		total_length += prev_pos.distance_to(segment.global_position)
		prev_pos = segment.global_position
	
	return total_length

func is_near_outlet() -> bool:
	"""Check if plug is currently near an outlet"""
	return nearby_outlet != null
