extends InteractionComponent
class_name ElevatorGateButton

## Button component for opening/closing the elevator gate

@export var elevator_controller: ElevatorController
@export var button_cooldown: float = 0.5

var last_pressed: float = 0.0

func _ready() -> void:
	super._ready()

	# Try to find elevator controller if not assigned
	if not elevator_controller:
		elevator_controller = _find_elevator_controller()

	# Connect signals and update text
	if elevator_controller:
		elevator_controller.gate_opened.connect(_on_gate_state_changed)
		elevator_controller.gate_closed.connect(_on_gate_state_changed)
		elevator_controller.painting_entered.connect(_on_painting_changed)
		elevator_controller.painting_exited.connect(_on_painting_changed)
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

func _on_painting_changed(_painting: CarryablePainting) -> void:
	_update_interaction_text()

func _update_interaction_text() -> void:
	if not elevator_controller:
		interaction_text = "Close Gate"
		return

	if elevator_controller.is_gate_animating() or elevator_controller.is_exporting:
		interaction_text = "..."
		is_disabled = true
	elif elevator_controller.is_gate_open():
		if elevator_controller.has_too_many_paintings():
			interaction_text = "Too Many Paintings"
			is_disabled = true
		else:
			interaction_text = "Close Gate"
			is_disabled = false
	else:
		interaction_text = "Open Gate"
		is_disabled = false

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

	elevator_controller.toggle_gate()

	# Play button press animation followed by release
	var anim_player = find_animation_player()
	if anim_player and anim_player.has_animation("press"):
		anim_player.play("press")
		await anim_player.animation_finished
		if anim_player.has_animation("release"):
			anim_player.play("release")
