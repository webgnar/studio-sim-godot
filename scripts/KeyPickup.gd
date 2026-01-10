extends InteractionComponent
class_name KeyPickup

## Interactable key that sets a player flag when picked up and then disappears

@export var key_flag_name: String = "studio_key"  # Flag name to set in WorldStateManager
@export var pickup_text: String = "Pick Up Key"
@export var pickup_sound: AudioStream  # Sound played when key is picked up

func _on_ready() -> void:
	interaction_text = pickup_text

	# Ensure audio player exists for pickup sound
	if not _audio_player and pickup_sound:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "KeyAudio"
		_audio_player.max_distance = 10.0
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_audio_player.bus = "SFX"
		add_child(_audio_player)
		print("🔑 Created audio player for key pickup sound")

func _on_interacted(_player: PlayerInteractionComponent) -> void:
	print("========== KEY PICKUP DEBUG ==========")
	print("🔑 Player is picking up key...")
	print("🔑 Key flag name: '%s'" % key_flag_name)

	# Set the key flag in WorldStateManager
	WorldStateManager.set_flag(key_flag_name, true)

	# Verify the flag was set
	var flag_value = WorldStateManager.has_flag(key_flag_name)
	print("🔑 Flag '%s' set to: %s" % [key_flag_name, flag_value])

	# Disable interaction immediately so player can't pick it up again
	is_disabled = true

	# Hide the key visually
	if parent_object:
		parent_object.visible = false

	# Play pickup sound
	if pickup_sound and _audio_player:
		_play_sound(pickup_sound)
		print("🔑 Playing pickup sound")

		# Wait for sound to finish before removing key
		var sound_length = pickup_sound.get_length()
		print("🔑 Waiting %.2f seconds for sound to finish..." % sound_length)
		await get_tree().create_timer(sound_length).timeout

	print("🔑 Removing key from scene...")
	print("======================================")

	# Remove the key from the scene
	if parent_object:
		parent_object.queue_free()
	else:
		# Fallback: remove self
		get_parent().queue_free()
