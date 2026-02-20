extends Node

## Global UI Manager - Centralized state machine for all UI screens and game states
## Manages screen visibility, input modes, and player currency

# Signals
signal state_changed(old_state: GameState, new_state: GameState)

# Game states
enum GameState {
	MAIN_MENU,      # Main menu hub visible
	GAMEPLAY,       # In studio, FPS controls active
	MISSION_SELECT, # Mission browser open (deprecated, use PAUSE_MENU)
	IN_MISSION,     # Actively painting/working on mission
	VALIDATION,     # Viewing mission results
	PAUSE_MENU      # Pause menu with tabs (Commissions, Inventory, Options)
}

# Current game state (start as null, will be set to MAIN_MENU in _ready)
@warning_ignore("INT_AS_ENUM_WITHOUT_MATCH")
var current_state: GameState = -1 as GameState  # Invalid state to force initial transition

# Player data
var missions_completed: int = 0

# Platform detection for mouse mode
var _platform_name: String = ""

# Steam overlay auto-pause tracking
var _overlay_triggered_pause: bool = false
var _state_before_overlay: GameState = GameState.GAMEPLAY

# Registered UI screens
var main_menu: Control = null
var mission_selection: Control = null
var validation_result: Control = null
var pause_menu: Control = null
var hud: CanvasLayer = null

# Save file path
const SAVE_PATH = "user://player_data.json"

func _ready():
	# Keep processing while game tree is paused (for _input and state transitions)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Detect platform for mouse mode optimization
	_platform_name = OS.get_name()
	print("UIManager: Detected platform: %s" % _platform_name)

	# Load player data from disk
	load_player_data()

	# CRITICAL: Ensure we're in fullscreen BEFORE capturing mouse
	# macOS works better with FULLSCREEN (mode 3) than EXCLUSIVE_FULLSCREEN (mode 4)
	# Regular fullscreen allows the macOS compositor to properly grant mouse capture
	var current_mode = DisplayServer.window_get_mode()
	print("UIManager: Initial window mode: %d (0=WINDOWED, 1=MINIMIZED, 2=MAXIMIZED, 3=FULLSCREEN, 4=EXCLUSIVE_FULLSCREEN)" % current_mode)

	if current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		print("UIManager: Setting fullscreen mode (was mode %d)" % current_mode)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

		# Wait for the mode switch to take effect
		await get_tree().process_frame
		current_mode = DisplayServer.window_get_mode()
		print("UIManager: Window mode immediately after setting: %d" % current_mode)

	# Wait for macOS to complete the fullscreen transition
	# Regular fullscreen is faster than exclusive, but still needs time
	await get_tree().process_frame
	await get_tree().process_frame

	# Additional time delay for macOS fullscreen animation
	await get_tree().create_timer(0.1).timeout

	# Wait another frame for all UI screens to register
	await get_tree().process_frame

	# Verify we're actually in fullscreen before proceeding
	current_mode = DisplayServer.window_get_mode()
	print("UIManager: Final window mode: %d (3=FULLSCREEN)" % current_mode)
	print("UIManager: Current mouse mode before capture: %d (0=VISIBLE, 2=CAPTURED, 5=CONFINED_HIDDEN)" % Input.mouse_mode)

	# Start in gameplay state so player can move immediately
	change_state(GameState.GAMEPLAY)

	# Pause when Steam overlay opens
	if SteamManager:
		SteamManager.steam_initialized.connect(_on_steam_initialized_for_overlay)

	# Pause when a controller is disconnected mid-game
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _input(event):
	# "start" button (backtick) toggles mission selection menu
	if event.is_action_pressed("start"):
		match current_state:
			GameState.GAMEPLAY, GameState.IN_MISSION:
				change_state(GameState.PAUSE_MENU)
			GameState.PAUSE_MENU:
				# Return to previous state (GAMEPLAY or IN_MISSION)
				if MissionManager and MissionManager.current_mission:
					change_state(GameState.IN_MISSION)
				else:
					change_state(GameState.GAMEPLAY)
			_:
				# In other states (validation, etc.), do nothing
				pass
		get_viewport().set_input_as_handled()

func change_state(new_state: GameState):
	"""Central state transition handler"""
	if new_state == current_state:
		return

	var old_state = current_state
	current_state = new_state

	# Hide all UI screens first
	_hide_all_screens()

	# Show appropriate screen and configure input
	match current_state:
		GameState.MAIN_MENU:
			if main_menu:
				main_menu.call("show_screen")
			_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if CameraManager:
				CameraManager.set_player_input(false)

		GameState.GAMEPLAY:
			# No UI overlay, just HUD (HUD handles its own visibility)
			# Use platform-specific mouse mode for optimal FPS experience
			_set_mouse_mode(_get_gameplay_mouse_mode())
			if CameraManager:
				CameraManager.set_player_input(true)

		GameState.MISSION_SELECT:
			# Deprecated: route to PAUSE_MENU
			if pause_menu:
				pause_menu.call("show_screen")
			elif mission_selection:
				mission_selection.call("show_screen")
			_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if CameraManager:
				CameraManager.set_player_input(false)

		GameState.IN_MISSION:
			# Similar to GAMEPLAY but mission is active
			# Use platform-specific mouse mode for optimal FPS experience
			_set_mouse_mode(_get_gameplay_mouse_mode())
			if CameraManager:
				CameraManager.set_player_input(true)

		GameState.VALIDATION:
			if validation_result:
				validation_result.call("show_screen")
			_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if CameraManager:
				CameraManager.set_player_input(false)

		GameState.PAUSE_MENU:
			if pause_menu:
				pause_menu.call("show_screen")
			_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if CameraManager:
				CameraManager.set_player_input(false)

	# Pause/unpause game tree (freezes all game world nodes while menu is open)
	get_tree().paused = (current_state == GameState.PAUSE_MENU)

	# Emit state change signal
	emit_signal("state_changed", old_state, new_state)

