extends Node3D
class_name ClickableArtbox

# --- SIGNALS ---
signal clicked
signal hover_started  
signal hover_ended
signal artbox_unfolded
signal artbox_moved_to_wall

# --- EXPORTED VARIABLES ---
@export_group("Interaction Settings")
@export var interaction_distance: float = 5.0
@export var click_sound: AudioStream  # Optional click sound
@export var hover_sound: AudioStream  # Optional hover sound
@export var unfold_sound: AudioStream # Sound when artbox unfolds
@export var move_sound: AudioStream   # Sound when artbox moves to wall

@export_group("Animation Timing")
@export var fold_sequence_delay: float = 0.5  # Delay between fold animations
@export var move_delay: float = 2.0  # Delay before moving to wall

# --- ENUMS ---
enum ArtboxState {
	FOLDED,        # Artbox is folded, ready for click
	MOVING_TO_WALL, # "go to wall" animation playing
	ORIENTING,     # "orient to horizontal T" animation playing
	UNFOLDING,     # All unfold animations playing
	COMPLETED      # All animations complete
}

# --- PRIVATE VARIABLES ---
var _is_hovered: bool = false
var _player_camera: Camera3D
var _audio_player: AudioStreamPlayer3D
var _current_state: ArtboxState = ArtboxState.FOLDED

# Animation references
var _go_to_wall_player: AnimationPlayer
var _orient_to_horizontal_player: AnimationPlayer
var _unfold_animation_players: Array[AnimationPlayer] = []

# --- GODOT METHODS ---

func _ready() -> void:
	# Find player camera
	_find_player_camera()
	
	# Setup audio player if we have sounds
	_setup_audio()
	
	# Find animation players
	_setup_animation_players()
	
	print("ClickableArtbox ready: " + name)

func _process(_delta: float) -> void:
	if not _player_camera:
		return
	
	var was_hovered = _is_hovered
	_is_hovered = _is_looking_at_artbox()
	
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
			# Only interact if mouse is captured (not in menu mode)
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
		print("Warning: No camera found for ClickableArtbox")

