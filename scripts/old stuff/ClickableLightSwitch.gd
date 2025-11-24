extends Node3D
class_name ClickableLightSwitch

# --- SIGNALS ---
signal clicked
signal hover_started
signal hover_ended
signal lights_toggled(switch_id: String, is_on: bool)

# --- EXPORTED VARIABLES ---
@export_group("Interaction Settings")
@export var interaction_distance: float = 5.0
@export var switch_id: String = "switch_1"  # Unique ID for this switch
@export var switch_on_sound: AudioStream   # Sound when turning switch ON
@export var switch_off_sound: AudioStream  # Sound when turning switch OFF
@export var hover_sound: AudioStream

@export_group("Light Control")
@export var controlled_light_paths: Array[String] = []  # Paths to lights this switch controls
@export var toggle_animation_name: String = "toggle"  # Name of the switch animation
@export var starts_on: bool = false  # Whether lights start ON or OFF

# --- ENUMS ---
enum SwitchState {
	OFF,
	ON,
	ANIMATING
}

# --- PRIVATE VARIABLES ---
var _is_hovered: bool = false
var _player_camera: Camera3D
var _audio_player: AudioStreamPlayer3D
var _current_state: SwitchState = SwitchState.OFF
var _animation_player: AnimationPlayer
var _controlled_lights: Array[Light3D] = []
var _mesh_instance: MeshInstance3D
var _original_material: Material
var _hover_material: StandardMaterial3D

# --- GODOT METHODS ---

func _ready() -> void:
	# Find player camera
	_find_player_camera()
	
	# Setup audio player
	_setup_audio()
	
	# Find animation player
	_setup_animation_player()
	
	# Find controlled lights
	_setup_controlled_lights()
	
	# Setup hover visual effect
	_setup_hover_effect()
	
	# Initialize lights based on switch starting state
	_initialize_lights_state()
	
	print("ClickableLightSwitch ready: " + name + " (ID: " + switch_id + ")")

func _process(_delta: float) -> void:
	if not _player_camera:
		return
	
	var was_hovered = _is_hovered
	_is_hovered = _is_looking_at_switch()
	
	# Handle hover state changes
	if _is_hovered and not was_hovered:
		_on_hover_started()
	elif was_hovered and not _is_hovered:
		_on_hover_ended()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_hovered or _current_state == SwitchState.ANIMATING:
		return
	
	# Handle mouse click
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_on_clicked()

# --- PRIVATE METHODS ---

func _find_player_camera() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_camera = _find_camera_in_node(players[0])
	
	if not _player_camera:
		_player_camera = get_viewport().get_camera_3d()

