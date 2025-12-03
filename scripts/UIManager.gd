extends Node

## Global UI Manager - Centralized state machine for all UI screens and game states
## Manages screen visibility, input modes, and player currency

# Signals
signal state_changed(old_state: GameState, new_state: GameState)

# Game states
enum GameState {
	MAIN_MENU,      # Main menu hub visible
	GAMEPLAY,       # In studio, FPS controls active
	MISSION_SELECT, # Mission browser open
	IN_MISSION,     # Actively painting/working on mission
	VALIDATION,     # Viewing mission results
	SHOP            # Shop interface (placeholder)
}

# Current game state (start as null, will be set to MAIN_MENU in _ready)
var current_state: GameState = -1  # Invalid state to force initial transition

# Player data
var missions_completed: int = 0

# Registered UI screens
var main_menu: Control = null
var mission_selection: Control = null
var validation_result: Control = null
var shop_ui: Control = null
var hud: CanvasLayer = null

# Save file path
const SAVE_PATH = "user://player_data.json"

func _ready():
	# Load player data from disk
	load_player_data()

	# Wait a frame for all UI screens to register
	await get_tree().process_frame

	# Start in gameplay state so player can move immediately
	change_state(GameState.GAMEPLAY)

func _input(event):
	# "start" button (backtick) toggles mission selection menu
	if event.is_action_pressed("start"):
		match current_state:
			GameState.GAMEPLAY, GameState.IN_MISSION:
				change_state(GameState.MISSION_SELECT)
			GameState.MISSION_SELECT:
				# Return to previous state (GAMEPLAY or IN_MISSION)
				if MissionManager and MissionManager.current_mission:
					change_state(GameState.IN_MISSION)
				else:
					change_state(GameState.GAMEPLAY)
			_:
				# In other states (validation, shop), do nothing
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
			_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			if CameraManager:
				CameraManager.set_player_input(true)

		GameState.MISSION_SELECT:
			if mission_selection:
				mission_selection.call("show_screen")
			_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if CameraManager:
				CameraManager.set_player_input(false)

		GameState.IN_MISSION:
			# Similar to GAMEPLAY but mission is active
			_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			if CameraManager:
				CameraManager.set_player_input(true)

		GameState.VALIDATION:
			if validation_result:
				validation_result.call("show_screen")
			_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if CameraManager:
				CameraManager.set_player_input(false)

		GameState.SHOP:
			if shop_ui:
				shop_ui.call("show_screen")
			_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if CameraManager:
				CameraManager.set_player_input(false)

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
	if shop_ui and shop_ui.has_method("hide_screen"):
		shop_ui.call("hide_screen")

func _set_mouse_mode(mode: Input.MouseMode):
	"""Set mouse capture mode"""
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode

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
		"shop":
			shop_ui = screen
			print("UIManager: Registered shop")
		"hud":
			hud = screen
			print("UIManager: Registered HUD")
		_:
			push_warning("UIManager: Unknown screen type '%s'" % screen_type)

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