func _find_camera_in_node(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	
	for child in node.get_children():
		var camera = _find_camera_in_node(child)
		if camera:
			return camera
	return null

func _setup_audio() -> void:
	if click_sound or hover_sound or unfold_sound or move_sound:
		_audio_player = AudioStreamPlayer3D.new()
		add_child(_audio_player)

func _setup_animation_players() -> void:
	# Find the "go to wall" animation player
	_go_to_wall_player = get_node_or_null("go to wall")
	if not _go_to_wall_player:
		print("Warning: Could not find 'go to wall' animation player")
	else:
		# Stop the animation if it's playing and reset to beginning
		if _go_to_wall_player.is_playing():
			_go_to_wall_player.stop()
		# Reset to starting position
		_reset_animation_to_start(_go_to_wall_player)
	
	# Find the "orient to horizontal T" animation player (in fold6)
	_orient_to_horizontal_player = get_node_or_null("fold6/orient to horizontal T")
	if not _orient_to_horizontal_player:
		print("Warning: Could not find 'orient to horizontal T' animation player")
	else:
		# Stop the animation if it's playing and reset
		if _orient_to_horizontal_player.is_playing():
			_orient_to_horizontal_player.stop()
		_reset_animation_to_start(_orient_to_horizontal_player)
	
	# Collect all unfold animation players and stop their autoplay
	_collect_unfold_animation_players(self)
	
	# Stop all unfold animations that might be autoplaying and reset them
	for anim_player in _unfold_animation_players:
		if anim_player.is_playing():
			anim_player.stop()
		# Reset to beginning of animation
		_reset_animation_to_start(anim_player)
	
	print("Found " + str(_unfold_animation_players.size()) + " unfold animation players")

func _collect_unfold_animation_players(node: Node) -> void:
	# Look for AnimationPlayer nodes that have unfold animations (not the orient one)
	if node is AnimationPlayer:
		var anim_player = node as AnimationPlayer
		# Collect unfold animations and the special "unfoldfinal" animation
		if ((anim_player.has_animation("fold out") or anim_player.has_animation("foldout")) and anim_player.name == "unfold") or anim_player.name == "unfoldfinal":
			_unfold_animation_players.append(anim_player)
			print("Found unfold animation player: " + str(anim_player.get_path()))
	
	for child in node.get_children():
		_collect_unfold_animation_players(child)

func _reset_animation_to_start(anim_player: AnimationPlayer) -> void:
	if not anim_player:
		return
	# Seek to start and force update
	anim_player.seek(0.0, true)
	anim_player.advance(0.0)

func _is_looking_at_artbox() -> bool:
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
		# Check if the hit object is part of this artbox
		return _is_part_of_this_artbox(hit_node)
	
	return false

func _is_part_of_this_artbox(node: Node) -> bool:
	# Check if the hit node is this artbox or a child of this artbox
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

# This function will be called by the animation to trigger orient step
func trigger_orient_horizontal():
	print("🎬 Animation signal: Starting orient to horizontal!")
	_current_state = ArtboxState.ORIENTING
	_orient_to_horizontal()

# This function will be called by the animation at the 9-second mark
func trigger_unfold_sequence():
	print("🎬 Animation signal: Starting unfold at 9 seconds!")
	_current_state = ArtboxState.UNFOLDING
	_unfold_all_panels()

# --- EVENT HANDLERS ---

func _on_hover_started() -> void:
	print("Hovering over artbox: " + name)
	
	if hover_sound:
		_play_sound(hover_sound)
	
	hover_started.emit()

func _on_hover_ended() -> void:
	print("Stopped hovering over artbox: " + name)
	hover_ended.emit()

func _on_clicked() -> void:
	print("Artbox clicked: " + name + " (Current state: " + str(ArtboxState.keys()[_current_state]) + ")")
	
	if click_sound:
		_play_sound(click_sound)
	
	# Handle artbox interaction based on current state
	_handle_artbox_interaction()
	
	clicked.emit()

func _handle_artbox_interaction() -> void:
	match _current_state:
		ArtboxState.FOLDED:
			_start_complete_sequence()
		ArtboxState.MOVING_TO_WALL:
			# Artbox is moving to wall, ignore clicks
			print("Artbox is moving to wall, please wait...")
			return
		ArtboxState.ORIENTING:
			# Artbox is orienting, ignore clicks
			print("Artbox is orienting, please wait...")
			return
		ArtboxState.UNFOLDING:
			# Artbox is unfolding, ignore clicks
			print("Artbox is unfolding, please wait...")
			return
		ArtboxState.COMPLETED:
			# Could implement reset or other interactions here
			print("Artbox sequence is complete!")
			return

# --- ARTBOX ANIMATION METHODS ---

func _start_complete_sequence() -> void:
	print("🎨 Starting complete artbox sequence...")
	_current_state = ArtboxState.MOVING_TO_WALL
	
	# Step 1: Start the move to wall animation (contains orient + method call for unfolds)
	_start_move_to_wall()
	
	# Step 2: Wait for the entire move to wall animation to finish
	await _wait_for_move_to_wall_to_complete()
	
	_current_state = ArtboxState.COMPLETED
	print("✨ Artbox sequence complete!")

func _start_move_to_wall() -> void:
	if not _go_to_wall_player:
		print("Warning: Cannot move to wall - no 'go to wall' animation player found")
		return
	
	print("🚀 Step 1: Moving artbox to wall...")
	_current_state = ArtboxState.MOVING_TO_WALL
	
	if move_sound:
		_play_sound(move_sound)
	
	# Start the "move up and rotate" animation (don't await)
	if _go_to_wall_player.has_animation("move up and rotate"):
		_go_to_wall_player.play("move up and rotate")

func _wait_for_move_to_wall_to_complete() -> void:
	if not _go_to_wall_player:
		return
	
	# Wait for the "go to wall" animation to finish
	if _go_to_wall_player.is_playing():
		await _go_to_wall_player.animation_finished
	
	print("✅ Move to wall complete!")
	artbox_moved_to_wall.emit()

func _orient_to_horizontal() -> void:
	if not _orient_to_horizontal_player:
		print("Warning: Cannot orient - no 'orient to horizontal T' animation player found")
		return
	
	print("🔄 Step 2: Orienting to horizontal...")
	_current_state = ArtboxState.ORIENTING
	
	# Start the "orient to wall" animation
	if _orient_to_horizontal_player.has_animation("orient to wall"):
		_orient_to_horizontal_player.play("orient to wall")
		await _orient_to_horizontal_player.animation_finished
	
	print("✅ Orient to horizontal complete!")

func _unfold_all_panels() -> void:
	print("📂 Step 3: Unfolding all panels simultaneously...")
	_current_state = ArtboxState.UNFOLDING
	
	if unfold_sound:
		_play_sound(unfold_sound)
	
	# Start all unfold animations at the same time
	var started_animations = 0
	for anim_player in _unfold_animation_players:
		var anim_name = ""
		if anim_player.has_animation("fold out"):
			anim_name = "fold out"
		elif anim_player.has_animation("foldout"):
			anim_name = "foldout"
		elif anim_player.name == "unfoldfinal" and anim_player.has_animation("fold out"):
			anim_name = "fold out"
		
		if anim_name != "":
			print("Playing animation: " + anim_name + " on " + str(anim_player.get_path()))
			anim_player.play(anim_name)
			started_animations += 1
	
	print("Started " + str(started_animations) + " unfold animations")
	
	# Wait for all unfold animations to complete
	await _wait_for_unfold_animations_to_complete()
	
	print("✅ All panels unfolded!")
	artbox_unfolded.emit()

func _wait_for_unfold_animations_to_complete() -> void:
	# Wait for all unfold animations to finish
	var playing_animations = []
	
	for anim_player in _unfold_animation_players:
		if anim_player.is_playing():
			playing_animations.append(anim_player)
	
	if playing_animations.size() > 0:
		print("Waiting for " + str(playing_animations.size()) + " unfold animations to complete...")
		
		# Wait for all animations to finish
		for anim_player in playing_animations:
			if anim_player.is_playing():
				await anim_player.animation_finished
	
	# Small buffer to ensure smooth state transitions
	await get_tree().create_timer(0.2).timeout

# --- PUBLIC METHODS ---

func get_artbox_state() -> ArtboxState:
	return _current_state

func is_artbox_folded() -> bool:
	return _current_state == ArtboxState.FOLDED

func is_artbox_completed() -> bool:
	return _current_state == ArtboxState.COMPLETED

func is_artbox_animating() -> bool:
	return _current_state in [ArtboxState.MOVING_TO_WALL, ArtboxState.ORIENTING, ArtboxState.UNFOLDING]

# Force methods for testing or external control
func force_start_sequence() -> void:
	if _current_state == ArtboxState.FOLDED:
		_start_complete_sequence()

# Connect to signals from other scripts
func connect_clicked(callable: Callable) -> void:
	clicked.connect(callable)

func connect_unfolded(callable: Callable) -> void:
	artbox_unfolded.connect(callable)

func connect_moved_to_wall(callable: Callable) -> void:
	artbox_moved_to_wall.connect(callable)

func set_interaction_distance(distance: float) -> void:
	interaction_distance = distance
