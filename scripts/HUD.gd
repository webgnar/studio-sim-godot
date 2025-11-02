extends CanvasLayer

## HUD system for displaying interaction prompts and game UI
## Automatically connects to PlayerInteractionComponent signals

# --- NODE REFERENCES ---
@onready var interaction_label: Label = $CenterContainer/InteractionPrompt
@onready var crosshair: Control = $Crosshair

# --- PRIVATE VARIABLES ---
var _player: CharacterBody3D
var _player_interaction_component: PlayerInteractionComponent

# --- GODOT METHODS ---

func _ready() -> void:
	# Find the player
	_player = get_parent()
	
	if not _player:
		push_error("HUD: No player found as parent!")
		return
	
	# Hide interaction prompt initially
	if interaction_label:
		interaction_label.hide()
	
	# Connect to player interaction component signals
	_connect_to_player_interaction_component()

# --- SETUP METHODS ---

func _connect_to_player_interaction_component() -> void:
	# Wait a frame for PlayerInteractionComponent to be created
	await get_tree().process_frame
	
	# Try to find the PlayerInteractionComponent
	for child in _player.get_children():
		if child is PlayerInteractionComponent:
			_player_interaction_component = child
			break
	
	if not _player_interaction_component:
		push_error("HUD: Could not find PlayerInteractionComponent on player!")
		return
	
	# Connect signals
	_player_interaction_component.interaction_prompt_changed.connect(_on_prompt_changed)
	_player_interaction_component.interactive_object_detected.connect(_on_object_detected)
	_player_interaction_component.nothing_detected.connect(_on_nothing_detected)
	
	print("✅ HUD connected to PlayerInteractionComponent")

# --- SIGNAL HANDLERS ---

func _on_prompt_changed(prompt_text: String) -> void:
	if not interaction_label:
		return
	
	if prompt_text == "":
		interaction_label.hide()
	else:
		# Format the prompt text
		var formatted_text = "[E] " + prompt_text
		interaction_label.text = formatted_text
		interaction_label.show()

func _on_object_detected(_interactable: Node3D) -> void:
	# Optional: Add visual feedback when object is detected
	# For example, change crosshair color
	pass

func _on_nothing_detected() -> void:
	# Optional: Reset visual feedback
	if interaction_label:
		interaction_label.hide()

# --- PUBLIC METHODS ---

## Show a custom message on the HUD
func show_message(message: String, duration: float = 2.0) -> void:
	if not interaction_label:
		return
	
	interaction_label.text = message
	interaction_label.show()
	
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		interaction_label.hide()

## Update crosshair visibility
func set_crosshair_visible(show_crosshair: bool) -> void:
	if crosshair:
		crosshair.visible = show_crosshair
