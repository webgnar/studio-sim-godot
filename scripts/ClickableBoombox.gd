extends Node3D
class_name ClickableBoombox

# --- SIGNALS ---
signal clicked
signal hover_started
signal hover_ended
signal radio_started(station_name: String)
signal radio_stopped

# --- EXPORTED VARIABLES ---
@export_group("Interaction Settings")
@export var interaction_distance: float = 5.0
@export var boombox_id: String = "boombox_1"

@export_group("Audio Settings")
@export var audio_file: AudioStream  # Single audio file to play
@export var default_volume: float = 0.5
@export var max_hearing_distance: float = 15.0  # Maximum distance where audio can be heard
@export var min_distance: float = 1.0  # Distance where volume is at maximum
@export var attenuation_model: AudioStreamPlayer3D.AttenuationModel = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
@export var click_sound: AudioStream
@export var hover_sound: AudioStream

@export_group("Visual Settings")
@export var power_light_color_on: Color = Color.GREEN
@export var power_light_color_off: Color = Color.RED

# --- ENUMS ---
enum BoomboxState {
	OFF,
	PLAYING,
	LOADING
}

# --- PRIVATE VARIABLES ---
var _is_hovered: bool = false
var _player_camera: Camera3D
var _audio_player: AudioStreamPlayer3D
var _ui_audio_player: AudioStreamPlayer3D  # For click/hover sounds
var _current_state: BoomboxState = BoomboxState.OFF
var _current_station_index: int = 0
var _mesh_instance: MeshInstance3D
var _original_material: Material
var _hover_material: StandardMaterial3D
var _http_request: HTTPRequest

# --- GODOT METHODS ---

func _ready() -> void:
	# Find player camera
	_find_player_camera()
	
	# Setup audio players
	_setup_audio()
	
	# Setup HTTP request for streaming
	_setup_http_request()
	
	# Setup hover visual effect
	_setup_hover_effect()
	
	# Load the audio file if provided
	if audio_file:
		_audio_player.stream = audio_file
		print("Audio file loaded: " + str(audio_file.resource_path))
	else:
		print("No audio file assigned to boombox!")
	
	print("ClickableBoombox ready: " + name + " (ID: " + boombox_id + ")")

func _process(_delta: float) -> void:
	if not _player_camera:
		return
	
	var was_hovered = _is_hovered
	_is_hovered = _is_looking_at_boombox()
	
	# Handle hover state changes
	if _is_hovered and not was_hovered:
		_on_hover_started()
	elif was_hovered and not _is_hovered:
		_on_hover_ended()
	
	# Update distance-based audio (for debugging/monitoring)
	if _current_state == BoomboxState.PLAYING:
		_update_distance_info()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_hovered:
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
	# Main audio player for radio stream
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "RadioPlayer"
	_audio_player.volume_db = linear_to_db(default_volume)
	
	# Configure 3D audio distance attenuation
	_audio_player.attenuation_model = attenuation_model
	_audio_player.max_distance = max_hearing_distance
	_audio_player.unit_size = min_distance
	
	# Make it sound more realistic in 3D space
	_audio_player.emission_angle_enabled = false  # Omnidirectional sound
	_audio_player.panning_strength = 1.0  # Full stereo panning based on position
	
	add_child(_audio_player)
	
	# UI sound effects player (should be quieter and not distance-based)
	if click_sound or hover_sound:
		_ui_audio_player = AudioStreamPlayer3D.new()
		_ui_audio_player.name = "UIAudioPlayer"
		_ui_audio_player.max_distance = 5.0  # UI sounds have shorter range
		_ui_audio_player.volume_db = -10.0  # UI sounds are quieter
		add_child(_ui_audio_player)

func _setup_http_request() -> void:
	_http_request = HTTPRequest.new()
	_http_request.name = "HTTPRequest"
	_http_request.timeout = 10.0  # 10 second timeout
	add_child(_http_request)

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
	_hover_material.emission = Color(1.0, 0.5, 0.0, 1.0)  # Orange glow for boombox
	_hover_material.emission_energy = 0.6
	
	print("Hover effect setup for boombox: " + name)

