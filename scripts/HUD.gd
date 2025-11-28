extends CanvasLayer

## HUD system for displaying interaction prompts and game UI
## Automatically connects to PlayerInteractionComponent signals

# --- NODE REFERENCES ---
@onready var interaction_label: Label = $CenterContainer/InteractionPrompt
@onready var crosshair: Control = $Crosshair
@onready var carry_hint: Label = $CarryHint  # Will show carry controls when holding object

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

	# Hide carry hint initially
	if carry_hint:
		carry_hint.hide()

	# Connect to UIManager state changes
	if UIManager:
		UIManager.state_changed.connect(_on_state_changed)

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

func _process(_delta: float) -> void:
	# Update carry hint based on carrying state
	_update_carry_hint()

# --- SIGNAL HANDLERS ---

func _on_state_changed(old_state, new_state) -> void:
	"""Handle game state changes from UIManager"""
	# Show HUD only in GAMEPLAY and IN_MISSION states
	match new_state:
		UIManager.GameState.GAMEPLAY, UIManager.GameState.IN_MISSION:
			visible = true
			set_crosshair_visible(true)
		_:
			# Hide HUD in menu states
			visible = false

func _on_prompt_changed(prompt_text: String) -> void:
	if not interaction_label:
		return
	
	if prompt_text == "":
		interaction_label.hide()
	else:
		# Display the prompt directly (already formatted by PlayerInteractionComponent)
		interaction_label.text = prompt_text
		interaction_label.show()

func _on_object_detected(_interactable: Node3D) -> void:
	pass

func _on_nothing_detected() -> void:
	if interaction_label:
		interaction_label.hide()

func _update_carry_hint() -> void:
	"""Update the carry controls hint based on whether player is carrying something"""
	if not _player_interaction_component or not carry_hint:
		return
	
	if _player_interaction_component.is_carrying:
		# Check if carried object has E-key interaction
		var carried = _player_interaction_component.carried_object
		if carried and carried.has_e_key_interaction and carried.can_interact_while_carried:
			carry_hint.text = "[E] " + carried.e_key_interaction_text + "  |  [Right Click] Drop  |  [Left Click] Throw"
		else:
			carry_hint.text = "[Right Click] Drop  |  [Left Click] Throw"
		carry_hint.show()
		
		# Hide normal interaction prompt while carrying
		if interaction_label:
			interaction_label.hide()
	else:
		carry_hint.hide()

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
