extends CarryableComponent
class_name PaintingHangingComponent

## Painting hanging component - physics-based hanging via stretcher bar collision
## Paintings rest on nails via gravity and can fall off if bumped

# --- CONSTANTS ---
const RESTING_VELOCITY_THRESHOLD: float = 0.5  ## Consider "resting" below this speed
const RESTING_CONTACT_TIME: float = 0.2  ## Must be in contact this long to consider hung
const NAIL_PEG_LAYER_BIT: int = 5  ## Layer 6 is bit 5 (zero-indexed)
const FLOOR_REST_VELOCITY_THRESHOLD: float = 0.5   ## Combined speed below this = settled on floor
const FLOOR_REST_CONFIRM_TIME: float = 0.3          ## Must be settled this long before auto-freezing
const FLOOR_REST_HARD_TIMEOUT: float = 3.0          ## Always freeze after this many seconds on floor

# --- SIGNALS ---
signal hung_on_nail(nail: NailComponent)
signal unhanged_from_nail(nail: NailComponent)

# --- PRIVATE VARIABLES ---
var current_nail: NailComponent = null
var is_resting_on_nail: bool = false
var contact_nail_count: int = 0
var resting_check_timer: float = 0.0
var is_resting_on_floor: bool = false
var floor_rest_timer: float = 0.0
var floor_time_since_free: float = 0.0

# --- GODOT METHODS ---

func _ready() -> void:
	super._ready()
	interaction_text = "Pick Up Painting"

	# Connect to stretcher bar collision signals (they're Area3D children)
	if parent_rigid_body:
		var stretcher_bars_container = parent_rigid_body.get_node_or_null("StretcherBarsPhysics")
		if stretcher_bars_container:
			# Connect all 4 stretcher bars (Area3D nodes detect other Area3D)
			for bar_name in ["TopBar", "BottomBar", "LeftBar", "RightBar"]:
				var bar = stretcher_bars_container.get_node_or_null(bar_name)
				if bar and bar is Area3D:
					bar.area_entered.connect(_on_stretcher_bar_hit)
					bar.area_exited.connect(_on_stretcher_bar_left)
					print("✓ Connected stretcher bar: ", bar_name)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Check if painting fell off while hung
	if is_resting_on_nail and contact_nail_count == 0:
		# Lost contact - fell off
		is_resting_on_nail = false
		interaction_text = "Pick Up Painting"
		parent_rigid_body.freeze = false
		parent_rigid_body.angular_damp = 3.0
		parent_rigid_body.linear_damp = 2.5
		unhanged_from_nail.emit(current_nail)
		current_nail = null
		floor_rest_timer = 0.0
		print("💥 Painting fell off!")

	# Auto-freeze when settled on floor (prevents twitching and floor penetration)
	if not is_resting_on_nail and not is_carried and not parent_rigid_body.freeze:
		floor_time_since_free += delta
		var speed = parent_rigid_body.linear_velocity.length() + parent_rigid_body.angular_velocity.length()
		if speed < FLOOR_REST_VELOCITY_THRESHOLD:
			floor_rest_timer += delta
		else:
			floor_rest_timer = 0.0
		# Freeze if settled OR hard timeout hit (catches persistent jitter)
		if floor_rest_timer >= FLOOR_REST_CONFIRM_TIME or floor_time_since_free >= FLOOR_REST_HARD_TIMEOUT:
			parent_rigid_body.linear_velocity = Vector3.ZERO
			parent_rigid_body.angular_velocity = Vector3.ZERO
			parent_rigid_body.freeze = true
			is_resting_on_floor = true
	else:
		floor_rest_timer = 0.0
		floor_time_since_free = 0.0

# --- CONTACT DETECTION ---

func _on_stretcher_bar_hit(area: Area3D) -> void:
	"""Called when any stretcher bar Area3D overlaps with nail detection area"""
	# Check if this is the nail's detection area (layer 6 = bit 5)
	if area and (area.collision_layer & (1 << NAIL_PEG_LAYER_BIT)) != 0:
		contact_nail_count += 1
		print("✓ Stretcher bar touched nail! Count: ", contact_nail_count)

		# IMMEDIATELY freeze painting if not already hung and not being carried
		if not is_resting_on_nail and not is_carried:
			# Find nail from the area that was hit
			var nail = _find_nail_from_area(area)
			if nail:
				# DON'T move the painting - just freeze it where it touched!
				# Moving it breaks the overlap with detection area

				# Freeze it in place immediately
				is_resting_on_nail = true
				current_nail = nail
				interaction_text = "Take Down Painting"
				parent_rigid_body.freeze = true
				parent_rigid_body.linear_velocity = Vector3.ZERO
				parent_rigid_body.angular_velocity = Vector3.ZERO
				hung_on_nail.emit(nail)
				print("🎨 PAINTING STUCK TO NAIL!")
			else:
				print("⚠️ Could not find nail from area!")

func _on_stretcher_bar_left(area: Area3D) -> void:
	"""Called when any stretcher bar Area3D stops overlapping"""
	if area and (area.collision_layer & (1 << NAIL_PEG_LAYER_BIT)) != 0:
		contact_nail_count = max(0, contact_nail_count - 1)
		print("✗ Nail peg contact lost. Count: ", contact_nail_count)

# --- HELPER METHODS ---

func _find_nail_from_area(detection_area: Area3D) -> NailComponent:
	"""Find NailComponent from the DetectionArea that triggered contact"""
	# DetectionArea -> NailPeg -> WallNail -> NailComponent
	if detection_area and detection_area.get_parent():
		var nail_peg = detection_area.get_parent()  # NailPeg
		if nail_peg.get_parent():
			var wall_nail = nail_peg.get_parent()  # WallNail
			var nail_component = wall_nail.get_node_or_null("NailComponent")
			if nail_component and nail_component is NailComponent:
				return nail_component
	return null

func _find_nearby_nail() -> NailComponent:
	"""Find the nail we're overlapping with"""
	if not get_tree():
		return null

	var nails = get_tree().get_nodes_in_group("nails")
	for nail in nails:
		if nail is NailComponent:
			var nail_peg = nail.get_node_or_null("../NailPeg")
			if nail_peg and parent_rigid_body:
				var distance = parent_rigid_body.global_position.distance_to(nail_peg.global_position)
				if distance < 0.5:  # Within 50cm
					return nail
	return null

# --- OVERRIDE INTERACTION ---

func _on_interacted(player_interaction: PlayerInteractionComponent) -> void:
	"""Override interaction - reset resting state when picked up"""

	# If painting is frozen on floor, unfreeze so pickup() can carry it
	if is_resting_on_floor:
		is_resting_on_floor = false
		floor_rest_timer = 0.0
		floor_time_since_free = 0.0
		parent_rigid_body.freeze = false

	# If painting is resting on nail, unfreeze and restore damping
	if is_resting_on_nail:
		is_resting_on_nail = false
		parent_rigid_body.freeze = false  # Unfreeze
		parent_rigid_body.angular_damp = 3.0
		parent_rigid_body.linear_damp = 2.5
		interaction_text = "Pick Up Painting"

		# Emit signal and clear nail reference
		if current_nail:
			unhanged_from_nail.emit(current_nail)
			current_nail = null

	# Normal pickup/drop behavior - physics handles everything
	super._on_interacted(player_interaction)
