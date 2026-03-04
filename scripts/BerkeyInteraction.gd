extends InteractionComponent
class_name BerkeyInteraction

const SNAPPY_DAMPING := 200.0
const EFFECT_DURATION := 30.0

var _original_damping: float = -1.0
var _player_controller: Node3D = null
var _timer: Timer


func _on_ready() -> void:
	interaction_text = "Drink Water"
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_effect_ended)
	add_child(_timer)


func _on_interacted(player_interaction: PlayerInteractionComponent) -> void:
	_player_controller = player_interaction.get_parent()
	if not is_instance_valid(_player_controller) or not "damping" in _player_controller:
		return
	_original_damping = _player_controller.damping
	_player_controller.damping = SNAPPY_DAMPING
	is_disabled = true
	_timer.start(EFFECT_DURATION)


func _on_effect_ended() -> void:
	if is_instance_valid(_player_controller) and _original_damping >= 0.0:
		_player_controller.damping = _original_damping
	is_disabled = false
