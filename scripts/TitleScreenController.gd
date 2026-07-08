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
@onready var camera_anim: AnimationPlayer = $Camera3D/AnimationPlayer
@onready var camera: Camera3D = $Camera3D
@onready var title_screen_ui: Control = $UI_Layer/TitleScreenUI
@onready var confirm_panel: PanelContainer = $UI_Layer/TitleScreenUI/ConfirmPanel
@onready var confirm_yes_button: Button = $UI_Layer/TitleScreenUI/ConfirmPanel/MarginContainer/VBoxContainer/HBoxContainer/YesButton
@onready var confirm_no_button: Button = $UI_Layer/TitleScreenUI/ConfirmPanel/MarginContainer/VBoxContainer/HBoxContainer/NoButton

var is_transitioning: bool = false
var is_confirming: bool = false
var options_menu: Control = null
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15  # Cooldown between navigation inputs
const OPTIONS_MENU_SCENE = preload("res://scenes/UI/OptionsMenu.tscn")

func _ready():
	# Connect device change signal (initial state applied at end of _ready, after grab_focus)
	InputDeviceManager.device_changed.connect(_on_input_device_changed)

	# Fade in from black (skip if SceneTransition is already handling a fade-in)
	if not SceneTransition.is_transitioning:
		SceneTransition.set_fade_visible(true)
		SceneTransition.fade_in()

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

	# Connect confirmation buttons
	confirm_yes_button.pressed.connect(_on_confirm_yes)
	confirm_no_button.pressed.connect(_on_confirm_no)
	
	# Instantiate options menu inside UI_Layer (CanvasLayer) so it shares the same
	# canvas layer as the title screen buttons and receives mouse input correctly
	options_menu = OPTIONS_MENU_SCENE.instantiate()
	options_menu.closed.connect(_on_options_closed)
	$UI_Layer.add_child(options_menu)

	# Ensure our camera is the active one (CameraManager autoload may hold stale state)
	camera.make_current()

	# Play "move in" backwards as intro, chain to "pan" when done
	camera_anim.animation_finished.connect(_on_camera_animation_finished)
	camera_anim.play_backwards("move in")

	# Connect background music to loop
	if background_music:
		background_music.finished.connect(_on_background_music_finished)

	# Set up controller/gamepad focus navigation
	_setup_focus_navigation()

	# Focus first available button so Continue (or New Game) is selected from the start,
	# regardless of input device - the player can hit any direction to begin navigating
	if has_save:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()

	# Apply initial mouse cursor state based on current input device without releasing
	# the focus we just grabbed (that release only makes sense on later device switches)
	if InputDeviceManager.current_device == InputDeviceManager.DeviceType.KEYBOARD_MOUSE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(delta):
	# Update input cooldown
	if input_cooldown > 0:
		input_cooldown -= delta

func _input(_event):
	var viewport = get_viewport()
	if not viewport:
		return  # Scene is transitioning, viewport is null

	if is_confirming:
		_handle_confirm_input(viewport)
		return

	# Handle menu navigation with ui_left/ui_right (buttons are laid out horizontally)
	if Input.is_action_just_pressed("ui_left"):
		if input_cooldown <= 0:
			_navigate_menu(-1)  # Move to previous button
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
	elif Input.is_action_just_pressed("ui_right"):
		if input_cooldown <= 0:
			_navigate_menu(1)  # Move to next button
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
	elif Input.is_action_just_pressed("jump"):
		# Confirm button selection with jump (A button)
		var focused = viewport.gui_get_focus_owner()
		if focused is Button and not focused.disabled:
			focused.pressed.emit()
			viewport.set_input_as_handled()

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

func _close_options_if_open():
	"""Close options menu and restore title screen input if options was open"""
	if options_menu and options_menu.visible:
		options_menu.hide()
		set_process_input(true)

func _on_continue_pressed():
	"""Load the world scene - UIManager will load existing save data in its _ready()"""
	_close_options_if_open()
	# Play game start sound
	if game_start_sound:
		game_start_sound.play()
	_transition_to_game("res://scenes/world.tscn", false)

func _on_new_game_pressed():
	"""Start new game - confirm only if there's existing save data to overwrite"""
	_close_options_if_open()
	if not _check_save_exists():
		# No save data, start immediately without confirmation
		if game_start_sound:
			game_start_sound.play()
		_transition_to_game("res://scenes/world.tscn", true)
		return
	is_confirming = true
	confirm_panel.visible = true
	confirm_no_button.grab_focus()

func _handle_confirm_input(viewport: Viewport):
	"""Handle gamepad input while confirmation dialog is open"""
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
		if input_cooldown <= 0:
			# Toggle between Yes and No
			var focused = viewport.gui_get_focus_owner()
			if focused == confirm_yes_button:
				confirm_no_button.grab_focus()
			else:
				confirm_yes_button.grab_focus()
			if button_nav_sound:
				button_nav_sound.play()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
	elif Input.is_action_just_pressed("jump"):
		var focused = viewport.gui_get_focus_owner()
		if focused is Button:
			focused.pressed.emit()
		viewport.set_input_as_handled()
	elif Input.is_action_just_pressed("go_back"):
		_on_confirm_no()
		viewport.set_input_as_handled()
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
		viewport.set_input_as_handled()

