extends Node3D
class_name ClickableBox

# --- SIGNALS ---
signal clicked
signal hover_started
signal hover_ended

# --- EXPORTED VARIABLES ---
@export_group("Interaction Settings")
@export var interaction_distance: float = 5.0
@export var highlight_on_hover: bool = true
@export var click_sound: AudioStream  # Optional click sound
@export var hover_sound: AudioStream  # Optional hover sound
@export var open_sound: AudioStream   # Sound when box fully opens
@export var close_sound: AudioStream  # Sound when box closes

# --- ENUMS ---
enum BoxState {
	CLOSED,      # Box is closed, ready for first click
	OPENING_1,   # First pair of lids opening
	OPENING_2,   # Second pair of lids opening  
	OPEN,        # Box is fully open
	CLOSING      # Box is closing
}

# --- SIGNALS ---
signal box_opened        # Emitted when box fully opens
signal box_closed        # Emitted when box closes
signal box_state_changed(new_state: BoxState)

# --- PRIVATE VARIABLES ---
var _original_materials: Array = []
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
	
	# Store original materials for highlighting
	if highlight_on_hover:
		_store_original_materials()
	
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
	
	# Handle mouse click
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
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
	if click_sound or hover_sound:
		_audio_player = AudioStreamPlayer3D.new()
		add_child(_audio_player)

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

func _store_original_materials() -> void:
	var mesh_instances = _get_all_mesh_instances()
	_original_materials.clear()
	
	for mesh_instance in mesh_instances:
		var materials = []
		for i in mesh_instance.get_surface_override_material_count():
			materials.append(mesh_instance.get_surface_override_material(i))
		_original_materials.append({
			"mesh": mesh_instance,
			"materials": materials
		})

func _get_all_mesh_instances() -> Array[MeshInstance3D]:
	var instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, instances)
	return instances

