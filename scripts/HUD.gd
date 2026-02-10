extends CanvasLayer

## HUD system for displaying interaction prompts and game UI
## Automatically connects to PlayerInteractionComponent signals

# --- NODE REFERENCES ---
@onready var interaction_prompt: HBoxContainer = $CenterContainer/InteractionPrompt
@onready var interaction_icon: TextureRect = $CenterContainer/InteractionPrompt/TextureRect
@onready var interaction_label: Label = $CenterContainer/InteractionPrompt/Label
@onready var crosshair: Control = $Crosshair
@onready var carry_hint: VBoxContainer = $CarryHint  # Will show carry controls when holding object
@onready var painting_hint: VBoxContainer = $PaintingHint  # Will show painting controls when in 2D painting mode
@onready var camera_icon: TextureRect = $CameraIcon  # Shows when camera zones are active

# --- PRIVATE VARIABLES ---
var _player: CharacterBody3D
var _player_interaction_component: PlayerInteractionComponent
var _current_prompt_text: String = ""  # Store current prompt for device switching

# --- GODOT METHODS ---

func _ready() -> void:
	# CRITICAL: Set mouse_filter to IGNORE on all Control children
	# This prevents HUD from consuming mouse motion events needed for FPS camera look
	_setup_mouse_filters()

	# Find the player
	_player = get_parent()

	if not _player:
		push_error("HUD: No player found as parent!")
		return

	# Hide interaction prompt initially
	if interaction_prompt:
		interaction_prompt.hide()

	# Hide carry hint initially
	if carry_hint:
		carry_hint.hide()

	# Hide painting hint initially
	if painting_hint:
		painting_hint.hide()

	# Connect to UIManager state changes
	if UIManager:
		UIManager.state_changed.connect(_on_state_changed)

	# Connect to input device changes for carry hint updates
	if InputDeviceManager:
		InputDeviceManager.device_changed.connect(_on_input_device_changed)

	# Connect to camera zone toggle for user feedback
	if CameraManager:
		CameraManager.zones_toggled.connect(_on_zones_toggled)

	# Connect to player interaction component signals
	_connect_to_player_interaction_component()

	# Log for debugging exports
	if DebugLogger:
		DebugLogger.write_log("[HUD] Mouse filter set to IGNORE on all UI elements")

# --- SETUP METHODS ---

func _setup_mouse_filters() -> void:
	"""Set mouse_filter to IGNORE on all HUD Control nodes to prevent consuming mouse motion"""
	# Set filter on all root Control children
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Recursively set on all descendants too
			_set_mouse_filter_recursive(child)

func _set_mouse_filter_recursive(node: Node) -> void:
	"""Recursively set mouse_filter to IGNORE on all Control descendants"""
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_filter_recursive(child)

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

	# Update painting hint based on painting mode
	_update_painting_hint()

# --- SIGNAL HANDLERS ---

func _on_state_changed(_old_state, new_state) -> void:
	"""Handle game state changes from UIManager"""
	# Show HUD only in GAMEPLAY and IN_MISSION states
	match new_state:
		UIManager.GameState.GAMEPLAY, UIManager.GameState.IN_MISSION:
			visible = true
			set_crosshair_visible(true)
		_:
			# Hide HUD in menu states
			visible = false

func _on_input_device_changed(_new_device) -> void:
	"""Refresh all hints when input device changes"""
	_update_carry_hint()
	_update_painting_hint()
	_update_interaction_prompt()

func _on_prompt_changed(prompt_text: String) -> void:
	# Store the prompt text for device switching
	_current_prompt_text = prompt_text
	_update_interaction_prompt()

func _on_object_detected(_interactable: Node3D) -> void:
	pass

func _on_nothing_detected() -> void:
	_current_prompt_text = ""
	_update_interaction_prompt()