func _on_confirm_yes():
	"""Player confirmed new game - wipe data and transition"""
	is_confirming = false
	confirm_panel.visible = false
	if game_start_sound:
		game_start_sound.play()
	_transition_to_game("res://scenes/world.tscn", true)

func _on_confirm_no():
	"""Player cancelled new game"""
	is_confirming = false
	confirm_panel.visible = false
	new_game_button.grab_focus()

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

func _on_input_device_changed(device: InputDeviceManager.DeviceType) -> void:
	if device == InputDeviceManager.DeviceType.KEYBOARD_MOUSE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Release focus ring so mouse hover looks natural
		var focused = get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		# Restore gamepad focus on first available button
		if not continue_button.disabled:
			continue_button.grab_focus()
		else:
			new_game_button.grab_focus()

func _transition_to_game(scene_path: String, wipe_data: bool) -> void:
	"""Handle transition to game with character animation and fade"""
	if is_transitioning or SceneTransition.is_transitioning:
		return  # Prevent multiple transitions and block input during incoming fade-in

	# Close options menu if it's open
	if options_menu and options_menu.visible:
		options_menu.hide()

	is_transitioning = true

	# Stop listening for device changes during transition
	if InputDeviceManager.device_changed.is_connected(_on_input_device_changed):
		InputDeviceManager.device_changed.disconnect(_on_input_device_changed)

	# Disable input and fade out the menu UI
	set_process_input(false)
	var tween = create_tween()
	tween.tween_property(title_screen_ui, "modulate:a", 0.0, 0.5)

	# Wipe save data if needed (before animation to ensure it completes)
	if wipe_data:
		_wipe_save_data()

	# Start loading the next scene in the background while animations play
	ResourceLoader.load_threaded_request(scene_path)

	# Disconnect chaining signal so stopping doesn't start "pan"
	if camera_anim.animation_finished.is_connected(_on_camera_animation_finished):
		camera_anim.animation_finished.disconnect(_on_camera_animation_finished)

	# Play move in forward as the exit animation
	camera_anim.play("move in")

	# Play character exit concurrently
	if character and character.has_method("play_exit_animation"):
		character.play_exit_animation()

	await camera_anim.animation_finished

	# Reset UIManager to GAMEPLAY so mouse capture and camera input work in the world scene
	# (UIManager._ready() only runs once on first launch; this handles returning from title)
	@warning_ignore("INT_AS_ENUM_WITHOUT_MATCH")
	UIManager.current_state = -1 as UIManager.GameState
	UIManager.change_state(UIManager.GameState.GAMEPLAY)

	# Grab the preloaded scene and transition
	var scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	SceneTransition.fade_to_packed_scene(scene)

func _on_quit_pressed():
	"""Quit the game"""
	get_tree().quit()

func _wipe_save_data():
	"""Delete all save files and directories"""
	# Clear player data (in-memory + on disk)
	if UIManager:
		UIManager.clear_player_data()
	if FileAccess.file_exists("user://player_data.json"):
		DirAccess.remove_absolute("user://player_data.json")
		print("TitleScreen: Deleted player_data.json")

	# Clear mission progression (in-memory + on disk)
	if MissionManager:
		MissionManager.clear_progression()
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

	# Reset economy
	if EconomyManager:
		EconomyManager.set_money(0)

	# Reset studio assistant
	if AutomationManager:
		AutomationManager.clear_state()
		print("TitleScreen: Reset automation state")
	if FileAccess.file_exists("user://assistant_canvas.png"):
		DirAccess.remove_absolute("user://assistant_canvas.png")
		print("TitleScreen: Deleted assistant_canvas.png")

	# Clear sticker wall saves
	var user_dir = DirAccess.open("user://")
	if user_dir:
		user_dir.list_dir_begin()
		var fname = user_dir.get_next()
		while fname != "":
			if fname.begins_with("sticker_wall_") and fname.ends_with(".json"):
				DirAccess.remove_absolute("user://" + fname)
				print("TitleScreen: Deleted %s" % fname)
			fname = user_dir.get_next()
		user_dir.list_dir_end()

	# Clear all custom sticker PNGs (root folder + bought_stickers subfolder)
	for sticker_path in ["user://custom_stickers", "user://custom_stickers/bought_stickers"]:
		var sdir = DirAccess.open(sticker_path)
		if sdir:
			sdir.list_dir_begin()
			var sfname = sdir.get_next()
			while sfname != "":
				if not sdir.current_is_dir() and sfname.ends_with(".png"):
					DirAccess.remove_absolute(sticker_path + "/" + sfname)
					print("TitleScreen: Deleted custom sticker %s" % sfname)
				sfname = sdir.get_next()
			sdir.list_dir_end()

	# Reload StickerLibrary so in-memory sticker list matches the wiped disk state
	StickerLibrary.reload()

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

func _on_camera_animation_finished(anim_name: String):
	if anim_name == "move in":
		camera_anim.play("pan")

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
