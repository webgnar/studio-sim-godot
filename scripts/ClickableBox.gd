extends Node3D
class_name ClickableBox

# --- SIGNALS ---
signal clicked
signal hover_started
signal hover_ended

# --- EXPORTED VARIABLES ---
@export_group("Interaction Settings")
@export var interaction_distance: float = 5.0
@export var hover_sound: AudioStream  # Optional hover sound

@export_group("Box Sounds")
@export var flap_1_open_sound: AudioStream   # Sound for first set of flaps (lid1 & lid2)
@export var flap_2_open_sound: AudioStream   # Sound for second set of flaps (lid3 & lid4)
@export var box_close_sound: AudioStream     # Sound when box closes completely
@export var max_hearing_distance: float = 10.0  # Maximum distance where audio can be heard
@export var min_distance: float = 1.0  # Distance where volume is at maximum
@export var attenuation_model: AudioStreamPlayer3D.AttenuationModel = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

@export_group("Animation Timing")
@export var sequence_buffer: float = 0.3  # Buffer time between lid pair animations

# --- ENUMS ---
enum BoxState {
	CLOSED,        # Box is closed, ready for first click
	OPENING_1,     # First pair of lids opening
	PAIR_1_OPEN,   # First pair open, waiting for second click
	OPENING_2,     # Second pair of lids opening  
	OPEN,          # Box is fully open
	CLOSING_1,     # First closing pair (lid3&lid4) closing
	PAIR_2_CLOSED, # Second pair closed, waiting for next click to close pair 1
	CLOSING_2      # Second closing pair (lid1&lid2) closing
}

# --- SIGNALS ---
signal box_opened        # Emitted when box fully opens
signal box_closed        # Emitted when box closes
signal box_state_changed(new_state: BoxState)

# --- PRIVATE VARIABLES ---
var _is_hovered: bool = false
var _player_camera: Camera3D
var _audio_player: AudioStreamPlayer3D
var _current_state: BoxState = BoxState.CLOSED
var _spawned_object: Node3D = null  # Reference to spawned object

# --- GODOT METHODS ---

func _ready() -> void:
	# Find player camera
	_find_player_camera()
	
	# Setup audio player if we have sounds
	_setup_audio()
	
	print("ClickableBox ready: " + name)

func _process(_delta: float) -> void:
	if not _player_camera:
		return
	
	var was_hovered = _is_hovered
	_is_hovered = _is_looking_at_box()
	
	# Handle hover state changes
	if _is_hovered and not was_hovered:
		_on_hover_started()
	elif was_hovered and not _is_hovered:
		_on_hover_ended()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_hovered:
		return
	
	# Handle mouse click - only when mouse is captured (in game mode)
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# Only interact with box if mouse is captured (not in menu mode)
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_on_clicked()

# --- PRIVATE METHODS ---

func _find_player_camera() -> void:
	# Try to find the player's camera
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_camera = _find_camera_in_node(players[0])
	
	if not _player_camera:
		# Fallback: search for any Camera3D in the scene
		_player_camera = get_viewport().get_camera_3d()
	
	if _player_camera:
		print("Found camera: " + str(_player_camera.get_path()))
	else:
		print("Warning: No camera found for ClickableBox")

