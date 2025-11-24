extends InteractionComponent
class_name ArtboxInteraction
## Artbox interaction component - handles multi-stage unfolding sequence
## Extends InteractionComponent to inherit common interaction functionality

enum ArtboxState {
	FOLDED,
	MOVING_TO_WALL,
	ORIENTING,
	UNFOLDING,
	COMPLETED
}

signal artbox_unfolded
signal artbox_moved_to_wall

@export_group("Artbox Sounds")
@export var unfold_sound: AudioStream
@export var move_sound: AudioStream
@export var move_sound_fade_in_duration: float = 1.0 ## Fade in time for move sound
@export var move_sound_fade_out_duration: float = 1.0 ## Fade out time for move sound

@export_group("Animation Timing")
@export var fold_sequence_delay: float = 0.5
@export var move_delay: float = 2.0
@export var orient_trigger_time: float = 5.0 ## When to start orienting (seconds into sequence)
@export var unfold_trigger_time: float = 9.0 ## When to start unfolding (seconds into sequence)

var _current_state: ArtboxState = ArtboxState.FOLDED
var _go_to_wall_player: AnimationPlayer
var _orient_to_horizontal_player: AnimationPlayer
var _unfold_animation_players: Array[AnimationPlayer] = []
var _move_sound_played: bool = false ## Track if move sound has been played
var _is_fading_sound: bool = false ## Track if currently fading audio

func _on_ready() -> void:
	# interaction_text set via inspector
	_setup_animation_players()
	print("✅ ArtboxInteraction ready: " + parent_object.name)

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	_handle_artbox_interaction()

func _handle_artbox_interaction() -> void:
	match _current_state:
		ArtboxState.FOLDED:
			_start_complete_sequence()
		ArtboxState.MOVING_TO_WALL:
			print("Artbox is moving to wall, please wait...")
			return
		ArtboxState.ORIENTING:
			print("Artbox is orienting, please wait...")
			return
		ArtboxState.UNFOLDING:
			print("Artbox is unfolding, please wait...")
			return
		ArtboxState.COMPLETED:
			print("Artbox sequence is complete!")
			return

func _setup_animation_players() -> void:
	_go_to_wall_player = find_in_parent("go to wall")
	if not _go_to_wall_player:
		print("Warning: Could not find 'go to wall' animation player")
	else:
		if _go_to_wall_player.is_playing():
			_go_to_wall_player.stop()
		_reset_animation_to_start(_go_to_wall_player)
	
	_orient_to_horizontal_player = find_in_parent("fold6/orient to horizontal T")
	if not _orient_to_horizontal_player:
		print("Warning: Could not find 'orient to horizontal T' animation player")
	else:
		if _orient_to_horizontal_player.is_playing():
			_orient_to_horizontal_player.stop()
		_reset_animation_to_start(_orient_to_horizontal_player)
	
	_collect_unfold_animation_players(parent_object)
	
	for anim_player in _unfold_animation_players:
		if anim_player.is_playing():
			anim_player.stop()
		_reset_animation_to_start(anim_player)
	
	print("Found " + str(_unfold_animation_players.size()) + " unfold animation players")

func _collect_unfold_animation_players(node: Node) -> void:
	if node is AnimationPlayer:
		var anim_player = node as AnimationPlayer
		if ((anim_player.has_animation("fold out") or anim_player.has_animation("foldout")) and anim_player.name == "unfold") or anim_player.name == "unfoldfinal":
			_unfold_animation_players.append(anim_player)
			print("Found unfold animation player: " + str(anim_player.get_path()))
	
	for child in node.get_children():
		_collect_unfold_animation_players(child)

func _reset_animation_to_start(anim_player: AnimationPlayer) -> void:
	if not anim_player:
		return
	anim_player.seek(0.0, true)
	anim_player.advance(0.0)

func _start_complete_sequence() -> void:
	print("🎨 Starting complete artbox sequence...")
	_current_state = ArtboxState.MOVING_TO_WALL
	interaction_text = ""  # Hide prompt during animation
	
	# Start movement immediately (with sound on first click only)
	_start_move_to_wall()
	
	# Schedule orient to trigger at configured time (during movement)
	_schedule_orient_animation()
	
	# Schedule unfold to trigger at configured time (during movement)
	_schedule_unfold_animation()
	
	# Wait for movement to complete
	await _wait_for_move_to_wall_to_complete()
	
	_current_state = ArtboxState.COMPLETED
	interaction_text = "Art Displayed"
	print("✨ Artbox sequence complete!")

func _schedule_orient_animation() -> void:
	await get_tree().create_timer(orient_trigger_time).timeout
	print("🔄 Step 2: Orienting to horizontal (during movement)...")
	_current_state = ArtboxState.ORIENTING
	await _orient_to_horizontal()