func _find_camera_in_node(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	
	for child in node.get_children():
		var camera = _find_camera_in_node(child)
		if camera:
			return camera
	return null

func _setup_audio() -> void:
	if switch_on_sound or switch_off_sound or hover_sound:
		_audio_player = AudioStreamPlayer3D.new()
		add_child(_audio_player)

func _setup_animation_player() -> void:
	# Look for AnimationPlayer in this node or its children
	_animation_player = _find_animation_player_in_node(self)
	if not _animation_player:
		print("Warning: No AnimationPlayer found for light switch: " + name)
	else:
		print("Found AnimationPlayer: " + str(_animation_player.get_path()))
		# List available animations
		var animation_list = _animation_player.get_animation_list()
		print("Available animations: " + str(animation_list))
		
		# Check if our toggle animation exists
		if _animation_player.has_animation(toggle_animation_name):
			print("Toggle animation '" + toggle_animation_name + "' found")
		else:
			print("Warning: Toggle animation '" + toggle_animation_name + "' NOT found")

func _find_animation_player_in_node(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	
	for child in node.get_children():
		var anim_player = _find_animation_player_in_node(child)
		if anim_player:
			return anim_player
	return null

func _setup_controlled_lights() -> void:
	_controlled_lights.clear()
	
	for light_path in controlled_light_paths:
		var light_node = get_node_or_null(light_path)
		if light_node and light_node is Light3D:
			_controlled_lights.append(light_node)
			print("Light switch " + switch_id + " will control: " + light_path)
		else:
			print("Warning: Could not find light at path: " + light_path)
	
	print("Light switch " + switch_id + " controlling " + str(_controlled_lights.size()) + " lights")

func _setup_hover_effect() -> void:
	# Find the MeshInstance3D in this node or its children
	_mesh_instance = _find_mesh_instance_in_node(self)
	
	if _mesh_instance and _mesh_instance.get_surface_override_material_count() > 0:
		_original_material = _mesh_instance.get_surface_override_material(0)
	elif _mesh_instance:
		_original_material = _mesh_instance.material_override
	
	if not _original_material and _mesh_instance and _mesh_instance.mesh:
		# Try to get material from mesh
		var mesh = _mesh_instance.mesh
		if mesh.get_surface_count() > 0:
			_original_material = mesh.surface_get_material(0)
	
	# Create a hover material with emission
	_hover_material = StandardMaterial3D.new()
	if _original_material:
		# Copy properties from original material if it exists
		if _original_material is StandardMaterial3D:
			var orig_std = _original_material as StandardMaterial3D
			_hover_material.albedo_color = orig_std.albedo_color
			_hover_material.albedo_texture = orig_std.albedo_texture
		else:
			_hover_material.albedo_color = Color.WHITE
	else:
		_hover_material.albedo_color = Color.WHITE
	
	# Add bright emission for hover effect
	_hover_material.emission_enabled = true
	_hover_material.emission = Color(0.3, 0.7, 1.0, 1.0)  # Bright cyan glow
	_hover_material.emission_energy = 0.8
	
	print("Hover effect setup for switch: " + name)

func _find_mesh_instance_in_node(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var mesh_instance = _find_mesh_instance_in_node(child)
		if mesh_instance:
			return mesh_instance
	return null

func _initialize_lights_state() -> void:
	# Set the initial switch state
	_current_state = SwitchState.ON if starts_on else SwitchState.OFF
	
	# Set lights to match the starting state
	_toggle_controlled_lights(starts_on)
	
	# Position the switch animation to match the state
	if _animation_player and _animation_player.has_animation(toggle_animation_name):
		if starts_on:
			# Switch starts UP (ON position)
			_animation_player.seek(_animation_player.get_animation(toggle_animation_name).length, true)
		else:
			# Switch starts DOWN (OFF position) 
			_animation_player.seek(0.0, true)
	
	print("💡 Switch " + switch_id + " initialized: " + ("ON" if starts_on else "OFF"))

func _is_looking_at_switch() -> bool:
	if not _player_camera:
		return false
	
	var space_state = _player_camera.get_world_3d().direct_space_state
	var from = _player_camera.global_transform.origin
	var to = from + (-_player_camera.global_transform.basis.z * interaction_distance)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result and result.has("collider"):
		var hit_node = result.collider
		# Debug: Print what we hit
		if hit_node.name.contains("switch"):
			print("Raycast hit switch-related object: " + hit_node.name + " at " + str(hit_node.get_path()))
		return _is_part_of_this_switch(hit_node)
	
	return false

func _is_part_of_this_switch(node: Node) -> bool:
	var current = node
	while current:
		if current == self:
			return true
		current = current.get_parent()
	return false

func _play_sound(sound: AudioStream) -> void:
	if sound and _audio_player:
		_audio_player.stream = sound
		_audio_player.play()

# --- EVENT HANDLERS ---

func _on_hover_started() -> void:
	print("Hovering over light switch: " + switch_id)
	
	# Apply hover visual effect
	if _mesh_instance and _hover_material:
		_mesh_instance.material_override = _hover_material
		print("Applied hover material to switch")
	
	if hover_sound:
		_play_sound(hover_sound)
	
	hover_started.emit()

func _on_hover_ended() -> void:
	print("Stopped hovering over light switch: " + switch_id)
	
	# Remove hover visual effect
	if _mesh_instance:
		_mesh_instance.material_override = _original_material
		print("Removed hover material from switch")
	
	hover_ended.emit()

func _on_clicked() -> void:
	print("Light switch clicked: " + switch_id + " (Current state: " + str(SwitchState.keys()[_current_state]) + ")")
	
	_toggle_switch()
	clicked.emit()

# --- SWITCH CONTROL METHODS ---

func _toggle_switch() -> void:
	if _current_state == SwitchState.ANIMATING:
		return
	
	# Determine new state BEFORE setting to ANIMATING
	var new_state = SwitchState.ON if _current_state != SwitchState.ON else SwitchState.OFF
	var is_turning_on = (new_state == SwitchState.ON)
	
	# Now set to animating
	_current_state = SwitchState.ANIMATING
	
	print("💡 Toggling lights " + ("ON" if is_turning_on else "OFF") + " for switch: " + switch_id)
	
	# Play appropriate sound based on switch direction
	if is_turning_on and switch_on_sound:
		_play_sound(switch_on_sound)
		print("🔊 Playing switch ON sound")
	elif not is_turning_on and switch_off_sound:
		_play_sound(switch_off_sound)
		print("🔊 Playing switch OFF sound")
	
	# Play switch animation
	if _animation_player and _animation_player.has_animation(toggle_animation_name):
		print("Playing animation: " + toggle_animation_name + " " + ("forward" if is_turning_on else "backward"))
		if is_turning_on:
			_animation_player.play(toggle_animation_name)
		else:
			_animation_player.play_backwards(toggle_animation_name)
		
		print("Waiting for animation to finish...")
		await _animation_player.animation_finished
		print("Animation finished!")
	else:
		print("Skipping animation - not found or no animation player")
	
	# Toggle the lights
	_toggle_controlled_lights(is_turning_on)
	
	# Update state
	_current_state = new_state
	
	# Emit signal
	lights_toggled.emit(switch_id, is_turning_on)
	
	print("✅ Switch " + switch_id + " is now " + ("ON" if is_turning_on else "OFF"))

func _toggle_controlled_lights(turn_on: bool) -> void:
	print("_toggle_controlled_lights called with turn_on: " + str(turn_on))
	print("Controlled lights array size: " + str(_controlled_lights.size()))
	
	if _controlled_lights.size() == 0:
		print("ERROR: No controlled lights found!")
		return
		
	for i in range(_controlled_lights.size()):
		var light = _controlled_lights[i]
		if light and is_instance_valid(light):
			light.visible = turn_on
			print("  Light " + light.name + " turned " + ("ON" if turn_on else "OFF"))
		else:
			print("  ERROR: Light at index " + str(i) + " is null or invalid!")

# --- PUBLIC METHODS ---

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