func _find_mesh_instance_in_node(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var mesh_instance = _find_mesh_instance_in_node(child)
		if mesh_instance:
			return mesh_instance
	return null



func _is_looking_at_boombox() -> bool:
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
		if hit_node.name.contains("boombox"):
			print("Raycast hit boombox-related object: " + hit_node.name + " at " + str(hit_node.get_path()))
		return _is_part_of_this_boombox(hit_node)
	
	return false

func _is_part_of_this_boombox(node: Node) -> bool:
	var current = node
	while current:
		if current == self:
			return true
		current = current.get_parent()
	return false

func _play_ui_sound(sound: AudioStream) -> void:
	if sound and _ui_audio_player:
		_ui_audio_player.stream = sound
		_ui_audio_player.play()

# --- EVENT HANDLERS ---

func _on_hover_started() -> void:
	print("Hovering over boombox: " + boombox_id)
	
	# Apply hover visual effect
	if _mesh_instance and _hover_material:
		_mesh_instance.material_override = _hover_material
		print("Applied hover material to boombox")
	
	if hover_sound:
		_play_ui_sound(hover_sound)
	
	hover_started.emit()

func _on_hover_ended() -> void:
	print("Stopped hovering over boombox: " + boombox_id)
	
	# Remove hover visual effect
	if _mesh_instance:
		_mesh_instance.material_override = _original_material
		print("Removed hover material from boombox")
	
	hover_ended.emit()

func _on_clicked() -> void:
	print("Boombox clicked: " + boombox_id + " (Current state: " + str(BoomboxState.keys()[_current_state]) + ")")
	
	if click_sound:
		_play_ui_sound(click_sound)
	
	_toggle_radio()
	clicked.emit()

# --- RADIO CONTROL METHODS ---

func _toggle_radio() -> void:
	match _current_state:
		BoomboxState.OFF:
			# Check if audio is paused vs completely stopped
			if _audio_player and _audio_player.stream_paused:
				_resume_audio()
			else:
				_start_audio()
		BoomboxState.PLAYING:
			_stop_audio()
		BoomboxState.LOADING:
			print("Audio is loading, please wait...")

func _start_audio() -> void:
	if not audio_file:
		print("❌ No audio file assigned to boombox!")
		return
	
	if not _audio_player.stream:
		_audio_player.stream = audio_file
	
	print("🎵 Starting audio: " + str(audio_file.resource_path))
	_audio_player.play()
	_current_state = BoomboxState.PLAYING
	radio_started.emit("Halloween Audio")
	print("✅ Now playing audio")

func _stop_audio() -> void:
	if _audio_player and _audio_player.playing:
		print("⏸️ Pausing audio (will resume from current position)")
		_audio_player.stream_paused = true
		_current_state = BoomboxState.OFF
		radio_stopped.emit()
		print("📻 Audio paused")

func _resume_audio() -> void:
	if _audio_player and _audio_player.stream_paused:
		print("▶️ Resuming audio from paused position")
		_audio_player.stream_paused = false
		_current_state = BoomboxState.PLAYING
		radio_started.emit("Halloween Audio")
		print("✅ Audio resumed")

# --- PUBLIC METHODS ---

func get_radio_state() -> BoomboxState:
	return _current_state

func is_radio_playing() -> bool:
	return _current_state == BoomboxState.PLAYING

func set_volume(volume: float) -> void:
	if _audio_player:
		_audio_player.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))

func get_audio_name() -> String:
	if audio_file:
		return audio_file.resource_path.get_file()
	return "No Audio File"

func get_distance_to_player() -> float:
	if not _player_camera:
		return 999.0
	return global_transform.origin.distance_to(_player_camera.global_transform.origin)

func _update_distance_info() -> void:
	# This runs every frame when radio is playing, for monitoring
	var distance = get_distance_to_player()
	
	# Optional: Print distance info every few seconds for debugging
	# Uncomment the next 3 lines if you want to see distance info in console
	# if Engine.get_process_frames() % 180 == 0:  # Every ~3 seconds at 60fps
	#     print("📻 Distance to boombox: " + str(distance) + "m (max: " + str(max_hearing_distance) + "m)")
	
	# The AudioStreamPlayer3D automatically handles volume attenuation based on distance
	# But you could add custom effects here if needed