func _schedule_unfold_animation() -> void:
	await get_tree().create_timer(unfold_trigger_time).timeout
	print("📂 Step 3: Unfolding panels (during movement)...")
	_current_state = ArtboxState.UNFOLDING
	await _unfold_all_panels()

func _start_move_to_wall() -> void:
	if not _go_to_wall_player:
		print("Warning: Cannot move to wall - no 'go to wall' animation player found")
		return
	
	print("🚀 Step 1: Moving artbox to wall...")
	_current_state = ArtboxState.MOVING_TO_WALL
	
	# Play move sound ONLY on first click with fade in/out
	if move_sound and not _move_sound_played:
		_play_move_sound_with_fade()
		_move_sound_played = true
	
	if _go_to_wall_player.has_animation("move up and rotate"):
		_go_to_wall_player.play("move up and rotate")

func _wait_for_move_to_wall_to_complete() -> void:
	if not _go_to_wall_player:
		return
	
	if _go_to_wall_player.is_playing():
		await _go_to_wall_player.animation_finished
	
	print("✅ Move to wall complete!")
	artbox_moved_to_wall.emit()

func _play_move_sound_with_fade() -> void:
	"""Play move sound with fade in and fade out"""
	if _is_fading_sound:
		return
	
	# Ensure audio player exists
	if not _audio_player:
		print("⚠️ No audio player found, creating one for move sound...")
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "ArtboxAudio"
		_audio_player.max_distance = 30.0
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(_audio_player)
	
	_is_fading_sound = true
	
	# Set the stream and start playing from beginning
	_audio_player.stream = move_sound
	_audio_player.volume_db = -80.0  # Start silent
	_audio_player.play()
	
	print("🔊 Fading in move sound...")
	
	# Fade in
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(_audio_player, "volume_db", -5.0, move_sound_fade_in_duration)
	await fade_in_tween.finished
	
	# Calculate when to start fade out (sound length - fade out duration)
	var sound_length = move_sound.get_length()
	var wait_time = sound_length - move_sound_fade_out_duration - move_sound_fade_in_duration
	
	if wait_time > 0:
		await get_tree().create_timer(wait_time).timeout
	
	print("🔉 Fading out move sound...")
	
	# Fade out
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(_audio_player, "volume_db", -80.0, move_sound_fade_out_duration)
	await fade_out_tween.finished
	
	_audio_player.stop()
	_is_fading_sound = false
	print("🔇 Move sound complete")

func trigger_orient_horizontal() -> void:
	print("🎬 Animation signal: Starting orient to horizontal!")
	_current_state = ArtboxState.ORIENTING
	_orient_to_horizontal()

func trigger_unfold_sequence() -> void:
	print("🎬 Animation signal: Starting unfold at 9 seconds!")
	_current_state = ArtboxState.UNFOLDING
	_unfold_all_panels()

func _orient_to_horizontal() -> void:
	if not _orient_to_horizontal_player:
		push_warning("Cannot orient - no 'orient to horizontal T' animation player found")
		return
	
	_current_state = ArtboxState.ORIENTING
	
	if _orient_to_horizontal_player.has_animation("orient to wall"):
		_orient_to_horizontal_player.play("orient to wall")
		await _orient_to_horizontal_player.animation_finished

func _unfold_all_panels() -> void:
	print("📂 Unfolding all panels...")
	_current_state = ArtboxState.UNFOLDING
	
	if unfold_sound:
		_play_sound(unfold_sound)
	
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
			anim_player.play(anim_name)
			started_animations += 1
	
	if started_animations > 0:
		await _wait_for_unfold_animations_to_complete()
		artbox_unfolded.emit()
	else:
		push_warning("No unfold animations were started!")

func _wait_for_unfold_animations_to_complete() -> void:
	var playing_animations = []
	
	for anim_player in _unfold_animation_players:
		if anim_player.is_playing():
			playing_animations.append(anim_player)
	
	if playing_animations.size() > 0:
		for anim_player in playing_animations:
			if anim_player.is_playing():
				await anim_player.animation_finished
	
	await get_tree().create_timer(0.2).timeout

func get_artbox_state() -> ArtboxState:
	return _current_state

func is_artbox_folded() -> bool:
	return _current_state == ArtboxState.FOLDED

func is_artbox_completed() -> bool:
	return _current_state == ArtboxState.COMPLETED

func is_artbox_animating() -> bool:
	return _current_state in [ArtboxState.MOVING_TO_WALL, ArtboxState.ORIENTING, ArtboxState.UNFOLDING]

func force_start_sequence() -> void:
	if _current_state == ArtboxState.FOLDED:
		_start_complete_sequence()
