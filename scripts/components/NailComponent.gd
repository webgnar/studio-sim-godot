extends Node3D
class_name NailComponent

## Component for wall-mounted nails that serve as painting attachment points
## Pattern similar to OutletComponent - passive socket that paintings plug into

# --- SIGNALS ---
signal painting_hung(painting: CarryablePainting)
signal painting_removed(painting: CarryablePainting)

# --- EXPORTED VARIABLES ---
@export var painting_socket_marker: Marker3D  ## Marker3D that defines where painting snaps to

# --- PRIVATE VARIABLES ---
var is_occupied: bool = false
var hung_painting: CarryablePainting = null
var nail_id: String = ""

# --- COMPUTED PROPERTIES ---
var painting_socket_position: Vector3:
	get:
		if painting_socket_marker:
			return painting_socket_marker.global_position
		return global_position

var painting_socket_rotation: Vector3:
	get:
		if painting_socket_marker:
			return painting_socket_marker.global_rotation
		return global_rotation

# --- GODOT METHODS ---

func _ready() -> void:
	# Generate unique ID for save system
	nail_id = "nail_" + str(get_instance_id())

	# Add to nails group for discovery by PaintingHangingComponent
	add_to_group("nails")

	# Register with WorldStateManager for save/load
	WorldStateManager.register_nail(self, nail_id)

func _exit_tree() -> void:
	# Unregister when removed from scene
	WorldStateManager.unregister_nail(self)

# --- HANG METHODS ---

func accept_painting(painting: CarryablePainting) -> bool:
	"""Accept a painting to hang on this nail. Returns true if successful."""
	if is_occupied:
		return false

	if not painting or not is_instance_valid(painting):
		return false

	# Find and call the hanging component to hang itself
	var hanging_comp = _find_hanging_component(painting)
	if hanging_comp and hanging_comp.hang_on_nail(self):
		is_occupied = true
		hung_painting = painting
		painting_hung.emit(painting)
		return true

	return false

func remove_painting() -> bool:
	"""Remove the hung painting and delete this nail. Returns true if successful."""
	if not is_occupied or not hung_painting:
		return false

	var painting = hung_painting

	# Tell painting to unhang itself
	var hanging_comp = _find_hanging_component(painting)
	if hanging_comp:
		hanging_comp.unhang()

	is_occupied = false
	hung_painting = null
	painting_removed.emit(painting)

	# Delete the nail itself (nail disappears when painting is removed)
	get_parent().queue_free()

	return true

# --- HELPER METHODS ---

func _find_hanging_component(painting: Node) -> Node:
	"""Find PaintingHangingComponent in painting node hierarchy"""
	for child in painting.get_children():
		# Check by class type or duck typing
		if child.has_method("hang_on_nail"):
			return child
	return null