func _update_interaction_prompt() -> void:
	"""Update the interaction prompt based on current device and prompt text"""
	if not interaction_label or not interaction_prompt or not interaction_icon:
		return

	# Don't show interaction prompt if painting or carrying
	if _is_2d_painting_active() or (_player_interaction_component and _player_interaction_component.is_carrying):
		interaction_prompt.hide()
		return

	if _current_prompt_text == "":
		interaction_prompt.hide()
		return

	# Check if we're in gamepad mode
	var is_gamepad = InputDeviceManager.current_device == InputDeviceManager.DeviceType.GAMEPAD

	if is_gamepad:
		# Show icon, update label (strip the "[X]" prefix from prompt text)
		var action_data = InputDeviceManager.glyph_map.get("interact", {})
		if action_data.has("gamepad_icon"):
			interaction_icon.texture = load(action_data["gamepad_icon"])
			interaction_icon.show()

			# Strip the glyph prefix (e.g., "[X] " or "[E] ") from the text
			var display_text = _current_prompt_text
			var regex = RegEx.new()
			regex.compile("^\\[.*?\\]\\s*")
			display_text = regex.sub(display_text, "", true)
			interaction_label.text = display_text
	else:
		# Keyboard mode - hide icon, show full text with keyboard glyph
		interaction_icon.hide()
		interaction_label.text = _current_prompt_text

	interaction_prompt.show()

func _update_carry_hint() -> void:
	"""Update the carry controls hint based on whether player is carrying something"""
	if not _player_interaction_component or not carry_hint:
		return

	if _player_interaction_component.is_carrying:
		var carried = _player_interaction_component.carried_object

		# Check if carried object has rotation enabled
		var has_rotation = false
		if carried and "enable_rotation_while_carried" in carried:
			has_rotation = carried.enable_rotation_while_carried

		# Show/hide rotation controls based on whether rotation is enabled
		var rotate_y_line = carry_hint.get_node("RotateYLine")
		var rotate_x_line = carry_hint.get_node("RotateXLine")

		if has_rotation:
			_update_button_display(
				rotate_y_line.get_node("RotateYLeftIcon"),
				rotate_y_line.get_node("RotateYLeftLabel"),
				"rotate_counter"
			)
			_update_button_display(
				rotate_y_line.get_node("RotateYRightIcon"),
				rotate_y_line.get_node("RotateYRightLabel"),
				"rotate_clockwise"
			)
			_update_button_display(
				rotate_x_line.get_node("RotateXDownIcon"),
				rotate_x_line.get_node("RotateXDownLabel"),
				"scale_sticker_down"
			)
			_update_button_display(
				rotate_x_line.get_node("RotateXUpIcon"),
				rotate_x_line.get_node("RotateXUpLabel"),
				"scale_sticker_up"
			)
			rotate_y_line.show()
			rotate_x_line.show()
		else:
			rotate_y_line.hide()
			rotate_x_line.hide()

		# Show/hide E-key interaction if available
		var interact_line = carry_hint.get_node("InteractLine")
		if carried and carried.has_e_key_interaction and carried.can_interact_while_carried:
			interact_line.get_node("InteractLabel").text = InputDeviceManager.get_formatted_prompt("interact")
			interact_line.get_node("InteractText").text = " " + carried.e_key_interaction_text
			interact_line.show()
		else:
			interact_line.hide()

		# Always show drop/throw controls
		var drop_throw_line = carry_hint.get_node("DropThrowLine")
		_update_button_display(
			drop_throw_line.get_node("DropIcon"),
			drop_throw_line.get_node("DropLabel"),
			"action_secondary"
		)
		_update_button_display(
			drop_throw_line.get_node("ThrowIcon"),
			drop_throw_line.get_node("ThrowLabel"),
			"action_primary"
		)
		drop_throw_line.show()

		carry_hint.show()

		# Hide other prompts while carrying
		if interaction_prompt:
			interaction_prompt.hide()
		if painting_hint:
			painting_hint.hide()
	else:
		carry_hint.hide()

func _is_2d_painting_active() -> bool:
	"""Check if player is currently in 2D painting mode"""
	if not PaintingModeManager or not PaintingModeManager.painting_system_2d:
		return false

	var painting_2d = PaintingModeManager.painting_system_2d

	# Check if preview sprite exists and is visible
	if painting_2d.preview_sprite and painting_2d.preview_sprite.visible:
		return true

	return false