func _hide_all_screens():
	"""Hide all registered UI screens"""
	if main_menu and main_menu.has_method("hide_screen"):
		main_menu.call("hide_screen")
	if mission_selection and mission_selection.has_method("hide_screen"):
		mission_selection.call("hide_screen")
	if validation_result and validation_result.has_method("hide_screen"):
		validation_result.call("hide_screen")
	if pause_menu and pause_menu.has_method("hide_screen"):
		pause_menu.call("hide_screen")

func _get_gameplay_mouse_mode() -> Input.MouseMode:
	"""Get the appropriate mouse mode for gameplay based on platform

	Platform-specific behavior:
	- Linux/Steam Deck: CAPTURED - True FPS capture, prevents cursor from reaching edges
	- macOS: CAPTURED - Proper FPS control, prevents cursor escape
	- Windows: CAPTURED - Standard FPS behavior

	All platforms now use CAPTURED mode for consistent behavior and proper mouse lock.
	"""
	# All platforms (including macOS) use CAPTURED for proper FPS control
	# This prevents cursor from reaching window edges or escaping off screen
	print("UIManager: Using MOUSE_MODE_CAPTURED for %s" % _platform_name)
	return Input.MOUSE_MODE_CAPTURED

func _set_mouse_mode(mode: Input.MouseMode):
	"""Set mouse capture mode with verification"""
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode

		# Verify the mode was actually set (especially important for CAPTURED/CONFINED_HIDDEN modes)
		await get_tree().process_frame

		if Input.mouse_mode != mode:
			push_error("UIManager: Failed to set mouse mode to %d! Current mode: %d (0=VISIBLE, 2=CAPTURED, 5=CONFINED_HIDDEN)" % [mode, Input.mouse_mode])

			# Retry once
			await get_tree().process_frame
			Input.mouse_mode = mode
			await get_tree().process_frame

			if Input.mouse_mode == mode:
				print("UIManager: Mouse mode set to %d on retry (0=VISIBLE, 2=CAPTURED, 5=CONFINED_HIDDEN)" % mode)
			else:
				push_error("UIManager: Mouse mode still failed after retry! Mode: %d (0=VISIBLE, 2=CAPTURED, 5=CONFINED_HIDDEN)" % Input.mouse_mode)
		else:
			print("UIManager: Mouse mode successfully set to %d (0=VISIBLE, 2=CAPTURED, 5=CONFINED_HIDDEN)" % mode)

func _on_steam_initialized_for_overlay(success: bool) -> void:
	"""Connect Steam overlay signal once Steam is ready"""
	if success:
		Steam.overlay_toggled.connect(_on_steam_overlay_toggled)

func _on_steam_overlay_toggled(active: bool, _user_initiated: bool = false, _app_id: int = 0) -> void:
	"""Pause the game when the Steam overlay opens; resume when it closes"""
	if active:
		if current_state == GameState.GAMEPLAY or current_state == GameState.IN_MISSION:
			_state_before_overlay = current_state
			_overlay_triggered_pause = true
			change_state(GameState.PAUSE_MENU)
	else:
		if _overlay_triggered_pause:
			_overlay_triggered_pause = false
			change_state(_state_before_overlay)

func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	"""Pause the game when a controller is disconnected during gameplay"""
	if not connected:
		if current_state == GameState.GAMEPLAY or current_state == GameState.IN_MISSION:
			change_state(GameState.PAUSE_MENU)

func register_screen(screen_type: String, screen: Node):
	"""Register UI screens with the manager"""
	match screen_type:
		"main_menu":
			main_menu = screen
			print("UIManager: Registered main menu")
		"mission_selection":
			mission_selection = screen
			print("UIManager: Registered mission selection")
		"validation":
			validation_result = screen
			print("UIManager: Registered validation result")
		"pause_menu":
			pause_menu = screen
			print("UIManager: Registered pause menu")
		"hud":
			hud = screen
			print("UIManager: Registered HUD")
		_:
			push_warning("UIManager: Unknown screen type '%s'" % screen_type)

func clear_player_data():
	"""Clear player data in memory (called on New Game)"""
	missions_completed = 0
	print("UIManager: Player data cleared")

func save_player_data():
	"""Save player data to disk"""
	var data = {
		"missions_completed": missions_completed
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()
	else:
		push_error("UIManager: Failed to save player data!")

func load_player_data():
	"""Load player data from disk"""
	if not FileAccess.file_exists(SAVE_PATH):
		print("UIManager: No save file found, starting with default values")
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("UIManager: Failed to open save file!")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)

	if error == OK:
		var data = json.data
		missions_completed = data.get("missions_completed", 0)
		print("UIManager: Loaded player data - Missions: %d" % missions_completed)
	else:
		push_error("UIManager: Failed to parse save file JSON!")
