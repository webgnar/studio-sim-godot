extends InteractionComponent
class_name LightSwitchInteraction
## Light switch interaction component - handles toggling lights on/off
## Extends InteractionComponent to inherit common interaction functionality

enum SwitchState {
	OFF,
	ON,
	ANIMATING
}

signal lights_toggled(switch_id: String, is_on: bool)

@export_group("Light Switch Settings")
@export var switch_id: String = "switch_1"
@export var switch_on_sound: AudioStream
@export var switch_off_sound: AudioStream
@export var controlled_light_paths: Array[String] = []
@export var toggle_animation_name: String = "toggle"
@export var starts_on: bool = false

var _current_state: SwitchState = SwitchState.OFF
var _animation_player: AnimationPlayer
var _controlled_lights: Array[Light3D] = []
var _default_interaction_text: String = ""  # Store inspector value

func _on_ready() -> void:
	# Store the inspector value before any changes
	_default_interaction_text = interaction_text if interaction_text != "" else "Toggle Switch"
	_ensure_audio_player()
	_setup_animation_player()
	_setup_controlled_lights()
	_initialize_lights_state()

func _ensure_audio_player() -> void:
	# Make sure we have an audio player for switch sounds
	if (switch_on_sound or switch_off_sound) and not _audio_player:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "SwitchAudio"
		_audio_player.max_distance = 10.0
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_audio_player.bus = "SFX"
		add_child(_audio_player)

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	if _current_state != SwitchState.ANIMATING:
		_toggle_switch()

func _setup_animation_player() -> void:
	_animation_player = find_animation_player()
	if not _animation_player:
		push_warning("No AnimationPlayer found for light switch: " + parent_object.name)
	elif not _animation_player.has_animation(toggle_animation_name):
		push_warning("Toggle animation '" + toggle_animation_name + "' NOT found on " + parent_object.name)

func _setup_controlled_lights() -> void:
	_controlled_lights.clear()

	for light_path in controlled_light_paths:
		# Try the path as-is first
		var light_node = get_node_or_null(light_path)

		# If not found, try from parent_object
		if not light_node:
			light_node = parent_object.get_node_or_null(light_path)

		if light_node and light_node is Light3D:
			_controlled_lights.append(light_node)
		else:
			push_warning("Could not find light at path: " + light_path)

func _initialize_lights_state() -> void:
	_current_state = SwitchState.ON if starts_on else SwitchState.OFF

	_toggle_controlled_lights(starts_on)

	if _animation_player and _animation_player.has_animation(toggle_animation_name):
		if starts_on:
			# Seek to end of animation (ON position)
			var anim_length = _animation_player.get_animation(toggle_animation_name).length
			_animation_player.play(toggle_animation_name)
			_animation_player.seek(anim_length, true)
			_animation_player.pause()
		else:
			# Seek to start of animation (OFF position)
			_animation_player.play(toggle_animation_name)
			_animation_player.seek(0.0, true)
			_animation_player.pause()

func _toggle_switch() -> void:
	if _current_state == SwitchState.ANIMATING:
		return

	var new_state = SwitchState.ON if _current_state != SwitchState.ON else SwitchState.OFF
	var is_turning_on = (new_state == SwitchState.ON)

	_current_state = SwitchState.ANIMATING
	interaction_text = ""  # Hide prompt during animation

	if is_turning_on and switch_on_sound:
		_play_sound(switch_on_sound)
	elif not is_turning_on and switch_off_sound:
		_play_sound(switch_off_sound)

	if _animation_player and _animation_player.has_animation(toggle_animation_name):
		if is_turning_on:
			_animation_player.play(toggle_animation_name)
		else:
			_animation_player.play_backwards(toggle_animation_name)

		await _animation_player.animation_finished

	_toggle_controlled_lights(is_turning_on)

	_current_state = new_state
	interaction_text = _default_interaction_text  # Restore inspector value

	lights_toggled.emit(switch_id, is_turning_on)

func _toggle_controlled_lights(turn_on: bool) -> void:
	if _controlled_lights.size() == 0:
		push_warning("Switch " + switch_id + " has no controlled lights!")
		return

	for light in _controlled_lights:
		if light and is_instance_valid(light):
			light.visible = turn_on

func get_switch_state() -> SwitchState:
	return _current_state

func is_switch_on() -> bool:
	return _current_state == SwitchState.ON

func force_switch_on() -> void:
	if _current_state != SwitchState.ON:
		_toggle_switch()

func force_switch_off() -> void:
	if _current_state != SwitchState.OFF:
		_toggle_switch()

func add_controlled_light(light_path: String) -> void:
	controlled_light_paths.append(light_path)
	_setup_controlled_lights()

func set_switch_id(new_id: String) -> void:
	switch_id = new_id
