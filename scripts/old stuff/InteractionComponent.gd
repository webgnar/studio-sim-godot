extends Node3D
class_name InteractionComponent

## Base class for all interactable objects in the game
## Provides common functionality like audio, interaction text, and virtual interact() method
## Automatically adds parent object to "interactable" group for detection

# --- SIGNALS ---
signal interacted(player_interaction_component: PlayerInteractionComponent)
signal hover_started()
signal hover_ended()
signal state_changed(new_state: String)

# --- EXPORTED VARIABLES ---
@export_group("Interaction Settings")
@export var interaction_text: String = "Interact"
@export var is_disabled: bool = false
@export var custom_interaction_distance: float = -1.0  ## Custom interaction distance for this object (-1 = use default)

@export_group("Audio")
@export var interaction_sound: AudioStream
@export var hover_sound: AudioStream

# --- PROTECTED VARIABLES ---
var parent_object: Node3D
var _audio_player: AudioStreamPlayer3D

# --- GODOT METHODS ---

func _ready() -> void:
	parent_object = get_parent()
	
	# Automatically add parent to interactable group
	if not parent_object.is_in_group("interactable"):
		parent_object.add_to_group("interactable")
	
	# Setup audio system
	_setup_audio()
	
	# Allow subclasses to do additional setup
	_on_ready()

## Virtual method - override in subclasses for additional setup
func _on_ready() -> void:
	pass

# --- AUDIO METHODS ---

func _setup_audio() -> void:
	if interaction_sound or hover_sound:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "InteractionAudio"
		_audio_player.max_distance = 10.0
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_audio_player.bus = "SFX"
		add_child(_audio_player)

func _play_sound(sound: AudioStream, volume_db: float = 0.0) -> void:
	if sound and _audio_player:
		_audio_player.stream = sound
		_audio_player.volume_db = volume_db
		_audio_player.play()

# --- INTERACTION METHODS ---

## Main interaction method - OVERRIDE THIS in subclasses
## This is called when player presses interact button while looking at this object
func interact(player_interaction_component: PlayerInteractionComponent) -> void:
	if is_disabled:
		return
	
	# Play interaction sound
	if interaction_sound:
		_play_sound(interaction_sound)
	
	# Emit signal
	interacted.emit(player_interaction_component)
	
	# Allow subclasses to add custom logic
	_on_interacted(player_interaction_component)

## Virtual method - override in subclasses for custom interaction logic
func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	pass

# --- STATE MANAGEMENT ---

## Set whether this interaction is disabled
func set_disabled(disabled: bool) -> void:
	is_disabled = disabled

## Get whether this interaction is disabled
func get_disabled() -> bool:
	return is_disabled

## Emit a state change signal (useful for UI updates)
func emit_state_change(new_state: String) -> void:
	state_changed.emit(new_state)

# --- HOVER METHODS ---

## Called when player starts looking at this object
func on_hover_start() -> void:
	if hover_sound:
		_play_sound(hover_sound, -10.0)  # Quieter for hover
	
	hover_started.emit()
	_on_hover_started()

## Virtual method - override for custom hover start behavior
func _on_hover_started() -> void:
	pass

## Called when player stops looking at this object
func on_hover_end() -> void:
	hover_ended.emit()
	_on_hover_ended()

## Virtual method - override for custom hover end behavior
func _on_hover_ended() -> void:
	pass

# --- UTILITY METHODS ---

## Get the parent object this component is attached to
func get_parent_object() -> Node3D:
	return parent_object

## Get the audio player for manual control if needed
func get_audio_player() -> AudioStreamPlayer3D:
	return _audio_player

## Helper to find nodes in parent hierarchy
func find_in_parent(node_name: String) -> Node:
	if not parent_object:
		return null
	return parent_object.get_node_or_null(node_name)

## Helper to find AnimationPlayer in parent
func find_animation_player() -> AnimationPlayer:
	return _find_animation_player_recursive(parent_object)

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	
	for child in node.get_children():
		var result = _find_animation_player_recursive(child)
		if result:
			return result
	
	return null