func _collect_mesh_instances(node: Node, collection: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		collection.append(node)
	
	for child in node.get_children():
		_collect_mesh_instances(child, collection)

func _highlight_box(enable: bool) -> void:
	if not highlight_on_hover:
		return
	
	var mesh_instances = _get_all_mesh_instances()
	
	if enable:
		# Apply highlight effect
		for mesh_instance in mesh_instances:
			_apply_highlight_to_mesh(mesh_instance)
	else:
		# Restore original materials
		_restore_original_materials()

func _apply_highlight_to_mesh(mesh_instance: MeshInstance3D) -> void:
	# Create a highlighted material
	for i in mesh_instance.get_surface_override_material_count():
		var original_material = mesh_instance.get_surface_override_material(i)
		if original_material and original_material is StandardMaterial3D:
			var highlight_material = original_material.duplicate()
			var std_mat = highlight_material as StandardMaterial3D
			
			# Add emission glow
			std_mat.emission_enabled = true
			std_mat.emission = Color(0.2, 0.2, 1.0)  # Blue glow
			
			mesh_instance.set_surface_override_material(i, highlight_material)

func _restore_original_materials() -> void:
	for material_data in _original_materials:
		var mesh_instance = material_data.mesh
		var materials = material_data.materials
		
		for i in materials.size():
			mesh_instance.set_surface_override_material(i, materials[i])

func _play_sound(sound: AudioStream) -> void:
	if sound and _audio_player:
		_audio_player.stream = sound
		_audio_player.play()

# --- EVENT HANDLERS ---

func _on_hover_started() -> void:
	print("Hovering over box: " + name)
	_highlight_box(true)
	
	if hover_sound:
		_play_sound(hover_sound)
	
	hover_started.emit()

func _on_hover_ended() -> void:
	print("Stopped hovering over box: " + name)
	_highlight_box(false)
	hover_ended.emit()

func _on_clicked() -> void:
	print("Box clicked: " + name + " (Current state: " + str(BoxState.keys()[_current_state]) + ")")
	
	if click_sound:
		_play_sound(click_sound)
	
	# Handle box interaction based on current state
	_handle_box_interaction()
	
	clicked.emit()

func _handle_box_interaction() -> void:
	match _current_state:
		BoxState.CLOSED:
			_start_opening_sequence()
		BoxState.OPENING_1:
			# Box is already opening, ignore clicks during animation
			print("Box is currently opening (pair 1), please wait...")
			return
		BoxState.OPENING_2:
			# Box is already opening, ignore clicks during animation
			print("Box is currently opening (pair 2), please wait...")
			return
		BoxState.OPEN:
			_start_closing_sequence()
		BoxState.CLOSING:
			# Box is already closing, ignore clicks during animation
			print("Box is currently closing, please wait...")
			return

# --- BOX STATE MANAGEMENT ---

func _start_opening_sequence() -> void:
	print("=== STARTING BOX OPENING SEQUENCE ===")
	_set_state(BoxState.OPENING_1)
	print("DEBUG: Starting pair 1 animation...")
	_animate_lid_pair(["lid1", "lid2"])
	
	# Wait for first animation to complete, then start second pair
	print("DEBUG: Waiting for pair 1 animations to complete...")
	await _wait_for_animations_to_complete()
	print("DEBUG: Pair 1 completed, starting pair 2...")
	
	_set_state(BoxState.OPENING_2)
	_animate_lid_pair(["lid3", "lid4"])
	
	# Wait for second animation to complete, then mark as fully open
	print("DEBUG: Waiting for pair 2 animations to complete...")
	await _wait_for_animations_to_complete()
	print("DEBUG: Pair 2 completed, box should be fully open!")
	
	_set_state(BoxState.OPEN)
	_on_box_fully_opened()

func _start_closing_sequence() -> void:
	print("=== STARTING BOX CLOSING SEQUENCE ===")
	_set_state(BoxState.CLOSING)
	
	# Close in reverse order: pair 2 first (lid3, lid4), then pair 1 (lid1, lid2)
	print("DEBUG: Starting closing pair 2 (lid3, lid4)...")
	_animate_lid_pair_reverse(["lid3", "lid4"])
	
	# Wait for first closing animation to complete
	print("DEBUG: Waiting for closing pair 2 to complete...")
	await _wait_for_animations_to_complete()
	print("DEBUG: Closing pair 2 completed, starting closing pair 1...")
	
	_animate_lid_pair_reverse(["lid1", "lid2"])
	
	# Wait for second closing animation to complete
	print("DEBUG: Waiting for closing pair 1 to complete...")
	await _wait_for_animations_to_complete()
	print("DEBUG: All closing animations completed, box should be closed!")
	
	_set_state(BoxState.CLOSED)
	_on_box_fully_closed()

func _animate_lid_pair(lid_names: Array[String]) -> void:
	print("DEBUG: Animating lid pair: " + str(lid_names))
	
	var animations_started = 0
	for lid_name in lid_names:
		print("DEBUG: Looking for lid node: " + lid_name)
		var lid_node = get_node_or_null(lid_name)
		if lid_node:
			print("DEBUG: Found lid node: " + lid_name + " at path: " + str(lid_node.get_path()))
			var anim_player = _find_animation_player_in_node(lid_node)
			if anim_player:
				print("DEBUG: Found animation player: " + str(anim_player.get_path()))
				if anim_player.has_animation("rotate"):
					print("DEBUG: 'rotate' animation exists, starting playback...")
					anim_player.play("rotate")
					animations_started += 1
					print("✓ Started animation for: " + lid_name + " (Length: " + str(anim_player.get_animation("rotate").length) + "s)")
				else:
					print("✗ No 'rotate' animation found for: " + lid_name)
					var available_anims = anim_player.get_animation_library("").get_animation_list()
					print("DEBUG: Available animations: " + str(available_anims))
			else:
				print("✗ Animation player not found in: " + lid_name)
		else:
			print("✗ Lid node not found: " + lid_name)
	
	print("DEBUG: Total animations started: " + str(animations_started))
	if animations_started == 0:
		print("WARNING: No animations were started!")

func _animate_lid_pair_reverse(lid_names: Array[String]) -> void:
	print("Closing lid pair: " + str(lid_names))
	
	var animations_started = 0
	for lid_name in lid_names:
		var lid_node = get_node_or_null(lid_name)
		if lid_node:
			var anim_player = _find_animation_player_in_node(lid_node)
			if anim_player and anim_player.has_animation("rotate"):
				# Play animation in reverse to close
				anim_player.play_backwards("rotate")
				animations_started += 1
				print("✓ Closing lid: " + lid_name)
			else:
				print("✗ Animation player or 'rotate' animation not found for: " + lid_name)
		else:
			print("✗ Lid node not found: " + lid_name)
	
	print("Total closing animations started: " + str(animations_started))

func _wait_for_animations_to_complete() -> void:
	print("DEBUG: _wait_for_animations_to_complete() called")
	
	# Wait for all currently playing animations to finish
	var all_anim_players = _get_animation_players()
	print("DEBUG: Found " + str(all_anim_players.size()) + " total animation players")
	
	var playing_animations = []
	
	for anim_player in all_anim_players:
		print("DEBUG: Checking animation player: " + str(anim_player.get_path()) + " - Playing: " + str(anim_player.is_playing()))
		if anim_player.is_playing():
			playing_animations.append(anim_player)
			print("DEBUG: Added playing animation: " + str(anim_player.get_path()))
	
	print("DEBUG: Total playing animations: " + str(playing_animations.size()))
	
	if playing_animations.size() > 0:
		print("DEBUG: Waiting for " + str(playing_animations.size()) + " animations to complete...")
		
		# Wait for all animations to finish
		for i in range(playing_animations.size()):
			var anim_player = playing_animations[i]
			print("DEBUG: Waiting for animation " + str(i + 1) + "/" + str(playing_animations.size()) + ": " + str(anim_player.get_path()))
			
			if anim_player.is_playing():
				await anim_player.animation_finished
				print("DEBUG: Animation finished: " + str(anim_player.get_path()))
			else:
				print("DEBUG: Animation was no longer playing: " + str(anim_player.get_path()))
		
		print("DEBUG: All animations completed!")
	else:
		print("DEBUG: No animations playing, using fallback timer")
		# Small delay to ensure smooth state transitions
		await get_tree().create_timer(0.1).timeout
		print("DEBUG: Fallback timer completed")

func _set_state(new_state: BoxState) -> void:
	var old_state = _current_state
	_current_state = new_state
	print("Box state changed: " + str(BoxState.keys()[old_state]) + " → " + str(BoxState.keys()[new_state]))
	box_state_changed.emit(new_state)

func _on_box_fully_opened() -> void:
	print("🎉 BOX IS FULLY OPEN!")
	
	if open_sound:
		_play_sound(open_sound)
	
	# Spawn object if not already spawned
	if not _spawned_object:
		_spawn_object()
	
	box_opened.emit()

func _on_box_fully_closed() -> void:
	print("📦 BOX IS CLOSED!")
	
	if close_sound:
		_play_sound(close_sound)
	
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
	return _current_state in [BoxState.OPENING_1, BoxState.OPENING_2, BoxState.CLOSING]

func force_close_box() -> void:
	if _current_state == BoxState.OPEN:
		_start_closing_sequence()

func force_open_box() -> void:
	if _current_state == BoxState.CLOSED:
		_start_opening_sequence()

# --- PUBLIC METHODS ---

# Connect to this signal to handle box clicks from other scripts
# Example: box.clicked.connect(_on_box_clicked)
func connect_clicked(callable: Callable) -> void:
	clicked.connect(callable)

func set_interaction_distance(distance: float) -> void:
	interaction_distance = distance
