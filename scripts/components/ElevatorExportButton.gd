extends InteractionComponent
class_name ElevatorExportButton

## Button component for the elevator export system
## Only works when gate is closed and a painting is inside

@export var elevator_controller: ElevatorController
@export var button_cooldown: float = 1.0

var last_pressed: float = 0.0

func _ready() -> void:
	super._ready()

	# Try to find elevator controller if not assigned
	if not elevator_controller:
		elevator_controller = _find_elevator_controller()

	# Connect signals and update text
	if elevator_controller:
		elevator_controller.painting_entered.connect(_on_state_changed)
		elevator_controller.painting_exited.connect(_on_state_changed)
		elevator_controller.gate_opened.connect(_on_gate_changed)
		elevator_controller.gate_closed.connect(_on_gate_changed)
		elevator_controller.export_started.connect(_on_export_started)
		elevator_controller.export_completed.connect(_on_export_completed)
		_update_interaction_text()
	else:
		push_warning("ElevatorExportButton: Could not find ElevatorController!")

func _find_elevator_controller() -> ElevatorController:
	# Walk up the tree to find ElevatorController
	var current = get_parent()
	var depth = 0
	while current and depth < 10:
		if current is ElevatorController:
			return current
		if current.has_method("start_export"):
			return current as ElevatorController
		current = current.get_parent()
		depth += 1
	return null

func _on_state_changed(_painting: CarryablePainting) -> void:
	_update_interaction_text()

func _on_gate_changed() -> void:
	_update_interaction_text()

func _on_export_started(_painting: CarryablePainting) -> void:
	interaction_text = "Sending..."
	is_disabled = true

func _on_export_completed(_png_path: String, _glb_path: String) -> void:
	is_disabled = false
	_update_interaction_text()

func _update_interaction_text() -> void:
	if not elevator_controller:
		interaction_text = "No Painting Inside"
		return

	if elevator_controller.is_exporting:
		interaction_text = "Sending..."
		is_disabled = true
	elif elevator_controller.can_export():
		var count = elevator_controller.get_painting_count()
		if count == 1:
			interaction_text = "Send Painting"
		else:
			interaction_text = "Send Painting (1 of %d)" % count
		is_disabled = false
	elif elevator_controller.is_gate_open():
		interaction_text = "Close Gate First"
		is_disabled = true
	elif elevator_controller.get_painting_count() == 0:
		interaction_text = "No Painting Inside"
		is_disabled = true
	else:
		interaction_text = "Send Painting"
		is_disabled = true


func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	# Cooldown check
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_pressed < button_cooldown:
		return

	last_pressed = current_time

	if not elevator_controller:
		push_error("ElevatorExportButton: No elevator controller found!")
		return

	if not elevator_controller.can_export():
		return

	elevator_controller.start_export()

	# Play button press animation followed by release
	var anim_player = find_animation_player()
	if anim_player and anim_player.has_animation("press"):
		anim_player.play("press")
		await anim_player.animation_finished
		if anim_player.has_animation("release"):
			anim_player.play("release")
