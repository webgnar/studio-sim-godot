extends InteractionComponent
class_name BoxInteraction
## Box interaction component - handles multi-stage box opening/closing
## Extends InteractionComponent to inherit common interaction functionality
## This replaces the old ClickableBox system with a cleaner component-based approach

enum BoxState {
	CLOSED,
	OPENING_1,
	PAIR_1_OPEN,
	OPENING_2,
	OPEN,
	CLOSING_1,
	PAIR_2_CLOSED,
	CLOSING_2
}

signal box_opened
signal box_closed
signal box_state_changed(new_state: BoxState)

@export_group("Box Sounds")
@export var flap_1_open_sound: AudioStream
@export var flap_2_open_sound: AudioStream
@export var box_close_sound: AudioStream

@export_group("Animation Timing")
@export var sequence_buffer: float = 0.3

var _current_state: BoxState = BoxState.CLOSED
var _spawned_object: Node3D = null

func _on_ready() -> void:
	interaction_text = "Open Box"
	_ensure_audio_player()
	print("✅ BoxInteraction ready: " + parent_object.name)

func _ensure_audio_player() -> void:
	"""Make sure we have an audio player for box sounds"""
	if (flap_1_open_sound or flap_2_open_sound or box_close_sound) and not _audio_player:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "BoxAudio"
		_audio_player.max_distance = 15.0
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(_audio_player)
		print("Created audio player for box sounds")

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	_handle_box_interaction()

func _handle_box_interaction() -> void:
	match _current_state:
		BoxState.CLOSED:
			_open_lid_pair_1()
		BoxState.OPENING_1:
			print("Queuing lid pair 2 to open after pair 1 gets a head start...")
			_open_lid_pair_2_with_delay()
		BoxState.PAIR_1_OPEN:
			_open_lid_pair_2()
		BoxState.OPENING_2:
			print("Lid pair 2 is opening, please wait...")
			return
		BoxState.OPEN:
			_close_lid_pair_2()
		BoxState.CLOSING_1:
			print("Queuing lid pair 1 to close after pair 2 gets a head start...")
			_close_lid_pair_1_with_delay()
		BoxState.PAIR_2_CLOSED:
			_close_lid_pair_1()
		BoxState.CLOSING_2:
			print("Lid pair 1 is closing, please wait...")
			return

func _open_lid_pair_1() -> void:
	print("Opening lid pair 1 (lid1 & lid2)...")
	
	if flap_1_open_sound:
		_play_sound(flap_1_open_sound)
		print("🔊 Playing flap 1 open sound")
	
	_set_state(BoxState.OPENING_1)
	_animate_lid_pair(["lid1", "lid2"])
	
	await _wait_for_animations_to_complete()
	
	if _current_state == BoxState.OPENING_1:
		_set_state(BoxState.PAIR_1_OPEN)
		interaction_text = "Open Further"
		emit_state_change("PAIR_1_OPEN")
		print("Lid pair 1 open. Click again to open pair 2.")

func _open_lid_pair_2() -> void:
	print("Opening lid pair 2 (lid3 & lid4)...")
	
	if flap_2_open_sound:
		_play_sound(flap_2_open_sound)
		print("🔊 Playing flap 2 open sound")
	
	_set_state(BoxState.OPENING_2)
	_animate_lid_pair(["lid3", "lid4"])
	
	await _wait_for_animations_to_complete()
	_set_state(BoxState.OPEN)
	_on_box_fully_opened()

func _open_lid_pair_2_with_delay() -> void:
	_set_state(BoxState.OPENING_2)
	
	await get_tree().create_timer(sequence_buffer).timeout
	
	print("Opening lid pair 2 (lid3 & lid4) after delay...")
	
	if flap_2_open_sound:
		_play_sound(flap_2_open_sound)
		print("🔊 Playing flap 2 open sound (delayed)")
	
	_animate_lid_pair(["lid3", "lid4"])
	
	await _wait_for_animations_to_complete()
	_set_state(BoxState.OPEN)
	_on_box_fully_opened()

