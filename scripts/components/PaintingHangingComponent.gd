extends CarryableComponent
class_name PaintingHangingComponent

## Painting hanging component - extends CarryableComponent with auto-snap to nails
## Pattern based on PowerCordPlugComponent
## Allows paintings to be hung on wall-mounted nails and taken down with E key

# --- CONSTANTS ---
const UNHANG_OFFSET: float = 0.3  ## Distance to push painting away from wall when unhanging

# --- SIGNALS ---
signal hung_on_nail(nail: NailComponent)
signal unhanged_from_nail(nail: NailComponent)
signal near_nail(nail: NailComponent)
signal left_nail()

# --- EXPORTED VARIABLES ---
@export_group("Hanging Settings")
@export var snap_distance: float = 0.5  ## How close to nail before auto-snap
@export var auto_hang_on_release: bool = true  ## Automatically hang when releasing near nail

# --- PRIVATE VARIABLES ---
var current_nail: NailComponent = null
var nearby_nail: NailComponent = null
var is_hung: bool = false
var was_near_nail: bool = false
var nail_check_timer: float = 0.0
var nail_check_interval: float = 0.1  ## Only check every 0.1 seconds to avoid performance issues

# --- GODOT METHODS ---

func _ready() -> void:
	super._ready()
	interaction_text = "Pick Up Painting"

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Only check for nails when being carried
	if is_carried and not is_hung:
		nail_check_timer += delta
		if nail_check_timer >= nail_check_interval:
			nail_check_timer = 0.0
			_check_for_nearby_nails()

# --- NAIL DETECTION ---

func _check_for_nearby_nails() -> void:
	"""Check if we're near any nails while being carried (like power cord)"""
	if not is_instance_valid(parent_rigid_body) or not get_tree():
		return

	var closest_nail: NailComponent = null
	var closest_distance: float = snap_distance

	var nails = get_tree().get_nodes_in_group("nails")
	if nails == null:
		return

	for nail in nails:
		if not is_instance_valid(nail):
			continue

		if nail is NailComponent and not nail.is_occupied:
			var distance = parent_rigid_body.global_position.distance_to(nail.painting_socket_position)

			if distance < closest_distance:
				closest_distance = distance
				closest_nail = nail

	# Update nearby nail state
	if closest_nail != nearby_nail:
		if nearby_nail:
			left_nail.emit()
			was_near_nail = false

		nearby_nail = closest_nail

		if nearby_nail:
			near_nail.emit(nearby_nail)
			was_near_nail = true
	elif not closest_nail and was_near_nail:
		left_nail.emit()
		was_near_nail = false
		nearby_nail = null

# --- HANG/UNHANG METHODS ---

func hang_on_nail(nail: NailComponent) -> bool:
	"""Hang this painting on a nail. Returns true if successful."""
	if is_hung:
		return false

	if not nail or nail.is_occupied:
		return false

	if not is_instance_valid(parent_rigid_body):
		return false

	# Drop from player's hands if being carried
	if is_carried and is_instance_valid(player_ref):
		is_carried = false
		if player_ref:
			player_ref.carried_object = null
			player_ref.is_carrying = false

	# Snap to nail position and rotation
	parent_rigid_body.global_position = nail.painting_socket_position
	parent_rigid_body.global_rotation = nail.painting_socket_rotation
	parent_rigid_body.freeze = true  # Lock in place

	# Update state
	is_hung = true
	current_nail = nail
	interaction_text = "Take Down Painting"

	# Clear nearby nail
	nearby_nail = null
	was_near_nail = false

	# Emit signal
	hung_on_nail.emit(nail)

	return true

func unhang() -> bool:
	"""Remove painting from nail (nail will be deleted). Returns true if successful."""
	if not is_hung:
		return false

	if not is_instance_valid(parent_rigid_body):
		return false

	var nail = current_nail

	# Move painting slightly away from wall
	if is_instance_valid(nail):
		var push_dir = (parent_rigid_body.global_position - nail.global_position).normalized()
		parent_rigid_body.global_position += push_dir * UNHANG_OFFSET

	# Restore physics
	parent_rigid_body.freeze = false

	# Give small velocity to prevent sleeping
	parent_rigid_body.linear_velocity = Vector3(0, -0.1, 0)
	parent_rigid_body.angular_velocity = Vector3.ZERO

	# Update state
	is_hung = false
	current_nail = null
	interaction_text = "Pick Up Painting"

	# Emit signal
	unhanged_from_nail.emit(nail)

	return true

# --- OVERRIDE INTERACTION ---

func _on_interacted(player_interaction: PlayerInteractionComponent) -> void:
	"""Override interaction based on hung state"""

	if is_hung:
		# If hung, unhang it AND pick it up in one action
		unhang()
		# Remove the nail (nail will delete itself when painting removed)
		if current_nail:
			current_nail.remove_painting()
		# Then pick up
		pickup(player_interaction)
	elif is_carried and nearby_nail:
		# If carrying near nail, hang it
		if nearby_nail.accept_painting(parent_rigid_body):
			pass  # Nail will call our hang_on_nail() method
	else:
		# Normal pickup/drop behavior
		super._on_interacted(player_interaction)

# --- OVERRIDE DROP ---

func drop() -> void:
	"""Override drop to check for auto-hang"""

	# Check if we should auto-hang
	if auto_hang_on_release and nearby_nail and not is_hung:
		if nearby_nail.accept_painting(parent_rigid_body):
			# Successfully hung, don't drop
			return

	# Normal drop behavior
	super.drop()

	nearby_nail = null
	was_near_nail = false
