extends InteractionComponent
class_name ElevatorGateButton

## Button component for opening/closing the elevator gate

const PaintingPromptDialogScene = preload("res://scenes/UI/PaintingPromptDialog.tscn")

@export var elevator_controller: ElevatorController
@export var button_cooldown: float = 0.5

var last_pressed: float = 0.0
var _pending_metadata_check: bool = false

func _ready() -> void:
	super._ready()

	# Try to find elevator controller if not assigned
	if not elevator_controller:
		elevator_controller = _find_elevator_controller()

	# Connect signals and update text
	if elevator_controller:
		elevator_controller.gate_opened.connect(_on_gate_state_changed)
		elevator_controller.gate_closed.connect(_on_gate_closed)
		elevator_controller.painting_entered.connect(_on_painting_changed)
		elevator_controller.painting_exited.connect(_on_painting_changed)
		elevator_controller.foreign_object_entered.connect(_on_foreign_object_changed)
		elevator_controller.foreign_object_exited.connect(_on_foreign_object_changed)
		elevator_controller.gate_clearance_changed.connect(_on_gate_clearance_changed)
		_update_interaction_text()
	else:
		push_warning("ElevatorGateButton: Could not find ElevatorController!")
		interaction_text = "Close Gate"

func _find_elevator_controller() -> ElevatorController:
	# Walk up the tree to find ElevatorController
	var current = get_parent()
	var depth = 0
	while current and depth < 10:
		if current is ElevatorController:
			return current
		if current.has_method("toggle_gate"):
			return current as ElevatorController
		current = current.get_parent()
		depth += 1
	return null

func _on_gate_state_changed() -> void:
	_update_interaction_text()

func _on_gate_closed() -> void:
	_update_interaction_text()

	# Check for missing metadata after the gate finishes closing
	if _pending_metadata_check:
		_pending_metadata_check = false
		var painting = _find_painting_missing_metadata()
		if painting:
			_show_metadata_prompt(painting)

func _on_painting_changed(_painting: CarryablePainting) -> void:
	_update_interaction_text()

func _on_foreign_object_changed(_body: RigidBody3D) -> void:
	_update_interaction_text()

func _process(_delta: float) -> void:
	if elevator_controller and elevator_controller.is_gate_open():
		_update_interaction_text()

func _on_gate_clearance_changed() -> void:
	_update_interaction_text()

func _update_interaction_text() -> void:
	if not elevator_controller:
		interaction_text = "Close Gate"
		return

	if elevator_controller.is_gate_animating() or elevator_controller.is_exporting:
		interaction_text = "..."
		is_disabled = true
	elif elevator_controller.is_gate_open():
		if elevator_controller.has_foreign_objects():
			interaction_text = "Remove Items First"
			is_disabled = true
		elif elevator_controller.has_too_many_paintings():
			interaction_text = "Too Many Paintings"
			is_disabled = true
		elif elevator_controller.is_painting_blocking_gate():
			interaction_text = "Reposition Painting"
			is_disabled = false
		else:
			interaction_text = "Close Gate"
			is_disabled = false
	else:
		interaction_text = "Open Gate"
		is_disabled = false

func interact(player_interaction_component: PlayerInteractionComponent) -> void:
	if is_disabled and elevator_controller:
		if elevator_controller.has_too_many_paintings() or elevator_controller.has_foreign_objects():
			elevator_controller.play_error_sound()
			return
	super.interact(player_interaction_component)

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	# Cooldown check
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_pressed < button_cooldown:
		return

	last_pressed = current_time

	if not elevator_controller:
		push_error("ElevatorGateButton: No elevator controller found!")
		return

	if not elevator_controller.can_toggle_gate():
		return

	# If closing with paintings inside, flag for metadata check after gate closes
	if elevator_controller.is_gate_open() and not elevator_controller.paintings_inside.is_empty():
		_pending_metadata_check = true

	elevator_controller.toggle_gate()
	_play_button_animation()

func _find_painting_missing_metadata() -> CarryablePainting:
	"""Check if any painting in the elevator is missing a title or artist statement"""
	for painting in elevator_controller.paintings_inside:
		if painting.painting_name.strip_edges().is_empty() or painting.artist_statement.strip_edges().is_empty():
			return painting
	return null

func _show_metadata_prompt(painting: CarryablePainting) -> void:
	"""Show the prompt dialog asking player to add metadata"""
	var dialog = PaintingPromptDialogScene.instantiate()
	dialog.setup(painting)
	dialog.dismissed.connect(_on_prompt_dismissed)
	dialog.open_inventory.connect(_on_prompt_open_inventory)
	get_tree().root.add_child(dialog)

func _on_prompt_dismissed() -> void:
	"""Player chose to skip - continue normally"""
	pass

func _on_prompt_open_inventory(painting: CarryablePainting) -> void:
	"""Player chose to add metadata - open inventory to that painting"""
	if UIManager and UIManager.pause_menu and UIManager.pause_menu.has_method("open_to_painting"):
		UIManager.pause_menu.open_to_painting(painting)

func _play_button_animation() -> void:
	# Play button press animation followed by release
	var anim_player = find_animation_player()
	if anim_player and anim_player.has_animation("press"):
		anim_player.play("press")
		await anim_player.animation_finished
		if anim_player.has_animation("release"):
			anim_player.play("release")