func _close_lid_pair_2() -> void:
	print("Closing lid pair 2 (lid3 & lid4)...")
	
	if flap_2_open_sound:
		_play_sound(flap_2_open_sound)
		print("🔊 Playing flap 2 close sound")
	
	_set_state(BoxState.CLOSING_1)
	_animate_lid_pair_reverse(["lid3", "lid4"])
	
	await _wait_for_animations_to_complete()
	
	if _current_state == BoxState.CLOSING_1:
		_set_state(BoxState.PAIR_2_CLOSED)
		interaction_text = "Close Further"
		emit_state_change("PAIR_2_CLOSED")
		print("Lid pair 2 closed. Click again to close pair 1.")

func _close_lid_pair_1() -> void:
	print("Closing lid pair 1 (lid1 & lid2)...")
	
	if flap_1_open_sound:
		_play_sound(flap_1_open_sound)
		print("🔊 Playing flap 1 close sound")
	
	_set_state(BoxState.CLOSING_2)
	_animate_lid_pair_reverse(["lid1", "lid2"])
	
	await _wait_for_animations_to_complete()
	_set_state(BoxState.CLOSED)
	_on_box_fully_closed()

func _close_lid_pair_1_with_delay() -> void:
	_set_state(BoxState.CLOSING_2)
	
	await get_tree().create_timer(sequence_buffer).timeout
	
	print("Closing lid pair 1 (lid1 & lid2) after delay...")
	
	if flap_1_open_sound:
		_play_sound(flap_1_open_sound)
		print("🔊 Playing flap 1 close sound (delayed)")
	
	_animate_lid_pair_reverse(["lid1", "lid2"])
	
	await _wait_for_animations_to_complete()
	_set_state(BoxState.CLOSED)
	_on_box_fully_closed()

func _animate_lid_pair(lid_names: Array[String]) -> void:
	var animations_started = 0
	for lid_name in lid_names:
		var lid_node = find_in_parent(lid_name)
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
		var lid_node = find_in_parent(lid_name)
		if lid_node:
			var anim_player = _find_animation_player_in_node(lid_node)
			if anim_player and anim_player.has_animation("rotate"):
				anim_player.play_backwards("rotate")
				animations_started += 1
			else:
				print("Warning: Animation not found for " + lid_name)
		else:
			print("Warning: Lid node not found: " + lid_name)
	
	if animations_started == 0:
		print("Warning: No closing animations started for pair: " + str(lid_names))

func _wait_for_animations_to_complete() -> void:
	var all_anim_players = _get_animation_players()
	var playing_animations = []
	
	for anim_player in all_anim_players:
		if anim_player.is_playing():
			playing_animations.append(anim_player)
	
	if playing_animations.size() > 0:
		for anim_player in playing_animations:
			if anim_player.is_playing():
				await anim_player.animation_finished
	else:
		await get_tree().create_timer(0.1).timeout

func _set_state(new_state: BoxState) -> void:
	_current_state = new_state
	box_state_changed.emit(new_state)

func _on_box_fully_opened() -> void:
	print("🎉 BOX IS FULLY OPEN!")
	interaction_text = "Close Box"
	emit_state_change("OPEN")
	
	if not _spawned_object:
		_spawn_object()
	
	box_opened.emit()

func _on_box_fully_closed() -> void:
	print("📦 BOX IS CLOSED!")
	interaction_text = "Open Box"
	emit_state_change("CLOSED")
	
	if box_close_sound:
		_play_sound(box_close_sound)
		print("🔊 Playing box close sound")
	
	if _spawned_object:
		_remove_spawned_object()
	
	box_closed.emit()

func _spawn_object() -> void:
	print("Ready to spawn object from box!")

func _remove_spawned_object() -> void:
	if _spawned_object and is_instance_valid(_spawned_object):
		print("Removing spawned object...")
		_spawned_object.queue_free()
		_spawned_object = null

func _get_animation_players() -> Array[AnimationPlayer]:
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(parent_object, players)
	return players

func _collect_animation_players(node: Node, collection: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		collection.append(node)
	
	for child in node.get_children():
		_collect_animation_players(child, collection)

func _find_animation_player_in_node(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
	return null

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