func _find_camera_in_node(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	
	for child in node.get_children():
		var camera = _find_camera_in_node(child)
		if camera:
			return camera
	return null

func _setup_audio() -> void:
	if hover_sound or flap_1_open_sound or flap_2_open_sound or box_close_sound:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "BoxAudioPlayer"
		
		# Configure 3D audio distance attenuation
		_audio_player.attenuation_model = attenuation_model
		_audio_player.max_distance = max_hearing_distance
		_audio_player.unit_size = min_distance
		
		# Make it sound realistic in 3D space
		_audio_player.emission_angle_enabled = false  # Omnidirectional sound
		_audio_player.panning_strength = 1.0  # Full stereo panning based on position
		_audio_player.volume_db = 0.0  # Default volume
		
		add_child(_audio_player)
		
		print("📦 Box 3D audio configured - Max distance: " + str(max_hearing_distance) + "m")

func _is_looking_at_box() -> bool:
	if not _player_camera:
		return false
	
	# Cast ray from camera
	var space_state = _player_camera.get_world_3d().direct_space_state
	var from = _player_camera.global_transform.origin
	var to = from + (-_player_camera.global_transform.basis.z * interaction_distance)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result and result.has("collider"):
		var hit_node = result.collider
		# Check if the hit object is part of this box
		return _is_part_of_this_box(hit_node)
	
	return false

func _is_part_of_this_box(node: Node) -> bool:
	# Check if the hit node is this box or a child of this box
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
	print("Hovering over box: " + name)
	
	if hover_sound:
		_play_sound(hover_sound)
	
	hover_started.emit()

func _on_hover_ended() -> void:
	print("Stopped hovering over box: " + name)
	hover_ended.emit()

func _on_clicked() -> void:
	print("Box clicked: " + name + " (Current state: " + str(BoxState.keys()[_current_state]) + ")")
	
	# Handle box interaction based on current state (sounds are played in specific methods)
	_handle_box_interaction()
	
	clicked.emit()

func _handle_box_interaction() -> void:
	match _current_state:
		BoxState.CLOSED:
			_open_lid_pair_1()
		BoxState.OPENING_1:
			# Allow clicking to start pair 2 while pair 1 is still opening (with delay)
			print("Queuing lid pair 2 to open after pair 1 gets a head start...")
			_open_lid_pair_2_with_delay()
		BoxState.PAIR_1_OPEN:
			_open_lid_pair_2()
		BoxState.OPENING_2:
			# Box is already opening pair 2, ignore clicks during animation  
			print("Lid pair 2 is opening, please wait...")
			return
		BoxState.OPEN:
			_close_lid_pair_2()
		BoxState.CLOSING_1:
			# Allow clicking to start closing pair 1 while pair 2 is still closing (with delay)
			print("Queuing lid pair 1 to close after pair 2 gets a head start...")
			_close_lid_pair_1_with_delay()
		BoxState.PAIR_2_CLOSED:
			_close_lid_pair_1()
		BoxState.CLOSING_2:
			# Box is already closing pair 1, ignore clicks during animation
			print("Lid pair 1 is closing, please wait...")
			return

# --- BOX STATE MANAGEMENT ---

func _open_lid_pair_1() -> void:
	print("Opening lid pair 1 (lid1 & lid2)...")
	
	# Play first flap opening sound
	if flap_1_open_sound:
		_play_sound(flap_1_open_sound)
		print("🔊 Playing flap 1 open sound")
	
	_set_state(BoxState.OPENING_1)
	_animate_lid_pair(["lid1", "lid2"])
	
	# Wait for animation to complete, then check current state
	await _wait_for_animations_to_complete()
	
	# Only set to PAIR_1_OPEN if we haven't already started opening pair 2
	if _current_state == BoxState.OPENING_1:
		_set_state(BoxState.PAIR_1_OPEN)
		print("Lid pair 1 open. Click again to open pair 2.")

func _open_lid_pair_2() -> void:
	print("Opening lid pair 2 (lid3 & lid4)...")
	
	# Play second flap opening sound
	if flap_2_open_sound:
		_play_sound(flap_2_open_sound)
		print("🔊 Playing flap 2 open sound")
	
	_set_state(BoxState.OPENING_2)
	_animate_lid_pair(["lid3", "lid4"])
	
	# Wait for animation to complete, then mark as fully open
	await _wait_for_animations_to_complete()
	_set_state(BoxState.OPEN)
	_on_box_fully_opened()

func _open_lid_pair_2_with_delay() -> void:
	# Set state immediately to prevent multiple calls
	_set_state(BoxState.OPENING_2)
	
	# Wait a bit to ensure lid pair 1 gets a head start
	await get_tree().create_timer(sequence_buffer).timeout
	
	print("Opening lid pair 2 (lid3 & lid4) after delay...")
	
	# Play second flap opening sound
	if flap_2_open_sound:
		_play_sound(flap_2_open_sound)
		print("🔊 Playing flap 2 open sound (delayed)")
	
	_animate_lid_pair(["lid3", "lid4"])
	
	# Wait for animation to complete, then mark as fully open
	await _wait_for_animations_to_complete()
	_set_state(BoxState.OPEN)
	_on_box_fully_opened()

func _close_lid_pair_2() -> void:
	print("Closing lid pair 2 (lid3 & lid4)...")
	
	# Play second flap closing sound (reverse of opening)
	if flap_2_open_sound:
		_play_sound(flap_2_open_sound)
		print("🔊 Playing flap 2 close sound")
	
	_set_state(BoxState.CLOSING_1)
	_animate_lid_pair_reverse(["lid3", "lid4"])
	
	# Wait for animation to complete, then check current state
	await _wait_for_animations_to_complete()
	
	# Only set to PAIR_2_CLOSED if we haven't already started closing pair 1
	if _current_state == BoxState.CLOSING_1:
		_set_state(BoxState.PAIR_2_CLOSED)
		print("Lid pair 2 closed. Click again to close pair 1.")

func _close_lid_pair_1() -> void:
	print("Closing lid pair 1 (lid1 & lid2)...")
	
	# Play first flap closing sound (reverse of opening)
	if flap_1_open_sound:
		_play_sound(flap_1_open_sound)
		print("🔊 Playing flap 1 close sound")
	
	_set_state(BoxState.CLOSING_2)
	_animate_lid_pair_reverse(["lid1", "lid2"])
	
	# Wait for animation to complete, then mark as fully closed
	await _wait_for_animations_to_complete()
	_set_state(BoxState.CLOSED)
	_on_box_fully_closed()

func _close_lid_pair_1_with_delay() -> void:
	# Set state immediately to prevent multiple calls
	_set_state(BoxState.CLOSING_2)
	
	# Wait a bit to ensure lid pair 2 gets a head start closing
	await get_tree().create_timer(sequence_buffer).timeout
	
	print("Closing lid pair 1 (lid1 & lid2) after delay...")
	
	# Play first flap closing sound (reverse of opening)
	if flap_1_open_sound:
		_play_sound(flap_1_open_sound)
		print("🔊 Playing flap 1 close sound (delayed)")
	
	_animate_lid_pair_reverse(["lid1", "lid2"])
	
	# Wait for animation to complete, then mark as fully closed
	await _wait_for_animations_to_complete()
	_set_state(BoxState.CLOSED)
	_on_box_fully_closed()

func _animate_lid_pair(lid_names: Array[String]) -> void:
	var animations_started = 0
	for lid_name in lid_names:
		var lid_node = get_node_or_null(lid_name)
		if lid_node:
			var anim_player = _find_animation_player_in_node(lid_node)
			if anim_player and anim_player.has_animation("rotate"):
				anim_player.play("rotate")
				animations_started += 1
			else:
				print("Warning: Animation not found for " + lid_name)
		else:
			print("Warning: Lid node not found: " + lid_name)
	
	if animations_started == 0:
		print("Warning: No animations were started for pair: " + str(lid_names))

func _animate_lid_pair_reverse(lid_names: Array[String]) -> void:
	var animations_started = 0
	for lid_name in lid_names:
		var lid_node = get_node_or_null(lid_name)
		if lid_node:
			var anim_player = _find_animation_player_in_node(lid_node)
			if anim_player and anim_player.has_animation("rotate"):
				# Play animation in reverse to close
				anim_player.play_backwards("rotate")
				animations_started += 1
			else:
				print("Warning: Animation not found for " + lid_name)
		else:
			print("Warning: Lid node not found: " + lid_name)
	
	if animations_started == 0:
		print("Warning: No closing animations started for pair: " + str(lid_names))

func _wait_for_animations_to_complete() -> void:
	# Wait for all currently playing animations to finish
	var all_anim_players = _get_animation_players()
	var playing_animations = []
	
	for anim_player in all_anim_players:
		if anim_player.is_playing():
			playing_animations.append(anim_player)
	
	if playing_animations.size() > 0:
		# Wait for all animations to finish
		for anim_player in playing_animations:
			if anim_player.is_playing():
				await anim_player.animation_finished
	else:
		# Small delay to ensure smooth state transitions
		await get_tree().create_timer(0.1).timeout

func _set_state(new_state: BoxState) -> void:
	_current_state = new_state
	box_state_changed.emit(new_state)

func _on_box_fully_opened() -> void:
	print("🎉 BOX IS FULLY OPEN!")
	
	# Spawn object if not already spawned
	if not _spawned_object:
		_spawn_object()
	
	box_opened.emit()

func _on_box_fully_closed() -> void:
	print("📦 BOX IS CLOSED!")
	
	if box_close_sound:
		_play_sound(box_close_sound)
		print("🔊 Playing box close sound")
	
	# Optionally remove spawned object when box closes
	if _spawned_object:
		_remove_spawned_object()
	
	box_closed.emit()

func _spawn_object() -> void:
	# Placeholder for object spawning - you can customize this
	print("Ready to spawn object from box!")
	
	# Example: Create a simple object above the box
	# var spawned_item = preload("res://scenes/BoxItem.tscn")
	# if spawned_item:
	#     _spawned_object = spawned_item.instantiate()
	#     get_parent().add_child(_spawned_object)
	#     _spawned_object.global_position = global_position + Vector3(0, 2, 0)
	#     print("Object spawned from box!")

func _remove_spawned_object() -> void:
	if _spawned_object and is_instance_valid(_spawned_object):
		print("Removing spawned object...")
		_spawned_object.queue_free()
		_spawned_object = null

func _get_animation_players() -> Array[AnimationPlayer]:
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(self, players)
	return players

func _collect_animation_players(node: Node, collection: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		collection.append(node)
	
	for child in node.get_children():
		_collect_animation_players(child, collection)

func _find_animation_player_in_node(node: Node) -> AnimationPlayer:
	# Look for AnimationPlayer in the specific node
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
	return null

# --- PUBLIC METHODS FOR BOX STATE ---

func get_box_state() -> BoxState:
	return _current_state

func is_box_open() -> bool:
	return _current_state == BoxState.OPEN

func is_box_closed() -> bool:
	return _current_state == BoxState.CLOSED

func is_box_animating() -> bool:
	return _current_state in [BoxState.OPENING_1, BoxState.OPENING_2, BoxState.CLOSING_1, BoxState.CLOSING_2]

func force_close_box() -> void:
	if _current_state == BoxState.OPEN:
		_close_lid_pair_2()

func force_open_box() -> void:
	if _current_state == BoxState.CLOSED:
		_open_lid_pair_1()

# --- PUBLIC METHODS ---

# Connect to this signal to handle box clicks from other scripts
# Example: box.clicked.connect(_on_box_clicked)
func connect_clicked(callable: Callable) -> void:
	clicked.connect(callable)

func set_interaction_distance(distance: float) -> void:
	interaction_distance = distance

func get_distance_to_player() -> float:
	if not _player_camera:
		return 999.0
	return global_transform.origin.distance_to(_player_camera.global_transform.origin)

func set_audio_volume(volume_db: float) -> void:
	if _audio_player:
		_audio_player.volume_db = volume_db