func _update_button_display(icon_node: TextureRect, label_node: Label, action_name: String) -> void:
	"""Update a button's icon and label based on current input device"""
	var is_gamepad = InputDeviceManager.current_device == InputDeviceManager.DeviceType.GAMEPAD
	var action_data = InputDeviceManager.glyph_map.get(action_name, {})

	if is_gamepad and action_data.has("gamepad_icon"):
		# Gamepad mode with icon
		icon_node.texture = load(action_data["gamepad_icon"])
		icon_node.show()
		label_node.hide()
	else:
		# Keyboard mode (text)
		var text = action_data.get("keyboard", "?")
		label_node.text = "[%s]" % text
		label_node.show()
		icon_node.hide()

func _update_painting_hint() -> void:
	"""Update painting controls hint when in 2D painting mode"""
	if not painting_hint:
		return

	var is_painting = _is_2d_painting_active()

	if is_painting:
		var is_gamepad = InputDeviceManager.current_device == InputDeviceManager.DeviceType.GAMEPAD

		# Update Rotate line
		var rotate_icon = painting_hint.get_node("RotateLine/RotateRightIcon")
		var rotate_label = painting_hint.get_node("RotateLine/RotateLabel")
		if is_gamepad:
			rotate_icon.show()
			rotate_label.text = " " + tr("Rotate")
		else:
			rotate_icon.hide()
			rotate_label.text = "[T] " + tr("Rotate")

		# Update Scale line
		var scale_icon = painting_hint.get_node("ScaleLine/ScaleDownIcon")
		var scale_label = painting_hint.get_node("ScaleLine/ScaleLabel")
		if is_gamepad:
			scale_icon.show()
			scale_label.text = " " + tr("Scale")
		else:
			scale_icon.hide()
			scale_label.text = "[X] / [Z] " + tr("Scale")

		# Update Cycle line (has two icons)
		var cycle_prev_icon = painting_hint.get_node("CycleLine/CyclePrevIcon")
		var cycle_next_icon = painting_hint.get_node("CycleLine/CycleNextIcon")
		var cycle_label = painting_hint.get_node("CycleLine/CycleLabel")
		if is_gamepad:
			cycle_prev_icon.show()
			cycle_next_icon.show()
			cycle_label.text = " " + tr("Cycle")
		else:
			cycle_prev_icon.hide()
			cycle_next_icon.hide()
			cycle_label.text = "[1] / [2] " + tr("Cycle")

		# Update Place line
		var place_icon = painting_hint.get_node("PlaceUndoLine/PlaceIcon")
		var place_text = painting_hint.get_node("PlaceUndoLine/PlaceText")
		if is_gamepad:
			place_icon.show()
			place_text.text = " " + tr("Place")
		else:
			place_icon.hide()
			place_text.text = "[Left Click] " + tr("Place")

		# Update Undo line
		var undo_icon = painting_hint.get_node("HBoxContainer/UndoIcon")
		var undo_text = painting_hint.get_node("HBoxContainer/UndoText")
		if is_gamepad:
			undo_icon.show()
			undo_text.text = " " + tr("Undo")
		else:
			undo_icon.hide()
			undo_text.text = "[Right Click] " + tr("Undo")

		painting_hint.show()

		# Hide normal interaction prompt (replace mode)
		if interaction_prompt:
			interaction_prompt.hide()
	else:
		painting_hint.hide()

# --- PUBLIC METHODS ---

## Show a custom message on the HUD
func show_message(message: String, duration: float = 2.0) -> void:
	if not interaction_label or not interaction_prompt:
		return
	
	interaction_label.text = message
	interaction_prompt.show()
	
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		interaction_prompt.hide()

## Update crosshair visibility
func set_crosshair_visible(show_crosshair: bool) -> void:
	if crosshair:
		crosshair.visible = show_crosshair

func _on_zones_toggled(enabled: bool) -> void:
	"""Show feedback when camera zones are toggled"""
	var message = tr("Camera Zones: ON") if enabled else tr("Camera Zones: OFF")
	show_message(message, 2.0)
	if camera_icon:
		camera_icon.visible = enabled
