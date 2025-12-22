extends Node3D

## Title screen controller - handles save detection and scene transitions

@onready var continue_button: Button = $UI_Layer/TitleScreenUI/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $UI_Layer/TitleScreenUI/VBoxContainer/NewGameButton
@onready var options_button: Button = $UI_Layer/TitleScreenUI/VBoxContainer/OptionsButton
@onready var quit_button: Button = $UI_Layer/TitleScreenUI/VBoxContainer/QuitButton
@onready var character = $humanrig
@onready var button_nav_sound: AudioStreamPlayer = $ButtonNavSound
@onready var game_start_sound: AudioStreamPlayer = $GameStartSound
@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var fan_animation_player: AnimationPlayer = $"FAN/fan legs/cage/blade/AnimationPlayer"

var is_transitioning: bool = false
var options_menu: Control = null
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15  # Cooldown between navigation inputs
const OPTIONS_MENU_SCENE = preload("res://scenes/UI/OptionsMenu.tscn")

func _ready():
	# Set mouse mode to visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Start fan animation
	if fan_animation_player:
		fan_animation_player.play("spin")

	# Check if save exists and enable/disable Continue button
	var has_save = _check_save_exists()
	continue_button.disabled = !has_save

	# Connect buttons
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Instantiate options menu
	options_menu = OPTIONS_MENU_SCENE.instantiate()
	options_menu.closed.connect(_on_options_closed)
	add_child(options_menu)

	# Connect background music to loop
	if background_music:
		background_music.finished.connect(_on_background_music_finished)

	# Set up controller/gamepad focus navigation
	_setup_focus_navigation()

	# Focus first available button
	if has_save:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()

func _process(delta):
	# Update input cooldown
	if input_cooldown > 0:
		input_cooldown -= delta

func _input(event):
	var viewport = get_viewport()
	if not viewport:
		return  # Scene is transitioning, viewport is null

	# Handle menu navigation with ui_up/ui_down
	if Input.is_action_just_pressed("ui_up"):
		if input_cooldown <= 0:
			_navigate_menu(-1)  # Move up
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
	elif Input.is_action_just_pressed("ui_down"):
		if input_cooldown <= 0:
			_navigate_menu(1)  # Move down
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
	elif Input.is_action_just_pressed("jump"):
		# Confirm button selection with jump (A button)
		var focused = viewport.gui_get_focus_owner()
		if focused is Button and not focused.disabled:
			focused.pressed.emit()
			# Don't set_input_as_handled here - scene might transition immediately
	elif Input.is_action_just_pressed("start"):
		# Start button goes directly to mission selection (same as new game)
		_on_new_game_pressed()
		# Don't set_input_as_handled here - scene is transitioning

func _navigate_menu(direction: int):
	"""Navigate menu up (-1) or down (1)"""
	var viewport = get_viewport()
	if not viewport:
		return  # Scene is transitioning

	var focused = viewport.gui_get_focus_owner()

	# Create button list (only enabled buttons)
	var buttons = []
	if not continue_button.disabled:
		buttons.append(continue_button)
	buttons.append(new_game_button)
	buttons.append(options_button)
	buttons.append(quit_button)

	if buttons.is_empty():
		return

	# Find current index
	var current_index = buttons.find(focused)
	if current_index == -1:
		# No button focused, focus first
		buttons[0].grab_focus()
		return

	# Calculate new index with wrapping
	var new_index = (current_index + direction) % buttons.size()
	if new_index < 0:
		new_index = buttons.size() - 1

	buttons[new_index].grab_focus()

	# Play navigation sound
	if button_nav_sound:
		button_nav_sound.play()

func _check_save_exists() -> bool:
	"""Check if any save files exist"""
	return (FileAccess.file_exists("user://player_data.json") or
			FileAccess.file_exists("user://mission_progression.json") or
			FileAccess.file_exists("user://world_state.json"))

func _on_continue_pressed():
	"""Load the world scene - UIManager will load existing save data in its _ready()"""
	# Play game start sound
	if game_start_sound:
		game_start_sound.play()
	_transition_to_game("res://scenes/world.tscn", false)

func _on_new_game_pressed():
	"""Wipe all save data before loading world scene"""
	# Play game start sound
	if game_start_sound:
		game_start_sound.play()
	_transition_to_game("res://scenes/world.tscn", true)

func _on_options_pressed():
	"""Open the options menu"""
	if options_menu:
		options_menu.show_menu()
		# Disable title screen input while options is open
		set_process_input(false)

func _on_options_closed():
	"""Handle options menu closing"""
	# Re-enable title screen input
	set_process_input(true)
	# Return focus to Options button
	options_button.grab_focus()

func _transition_to_game(scene_path: String, wipe_data: bool) -> void:
	"""Handle transition to game with character animation and fade"""
	if is_transitioning:
		return  # Prevent multiple transitions

	is_transitioning = true

	# Disable input and buttons
	set_process_input(false)
	continue_button.disabled = true
	new_game_button.disabled = true
	quit_button.disabled = true

	# Wipe save data if needed (before animation to ensure it completes)
	if wipe_data:
		_wipe_save_data()

	# Play character exit animation if character exists
	if character and character.has_method("play_exit_animation"):
		character.play_exit_animation()
		await character.exit_animation_completed

	# Fade to scene using SceneTransition singleton
	SceneTransition.fade_to_scene(scene_path)

func _on_quit_pressed():
	"""Quit the game"""
	get_tree().quit()

func _wipe_save_data():
	"""Delete all save files and directories"""
	# Delete player data JSON
	if FileAccess.file_exists("user://player_data.json"):
		DirAccess.remove_absolute("user://player_data.json")
		print("TitleScreen: Deleted player_data.json")

	# Delete mission progression JSON
	if FileAccess.file_exists("user://mission_progression.json"):
		DirAccess.remove_absolute("user://mission_progression.json")
		print("TitleScreen: Deleted mission_progression.json")

	# Delete mission_paintings directory
	var dir = DirAccess.open("user://")
	if dir and dir.dir_exists("mission_paintings"):
		_delete_directory_recursive("user://mission_paintings")
		print("TitleScreen: Deleted mission_paintings directory")

	# Delete world state (carryable paintings)
	if WorldStateManager:
		WorldStateManager.clear_world_state()
		print("TitleScreen: Cleared world state")

func _delete_directory_recursive(path: String):
	"""Recursively delete a directory and all its contents"""
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var file_path = path + "/" + file_name

		if dir.current_is_dir():
			# Recursively delete subdirectory
			_delete_directory_recursive(file_path)
		else:
			# Delete file
			DirAccess.remove_absolute(file_path)

		file_name = dir.get_next()

	dir.list_dir_end()

	# Remove the directory itself
	DirAccess.remove_absolute(path)

func _on_background_music_finished():
	"""Loop background music when it finishes"""
	if background_music:
		background_music.play()

func _setup_focus_navigation():
	"""Set up gamepad/keyboard focus navigation for menu buttons"""
	# Enable focus mode for all buttons
	continue_button.focus_mode = Control.FOCUS_ALL
	new_game_button.focus_mode = Control.FOCUS_ALL
	options_button.focus_mode = Control.FOCUS_ALL
	quit_button.focus_mode = Control.FOCUS_ALL

	# Don't set up focus neighbors - we handle navigation manually
	# This prevents arrow keys from selecting disabled buttons
