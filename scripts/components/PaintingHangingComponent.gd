extends CarryableComponent
class_name PaintingHangingComponent

## Painting hanging component - physics-based hanging via stretcher bar collision
## Paintings rest on nails via gravity and can fall off if bumped

# --- CONSTANTS ---
const RESTING_VELOCITY_THRESHOLD: float = 0.5  ## Consider "resting" below this speed
const RESTING_CONTACT_TIME: float = 0.2  ## Must be in contact this long to consider hung
const NAIL_PEG_LAYER_BIT: int = 5  ## Layer 6 is bit 5 (zero-indexed)

# --- SIGNALS ---
signal hung_on_nail(nail: NailComponent)
signal unhanged_from_nail(nail: NailComponent)

# --- PRIVATE VARIABLES ---
var current_nail: NailComponent = null
var is_resting_on_nail: bool = false
var contact_nail_count: int = 0
var resting_check_timer: float = 0.0

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

	# Check for resting state when in contact with nail
	if contact_nail_count > 0:
		var velocity = parent_rigid_body.linear_velocity.length()
		if velocity < RESTING_VELOCITY_THRESHOLD:
			resting_check_timer += delta
			if resting_check_timer >= RESTING_CONTACT_TIME and not is_resting_on_nail:
				# Became hung - need to find nail and snap to it
				var nail = _find_nearby_nail()
				if nail:
					# Move painting up slightly to rest ON the nail, not through it
					var nail_peg = nail.get_node_or_null("NailPeg")
					if nail_peg:
						# Position painting so it hangs from the nail (slightly below peg center)
						var hang_offset = Vector3(0, -0.1, 0)  # 10cm below nail peg
						parent_rigid_body.global_position = nail_peg.global_position + hang_offset

					is_resting_on_nail = true
					current_nail = nail
					interaction_text = "Take Down Painting"
					parent_rigid_body.freeze = true  # Lock in place
					hung_on_nail.emit(nail)
					print("🎨 PAINTING HUNG! Position adjusted to nail at: ", parent_rigid_body.global_position)
		else:
			resting_check_timer = 0.0
			if not is_carried:  # Only print if not being carried
				print("⚡ Moving too fast: ", velocity)
	else:
		# No contact with nail
		if is_resting_on_nail:
			# Fell off
			is_resting_on_nail = false
			interaction_text = "Pick Up Painting"
			parent_rigid_body.freeze = false  # Unfreeze
			parent_rigid_body.angular_damp = 3.0  # Restore normal damping
			parent_rigid_body.linear_damp = 2.5  # Restore normal damping
			unhanged_from_nail.emit(current_nail)
			current_nail = null
			print("💥 Painting fell off!")
		else:
			# Not in contact and not hung - restore normal damping
			parent_rigid_body.linear_damp = 2.5
			parent_rigid_body.angular_damp = 3.0
		resting_check_timer = 0.0

# --- CONTACT DETECTION ---

func _on_stretcher_bar_hit(area: Area3D) -> void:
	"""Called when any stretcher bar Area3D overlaps with nail detection area"""
	print("Stretcher bar overlap - Area: ", area.name if area else "null", " Layer: ", area.collision_layer)

	# Check if this is the nail's detection area (layer 6 = bit 5)
	if area and (area.collision_layer & (1 << NAIL_PEG_LAYER_BIT)) != 0:
		contact_nail_count += 1
		print("✓ Nail peg contact! Count: ", contact_nail_count)

		# Immediately slow down the painting when contact detected
		if parent_rigid_body:
			parent_rigid_body.linear_damp = 10.0  # Heavy damping to stop quickly
			parent_rigid_body.angular_damp = 10.0

func _on_stretcher_bar_left(area: Area3D) -> void:
	"""Called when any stretcher bar Area3D stops overlapping"""
	if area and (area.collision_layer & (1 << NAIL_PEG_LAYER_BIT)) != 0:
		contact_nail_count = max(0, contact_nail_count - 1)
		print("✗ Nail peg contact lost. Count: ", contact_nail_count)

# --- HELPER METHODS ---

func _find_nearby_nail() -> NailComponent:
	"""Find the nail we're overlapping with"""
	if not get_tree():
		return null

	var nails = get_tree().get_nodes_in_group("nails")
	for nail in nails:
		if nail is NailComponent:
			var nail_peg = nail.get_node_or_null("NailPeg")
			if nail_peg and parent_rigid_body:
				var distance = parent_rigid_body.global_position.distance_to(nail_peg.global_position)
				if distance < 0.5:  # Within 50cm
					return nail
	return null

# --- OVERRIDE INTERACTION ---

func _on_interacted(player_interaction: PlayerInteractionComponent) -> void:
	"""Override interaction - reset resting state when picked up"""

	# If painting is resting on nail, unfreeze and restore damping
	if is_resting_on_nail:
		is_resting_on_nail = false
		parent_rigid_body.freeze = false  # Unfreeze
		parent_rigid_body.angular_damp = 3.0
		parent_rigid_body.linear_damp = 2.5
		interaction_text = "Pick Up Painting"

	# Normal pickup/drop behavior - physics handles everything
	super._on_interacted(player_interaction)
