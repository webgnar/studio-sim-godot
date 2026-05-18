extends Control

## OptionsMenu - Tabbed settings menu for Audio and Visual options
## Can be standalone or embedded inside PauseMenu

@export var is_embedded: bool = false

signal closed

@onready var tab_container: TabContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var sfx_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/AudioSettings/SFXSlider
@onready var music_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/AudioSettings/MusicSlider
@onready var sfx_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/AudioSettings/SFXHeader/SFXValue
@onready var music_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/AudioSettings/MusicHeader/MusicValue
@onready var painting_sounds_checkbox: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/AudioSettings/PaintingSoundsCheckbox
@onready var hue_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/ScrollContainer/VisualSettings/HueSlider
@onready var hue_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/ScrollContainer/VisualSettings/HueHeader/HueValue
@onready var saturation_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/ScrollContainer/VisualSettings/SaturationSlider
@onready var saturation_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/ScrollContainer/VisualSettings/SaturationHeader/SaturationValue
@onready var hud_hue_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/ScrollContainer/VisualSettings/HudHueSlider
@onready var hud_hue_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/ScrollContainer/VisualSettings/HBoxContainer/HudHueHeader/HudHueValue
@onready var hud_bg_checkbox: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/ScrollContainer/VisualSettings/HBoxContainer/HudBgCheckbox
@onready var visual_scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/ScrollContainer
var close_button: Button = null  # Removed from scene; closing handled by go_back/ESC
@onready var controls_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Controls/ScrollContainer/ControlsList
@onready var controls_scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Controls/ScrollContainer
@onready var stick_sensitivity_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Controls/SensitivitySection/SensitivitySlider
@onready var stick_sensitivity_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Controls/SensitivitySection/SensitivityHeader/SensitivityValue
@onready var language_button_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Language/ScrollContainer/ButtonContainer
@onready var language_scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Language/ScrollContainer
@onready var save_glb_checkbox: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/SaveGLBCheckbox
@onready var save_png_checkbox: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/SavePNGCheckbox
@onready var generate_critique_checkbox: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/GenerateCritiqueCheckbox
@onready var publish_online_checkbox: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/PublishOnlineCheckbox
@onready var instagram_line_edit: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/InstagramRow/InstagramLineEdit
@onready var bluesky_line_edit: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/BlueSkyRow/BlueSkyLineEdit
@onready var panel_container: PanelContainer = $PanelContainer
@onready var button_nav_sound: AudioStreamPlayer = $ButtonNavSound
@onready var open_menu_sound: AudioStreamPlayer = $OpenMenuSound
@onready var close_menu_sound: AudioStreamPlayer = $CloseMenuSound
@onready var tick_sound: AudioStreamPlayer = $TickSound
@onready var button_hit_sound: AudioStreamPlayer = get_node_or_null("ButtonHitSound")

var theme_panel_style: StyleBoxFlat = null
var current_bg_color: Color = Color(0.2, 0.2, 0.2, 0.9)  # Default from theme
var is_in_tab_mode: bool = true  # true = navigating tabs, false = navigating content
var current_hue: float = 0.0  # Hue value 0-360
var current_saturation: float = 0.3  # Saturation value 0.0-1.0
var current_hud_hue: float = 0.0  # HUD hue shift 0-360
var hud_bg_enabled: bool = true
var _is_loading: bool = false
var slider_hold_timer: float = 0.0
var slider_hold_delay: float = 0.3  # Initial delay before repeating
var slider_repeat_rate: float = 0.05  # Time between repeats
var is_holding_slider: bool = false
var slider_direction: int = 0  # -1 for left, 1 for right
var keyboard_nav_enabled: bool = false
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15  # Cooldown between navigation inputs
var _tab_nav_held: bool = false  # Prevent rapid tab cycling from held analog stick
var binding_labels: Array[Label] = []  # Labels showing current bindings in Controls tab
const CONTROLS_SCROLL_STEP: int = 60
var _in_controls_scroll: bool = false

# Controls to display: [display_name, action_name_in_glyph_map]
var controls_entries: Array = [
	["Move", "move"],
	["Look", "look"],
	["Jump", "jump"],
	["Run", "run"],
	["Crouch", "crouch"],
	["Interact", "interact"],
	["Paint", "action_primary"],
	["Drop", "action_secondary"],
	["Rotate CW", "rotate_clockwise"],
	["Rotate CCW", "rotate_counter"],
	["Scale Up", "scale_sticker_up"],
	["Scale Down", "scale_sticker_down"],
	["Next Sticker", "cycle_sticker_next"],
	["Prev Sticker", "cycle_sticker_prev"],
	["Back", "go_back"],
	["Pause", "start"],
]

func _ready():
	# Hide by default
	hide()

	# Disable processing when hidden so _input isn't called
	process_mode = Node.PROCESS_MODE_DISABLED

	# Initialize tab container to Audio tab (tab 0)
	tab_container.current_tab = 0

	# Connect signals
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	painting_sounds_checkbox.toggled.connect(_on_painting_sounds_toggled)
	
	# Only connect hue and saturation sliders if they exist
	if hue_slider:
		hue_slider.value_changed.connect(_on_hue_slider_changed)
	if saturation_slider:
		saturation_slider.value_changed.connect(_on_saturation_slider_changed)
	if hud_hue_slider:
		hud_hue_slider.value_changed.connect(_on_hud_hue_slider_changed)
	if hud_bg_checkbox:
		hud_bg_checkbox.toggled.connect(_on_hud_bg_toggled)
	stick_sensitivity_slider.value_changed.connect(_on_stick_sensitivity_changed)
	# Get theme panel style
	var theme_res = load("res://themes/ui_theme.tres")
	if theme_res:
		theme_panel_style = theme_res.get_stylebox("panel", "PanelContainer")
		if theme_panel_style:
			current_bg_color = theme_panel_style.bg_color
	
	# Load settings from AudioManager and file
	load_settings()

	# Build controls display and listen for device changes
	_populate_controls_display()
	InputDeviceManager.device_changed.connect(_on_device_changed)

	# Build language selector tab
	_create_language_tab()

	# Build game settings tab
	_create_game_tab()

	# Set up focus navigation
	_setup_focus_navigation()

func _process(delta):
	if not visible:
		return
	
	# Update input cooldown
	if input_cooldown > 0:
		input_cooldown -= delta

	# Reset tab nav held when stick returns to center
	if _tab_nav_held:
		if not Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_right") \
			and not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"):
			_tab_nav_held = false

	if not is_holding_slider:
		return
	
	slider_hold_timer += delta
	
	# Check if we should adjust the slider
	var should_adjust = false
	if slider_hold_timer >= slider_hold_delay:
		# After initial delay, repeat at regular intervals
		if slider_hold_timer >= slider_hold_delay + slider_repeat_rate:
			should_adjust = true
			slider_hold_timer = slider_hold_delay  # Reset to delay, so next repeat happens after repeat_rate
	
	if should_adjust:
		var focused = get_viewport().gui_get_focus_owner()
		if focused is HSlider:
			focused.value += focused.step * slider_direction

func _input(event):
	if not visible:
		return

	# Only process keyboard/gamepad input when enabled (mouse works via built-in Godot GUI)
	if not keyboard_nav_enabled:
		return

	# Don't intercept input while a LineEdit is focused — let it handle typing
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return

	# ESC or B button to close (when standalone) or go back to tab mode (when embedded)
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("go_back"):
		if is_embedded:
			if not is_in_tab_mode:
				# Return to tab mode within options
				is_in_tab_mode = true
				_update_tab_mode_visual()
				if button_nav_sound:
					button_nav_sound.play()
				get_viewport().set_input_as_handled()
			# When in tab mode and embedded, don't consume - let PauseMenu handle it
			return
		_on_close_pressed()
		get_viewport().set_input_as_handled()
		return

	if is_in_tab_mode:
		# Tab mode: left/right switches tabs, down enters content
		if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
			if not _tab_nav_held:
				_switch_tab(-1)
				_tab_nav_held = true
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
			if not _tab_nav_held:
				_switch_tab(1)
				_tab_nav_held = true
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
			if input_cooldown <= 0:
				# Enter content mode
				is_in_tab_mode = false
				_update_tab_mode_visual()
				_focus_first_content_item()
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
			if is_embedded:
				# Don't consume → PauseMenu catches and enters tab bar
				pass
			else:
				# Standalone: stay at tabs, no looping
				get_viewport().set_input_as_handled()
	else:
		# Content mode: navigate within content, up from first item returns to tabs
		if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
			if input_cooldown <= 0:
				if _in_controls_scroll:
					if controls_scroll_container.scroll_vertical <= 0:
						_in_controls_scroll = false
						stick_sensitivity_slider.grab_focus()
					else:
						controls_scroll_container.scroll_vertical -= CONTROLS_SCROLL_STEP
					if button_nav_sound:
						button_nav_sound.play()
					input_cooldown = input_cooldown_time
					get_viewport().set_input_as_handled()
					return
				var focused_control = get_viewport().gui_get_focus_owner()
				# Check if we're at the first focusable in current tab
				var is_first_in_tab = (focused_control == sfx_slider or focused_control == hue_slider
					or (tab_container.current_tab == 2 and focused_control == stick_sensitivity_slider)
					or (tab_container.current_tab == 3 and language_buttons.size() > 0 and focused_control == language_buttons[0])
					or (tab_container.current_tab == 4 and game_checkboxes.size() > 0 and focused_control == game_checkboxes[0]))
				if is_first_in_tab:
					is_in_tab_mode = true
					_update_tab_mode_visual()
					if button_nav_sound:
						button_nav_sound.play()
				else:
					_navigate_focus(-1)
					if button_nav_sound:
						button_nav_sound.play()
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
			if input_cooldown <= 0:
				var focused_control = get_viewport().gui_get_focus_owner()
				if tab_container.current_tab == 2 and (focused_control == stick_sensitivity_slider or _in_controls_scroll):
					if _in_controls_scroll:
						var sb = controls_scroll_container.get_v_scroll_bar()
						if controls_scroll_container.scroll_vertical >= sb.max_value - sb.page:
							if is_embedded:
								_in_controls_scroll = false
								return
							# Standalone: keep _in_controls_scroll = true so UP can scroll back up
						else:
							controls_scroll_container.scroll_vertical += CONTROLS_SCROLL_STEP
							if button_nav_sound:
								button_nav_sound.play()
					else:
						_in_controls_scroll = true
						stick_sensitivity_slider.release_focus()
						if button_nav_sound:
							button_nav_sound.play()
				elif _is_last_in_tab(focused_control):
					if is_embedded:
						# Don't consume → PauseMenu focuses ReturnToTitleButton
						return
					# Standalone: stay at bottom
				else:
					_navigate_focus(1)
					if button_nav_sound:
						button_nav_sound.play()
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()

		# Accept / A button: activate the focused control
		elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			var focused_btn = get_viewport().gui_get_focus_owner()
			if focused_btn is CheckBox:
				focused_btn.button_pressed = not focused_btn.button_pressed
				get_viewport().set_input_as_handled()
			elif focused_btn is Button:
				focused_btn.pressed.emit()
				get_viewport().set_input_as_handled()

		# Handle slider adjustment with left/right in content mode
		var focused = get_viewport().gui_get_focus_owner()
		if focused is HSlider:
			if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
				focused.value -= focused.step
				is_holding_slider = true
				slider_direction = -1
				slider_hold_timer = 0.0
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
				focused.value += focused.step
				is_holding_slider = true
				slider_direction = 1
				slider_hold_timer = 0.0
				get_viewport().set_input_as_handled()
			elif event.is_action_released("ui_left") or event.is_action_released("ui_right") \
				or event.is_action_released("move_left") or event.is_action_released("move_right"):
				is_holding_slider = false
				slider_hold_timer = 0.0
				get_viewport().set_input_as_handled()
		else:
			# Non-slider controls don't use left/right — consume so TabContainer doesn't switch tabs
			if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left") \
					or event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
				get_viewport().set_input_as_handled()

func show_menu():
	"""Show the options menu"""
	show()

	# Play open menu sound (skip when embedded - PauseMenu handles sounds)
	if open_menu_sound and not is_embedded:
		open_menu_sound.play()

	# Ensure menu is above other UI layers (skip when embedded - PauseMenu handles layering)
	if not is_embedded:
		z_index = 100

	# Always start on Audio tab (tab 0)
	tab_container.current_tab = 0

	# Update close button focus for current tab
	_update_close_button_focus()

	# Start in tab mode
	is_in_tab_mode = true
	_update_tab_mode_visual()

	# Enable keyboard nav (standalone always has it; embedded waits for PauseMenu)
	if not is_embedded:
		keyboard_nav_enabled = true

	# Apply current sensitivity to player (reliable since player is in scene by now)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].joystick_sensitivity_multiplier = joystick_sensitivity

	# Reset input cooldown
	input_cooldown = 0.0
	_tab_nav_held = false

	# Set mouse mode to visible (skip when embedded - PauseMenu handles this)
	if not is_embedded:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Enable processing so _input gets called
	process_mode = Node.PROCESS_MODE_INHERIT

func _on_sfx_slider_changed(value: float):
	"""Handle SFX volume slider change"""
	AudioManager.set_sfx_volume(value)
	sfx_value_label.text = "%d%%" % int(value)
	save_settings()

func _on_music_slider_changed(value: float):
	"""Handle Music volume slider change"""
	AudioManager.set_music_volume(value)
	music_value_label.text = "%d%%" % int(value)
	save_settings()

func _on_painting_sounds_toggled(pressed: bool):
	AudioManager.painting_sounds_enabled = pressed
	save_settings()

func _on_hue_slider_changed(value: float):
	"""Handle hue slider change"""
	current_hue = value
	hue_value_label.text = "%d°" % int(value)

	# Convert hue to color (using HSV with current saturation and fixed value)
	current_bg_color = Color.from_hsv(value / 360.0, current_saturation, 0.3, 0.9)

	# Update the theme panel style
	if theme_panel_style:
		theme_panel_style.bg_color = current_bg_color

	save_settings()

func _on_saturation_slider_changed(value: float):
	"""Handle saturation slider change"""
	current_saturation = value
	saturation_value_label.text = "%.0f%%" % (value * 100)

	# Update color with new saturation
	current_bg_color = Color.from_hsv(current_hue / 360.0, current_saturation, 0.3, 0.9)

	# Update the theme panel style
	if theme_panel_style:
		theme_panel_style.bg_color = current_bg_color

	save_settings()

func _on_hud_hue_slider_changed(value: float):
	"""Handle HUD hue slider change"""
	current_hud_hue = value
	hud_hue_value_label.text = "%d°" % int(value)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("apply_hud_hue"):
		hud.apply_hud_hue(value)
	save_settings()

func _on_hud_bg_toggled(pressed: bool):
	"""Handle HUD background checkbox toggle"""
	hud_bg_enabled = pressed
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("apply_hud_bg_visible"):
		hud.apply_hud_bg_visible(pressed)
	save_settings()

func _on_stick_sensitivity_changed(value: float):
	"""Handle right stick sensitivity slider change"""
	joystick_sensitivity = value
	stick_sensitivity_value_label.text = "%d%%" % int(value / 5.0)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].joystick_sensitivity_multiplier = value
	save_settings()

func _on_close_pressed():
	"""Close the options menu"""
	hide()

	# Play close menu sound
	if close_menu_sound:
		close_menu_sound.play()

	# Reset z-index
	z_index = 0

	# Disable processing when hidden so _input isn't called
	process_mode = Node.PROCESS_MODE_DISABLED

	closed.emit()

func save_settings():
	"""Save all settings to disk"""
	if _is_loading:
		return
	# AudioManager handles audio settings
	AudioManager.save_settings()
	
	# Save visual settings
	var settings = {}
	
	# Load existing settings first
	if FileAccess.file_exists("user://settings.json"):
		var read_file = FileAccess.open("user://settings.json", FileAccess.READ)
		if read_file:
			var json_string = read_file.get_as_text()
			read_file.close()

			var json = JSON.new()
			if json.parse(json_string) == OK:
				settings = json.data

	# Update visual settings - save hue and saturation
	settings["bg_hue"] = current_hue
	settings["bg_saturation"] = current_saturation
	settings["hud_hue"] = current_hud_hue
	settings["hud_bg"] = hud_bg_enabled

	# Save game settings
	settings["save_glb_on_ship"] = save_glb_on_ship
	settings["save_png_on_ship"] = save_png_on_ship
	settings["generate_npc_critique"] = generate_npc_critique
	settings["publish_online_on_ship"] = publish_online_on_ship
	settings["instagram_handle"] = instagram_handle
	settings["bluesky_handle"] = bluesky_handle
	settings["joystick_sensitivity"] = joystick_sensitivity

	# Also save audio settings (in case AudioManager.save_settings() wasn't called)
	settings["sfx_volume"] = AudioManager.sfx_volume
	settings["music_volume"] = AudioManager.music_volume
	settings["painting_sounds"] = AudioManager.painting_sounds_enabled

	# Write to file
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

func load_settings():
	"""Load all settings from disk"""
	_is_loading = true
	# Load audio settings from AudioManager
	sfx_slider.value = AudioManager.sfx_volume
	music_slider.value = AudioManager.music_volume
	sfx_value_label.text = "%d%%" % int(AudioManager.sfx_volume)
	music_value_label.text = "%d%%" % int(AudioManager.music_volume)
	painting_sounds_checkbox.set_pressed_no_signal(AudioManager.painting_sounds_enabled)
	
	# Load visual settings only if hue slider exists
	if not hue_slider or not saturation_slider:
		_is_loading = false
		return
	
	# Load visual settings
	if not FileAccess.file_exists("user://settings.json"):
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		saturation_slider.value = current_saturation
		saturation_value_label.text = "%.0f%%" % (current_saturation * 100)
		_is_loading = false
		return

	var file = FileAccess.open("user://settings.json", FileAccess.READ)
	if not file:
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		saturation_slider.value = current_saturation
		saturation_value_label.text = "%.0f%%" % (current_saturation * 100)
		_is_loading = false
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		saturation_slider.value = current_saturation
		saturation_value_label.text = "%.0f%%" % (current_saturation * 100)
		_is_loading = false
		return

	var settings = json.data
	if typeof(settings) != TYPE_DICTIONARY:
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		saturation_slider.value = current_saturation
		saturation_value_label.text = "%.0f%%" % (current_saturation * 100)
		_is_loading = false
		return
	
	# Load hue value
	var has_hue_setting = settings.has("bg_hue")
	var has_sat_setting = settings.has("bg_saturation")

	if has_hue_setting:
		current_hue = float(settings.bg_hue)
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)

	# Load saturation value
	if has_sat_setting:
		current_saturation = float(settings.bg_saturation)
		saturation_slider.value = current_saturation
		saturation_value_label.text = "%.0f%%" % (current_saturation * 100)

	# Only override the theme color if the user has explicitly saved visual settings.
	# Without this guard, default values produce a dark gray that overlays all menus.
	if has_hue_setting or has_sat_setting:
		current_bg_color = Color.from_hsv(current_hue / 360.0, current_saturation, 0.3, 0.9)
		if theme_panel_style:
			theme_panel_style.bg_color = current_bg_color

	# Load HUD hue value
	if settings.has("hud_hue"):
		current_hud_hue = float(settings["hud_hue"])
		if hud_hue_slider:
			hud_hue_slider.value = current_hud_hue
		if hud_hue_value_label:
			hud_hue_value_label.text = "%d°" % int(current_hud_hue)
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("apply_hud_hue"):
			hud.apply_hud_hue(current_hud_hue)
	elif hud_hue_slider:
		hud_hue_slider.value = 0.0
		if hud_hue_value_label:
			hud_hue_value_label.text = "0°"

	# Load HUD background setting
	if settings.has("hud_bg"):
		hud_bg_enabled = bool(settings["hud_bg"])
		if hud_bg_checkbox:
			hud_bg_checkbox.set_pressed_no_signal(hud_bg_enabled)
		var hud_bg_node = get_tree().get_first_node_in_group("hud")
		if hud_bg_node and hud_bg_node.has_method("apply_hud_bg_visible"):
			hud_bg_node.apply_hud_bg_visible(hud_bg_enabled)
	elif hud_bg_checkbox:
		hud_bg_checkbox.set_pressed_no_signal(true)

	# Load game settings
	if settings.has("save_glb_on_ship"):
		save_glb_on_ship = bool(settings["save_glb_on_ship"])
	if settings.has("save_png_on_ship"):
		save_png_on_ship = bool(settings["save_png_on_ship"])
	if settings.has("generate_npc_critique"):
		generate_npc_critique = bool(settings["generate_npc_critique"])
	if settings.has("publish_online_on_ship"):
		publish_online_on_ship = bool(settings["publish_online_on_ship"])
	if settings.has("instagram_handle"):
		instagram_handle = str(settings["instagram_handle"])
		instagram_line_edit.text = instagram_handle
	if settings.has("bluesky_handle"):
		bluesky_handle = str(settings["bluesky_handle"])
		bluesky_line_edit.text = bluesky_handle
	save_glb_checkbox.button_pressed = save_glb_on_ship
	save_png_checkbox.button_pressed = save_png_on_ship
	generate_critique_checkbox.button_pressed = generate_npc_critique
	publish_online_checkbox.button_pressed = publish_online_on_ship

	# Load sensitivity setting
	if settings.has("joystick_sensitivity"):
		joystick_sensitivity = float(settings["joystick_sensitivity"])
		stick_sensitivity_slider.value = joystick_sensitivity
		stick_sensitivity_value_label.text = "%d%%" % int(joystick_sensitivity / 5.0)
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			players[0].joystick_sensitivity_multiplier = joystick_sensitivity

	_is_loading = false

func _populate_controls_display():
	"""Build the controls list with label rows"""
	binding_labels.clear()
	for entry in controls_entries:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var action_label = Label.new()
		action_label.text = tr(entry[0])
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_label.add_theme_font_size_override("font_size", 32)
		row.add_child(action_label)

		var binding_label = Label.new()
		binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		binding_label.add_theme_font_size_override("font_size", 32)
		row.add_child(binding_label)
		binding_labels.append(binding_label)

		controls_list.add_child(row)

	_update_controls_display()

func _update_controls_display():
	"""Update binding labels for the current input device"""
	for i in range(controls_entries.size()):
		var action_name = controls_entries[i][1]
		binding_labels[i].text = InputDeviceManager.get_action_glyph(action_name)

func _on_device_changed(_new_device):
	_update_controls_display()

var language_buttons: Array[Button] = []

var save_glb_on_ship: bool = true
var save_png_on_ship: bool = true
var generate_npc_critique: bool = true
var publish_online_on_ship: bool = true
var instagram_handle: String = ""
var bluesky_handle: String = ""
var game_checkboxes: Array[CheckBox] = []
var joystick_sensitivity: float = 500.0

func _create_language_tab():
	"""Populate the Language tab (scene container) with locale selection buttons"""
	for locale in LocaleManager.SUPPORTED_LOCALES:
		var btn = Button.new()
		btn.text = LocaleManager.LOCALE_NAMES[locale]
		btn.focus_mode = Control.FOCUS_ALL
		var flag_path := "res://sprites/ui/flags/%s.png" % locale
		if ResourceLoader.exists(flag_path):
			btn.icon = load(flag_path)
		btn.pressed.connect(_on_language_selected.bind(locale))
		btn.focus_entered.connect(_scroll_to_language_button.bind(btn))
		language_button_container.add_child(btn)
		language_buttons.append(btn)

	# Set up focus chain for language buttons
	for i in range(language_buttons.size()):
		if i > 0:
			language_buttons[i].focus_previous = language_buttons[i].get_path_to(language_buttons[i - 1])
			language_buttons[i].focus_neighbor_top = language_buttons[i].get_path_to(language_buttons[i - 1])
		if i < language_buttons.size() - 1:
			language_buttons[i].focus_next = language_buttons[i].get_path_to(language_buttons[i + 1])
			language_buttons[i].focus_neighbor_bottom = language_buttons[i].get_path_to(language_buttons[i + 1])

	# Highlight current language
	_update_language_buttons()

func _scroll_to_language_button(btn: Button) -> void:
	"""Scroll the language list so the focused button is visible"""
	await get_tree().process_frame
	if not is_instance_valid(btn) or not is_instance_valid(language_scroll_container):
		return
	var btn_top := btn.position.y
	var btn_bottom := btn_top + btn.size.y
	var scroll_pos := language_scroll_container.scroll_vertical
	var viewport_height := language_scroll_container.size.y
	if btn_top < scroll_pos:
		language_scroll_container.scroll_vertical = int(btn_top)
	elif btn_bottom > scroll_pos + viewport_height:
		language_scroll_container.scroll_vertical = int(btn_bottom - viewport_height)


func _on_language_selected(locale: String):
	"""Handle language button press"""
	LocaleManager.set_locale(locale)
	_update_language_buttons()

	# Rebuild controls display with translated labels
	for child in controls_list.get_children():
		child.queue_free()
	binding_labels.clear()
	_populate_controls_display()

	if button_hit_sound:
		button_hit_sound.play()

func _update_language_buttons():
	"""Highlight the currently selected language button"""
	for i in range(language_buttons.size()):
		var btn = language_buttons[i]
		var locale = LocaleManager.SUPPORTED_LOCALES[i]
		if locale == LocaleManager.current_locale:
			btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _create_game_tab():
	"""Set up the Game tab (scene nodes) with signals and focus chain"""
	save_glb_checkbox.button_pressed = save_glb_on_ship
	save_glb_checkbox.focus_mode = Control.FOCUS_ALL
	save_png_checkbox.button_pressed = save_png_on_ship
	save_png_checkbox.focus_mode = Control.FOCUS_ALL
	generate_critique_checkbox.button_pressed = generate_npc_critique
	generate_critique_checkbox.focus_mode = Control.FOCUS_ALL

	publish_online_checkbox.button_pressed = publish_online_on_ship
	publish_online_checkbox.focus_mode = Control.FOCUS_ALL

	# Wire focus chain: glb → png → critique → publish
	save_glb_checkbox.focus_next = save_glb_checkbox.get_path_to(save_png_checkbox)
	save_glb_checkbox.focus_neighbor_bottom = save_glb_checkbox.get_path_to(save_png_checkbox)
	save_png_checkbox.focus_previous = save_png_checkbox.get_path_to(save_glb_checkbox)
	save_png_checkbox.focus_neighbor_top = save_png_checkbox.get_path_to(save_glb_checkbox)
	save_png_checkbox.focus_next = save_png_checkbox.get_path_to(generate_critique_checkbox)
	save_png_checkbox.focus_neighbor_bottom = save_png_checkbox.get_path_to(generate_critique_checkbox)
	generate_critique_checkbox.focus_previous = generate_critique_checkbox.get_path_to(save_png_checkbox)
	generate_critique_checkbox.focus_neighbor_top = generate_critique_checkbox.get_path_to(save_png_checkbox)
	generate_critique_checkbox.focus_next = generate_critique_checkbox.get_path_to(publish_online_checkbox)
	generate_critique_checkbox.focus_neighbor_bottom = generate_critique_checkbox.get_path_to(publish_online_checkbox)
	publish_online_checkbox.focus_previous = publish_online_checkbox.get_path_to(generate_critique_checkbox)
	publish_online_checkbox.focus_neighbor_top = publish_online_checkbox.get_path_to(generate_critique_checkbox)

	# Set up social handle inputs
	instagram_line_edit.text = instagram_handle
	instagram_line_edit.focus_mode = Control.FOCUS_ALL
	bluesky_line_edit.text = bluesky_handle
	bluesky_line_edit.focus_mode = Control.FOCUS_ALL

	# Extend focus chain: publish → instagram → bluesky
	publish_online_checkbox.focus_next = publish_online_checkbox.get_path_to(instagram_line_edit)
	publish_online_checkbox.focus_neighbor_bottom = publish_online_checkbox.get_path_to(instagram_line_edit)
	instagram_line_edit.focus_previous = instagram_line_edit.get_path_to(publish_online_checkbox)
	instagram_line_edit.focus_neighbor_top = instagram_line_edit.get_path_to(publish_online_checkbox)
	instagram_line_edit.focus_next = instagram_line_edit.get_path_to(bluesky_line_edit)
	instagram_line_edit.focus_neighbor_bottom = instagram_line_edit.get_path_to(bluesky_line_edit)
	bluesky_line_edit.focus_previous = bluesky_line_edit.get_path_to(instagram_line_edit)
	bluesky_line_edit.focus_neighbor_top = bluesky_line_edit.get_path_to(instagram_line_edit)

	# Connect signals after setting button_pressed to avoid triggering save_settings()
	save_glb_checkbox.toggled.connect(_on_save_glb_toggled)
	save_png_checkbox.toggled.connect(_on_save_png_toggled)
	generate_critique_checkbox.toggled.connect(_on_generate_critique_toggled)
	publish_online_checkbox.toggled.connect(_on_publish_online_toggled)
	instagram_line_edit.text_changed.connect(_on_instagram_changed)
	bluesky_line_edit.text_changed.connect(_on_bluesky_changed)

	game_checkboxes = [save_glb_checkbox, save_png_checkbox, generate_critique_checkbox, publish_online_checkbox]

func _on_save_glb_toggled(pressed: bool):
	save_glb_on_ship = pressed
	save_settings()

func _on_save_png_toggled(pressed: bool):
	save_png_on_ship = pressed
	save_settings()

func _on_generate_critique_toggled(pressed: bool):
	generate_npc_critique = pressed
	save_settings()

func _on_publish_online_toggled(pressed: bool):
	publish_online_on_ship = pressed
	save_settings()

func _on_instagram_changed(new_text: String):
	instagram_handle = new_text
	save_settings()

func _on_bluesky_changed(new_text: String):
	bluesky_handle = new_text
	save_settings()

func _is_last_in_tab(focused_control: Control) -> bool:
	"""Check if the focused control is the last focusable item in the current tab"""
	match tab_container.current_tab:
		0:  # Audio
			return focused_control == painting_sounds_checkbox
		1:  # Visual
			if hud_hue_slider:
				return focused_control == hud_hue_slider
			elif hud_bg_checkbox:
				return focused_control == hud_bg_checkbox
			return focused_control == saturation_slider
		2:  # Controls
			if _in_controls_scroll:
				var sb = controls_scroll_container.get_v_scroll_bar()
				return controls_scroll_container.scroll_vertical >= sb.max_value - sb.page
			return false
		3:  # Language
			return language_buttons.size() > 0 and focused_control == language_buttons[-1]
		4:  # Game
			return focused_control == bluesky_line_edit
	return false

func _focus_last_content_item():
	"""Focus the last focusable item in current tab (called by PauseMenu)"""
	_update_tab_mode_visual()
	match tab_container.current_tab:
		0:  # Audio
			painting_sounds_checkbox.grab_focus()
		1:  # Visual
			if hud_hue_slider:
				hud_hue_slider.grab_focus()
			elif hud_bg_checkbox:
				hud_bg_checkbox.grab_focus()
			elif saturation_slider:
				saturation_slider.grab_focus()
		2:  # Controls
			_in_controls_scroll = true
			stick_sensitivity_slider.release_focus()
			controls_scroll_container.scroll_vertical = 999999
		3:  # Language
			if language_buttons.size() > 0:
				language_buttons[-1].grab_focus()
		4:  # Game
			bluesky_line_edit.grab_focus()

func _navigate_focus(direction: int):
	"""Navigate focus up/down through controls"""
	var focused = get_viewport().gui_get_focus_owner()
	if not focused:
		sfx_slider.grab_focus()
		return
	
	if direction < 0:  # Move up
		if focused.focus_previous:
			focused.get_node(focused.focus_previous).grab_focus()
	else:  # Move down
		if focused.focus_next:
			focused.get_node(focused.focus_next).grab_focus()

func _focus_first_content_item():
	"""Focus the first item in the current tab's content"""
	if tab_container.current_tab == 0:  # Audio tab
		sfx_slider.grab_focus()
	elif tab_container.current_tab == 1:  # Visual tab
		if hue_slider:
			hue_slider.grab_focus()
	elif tab_container.current_tab == 2:  # Controls tab
		_in_controls_scroll = false
		controls_scroll_container.scroll_vertical = 0
		stick_sensitivity_slider.grab_focus()
	elif tab_container.current_tab == 3:  # Language tab
		if language_buttons.size() > 0:
			language_buttons[0].grab_focus()
	elif tab_container.current_tab == 4:  # Game tab
		if game_checkboxes.size() > 0:
			game_checkboxes[0].grab_focus()

func _switch_tab(direction: int):
	"""Switch between tabs (Audio/Visual) - no looping"""
	var current_tab = tab_container.current_tab
	var new_tab = current_tab + direction

	# Clamp to valid tab range (no wrapping)
	new_tab = clamp(new_tab, 0, tab_container.get_tab_count() - 1)

	# Only change tab and play sound if we actually moved
	_in_controls_scroll = false
	if new_tab != current_tab:
		tab_container.current_tab = new_tab
		# Update close button focus for new tab
		_update_close_button_focus()
		# Play navigation sound
		if button_nav_sound:
			button_nav_sound.play()

func _update_tab_mode_visual():
	"""Update visual indicator for tab mode"""
	if is_in_tab_mode:
		# Highlight tab container with subtle cyan tint when in tab mode
		tab_container.modulate = Color(0.7, 1.0, 1.0, 1.0)
	else:
		# Normal white (no tint) when in content mode
		tab_container.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _update_close_button_focus():
	"""Update close button focus navigation based on current tab"""
	if close_button == null:
		return
	if tab_container.current_tab == 0:  # Audio tab
		close_button.focus_previous = close_button.get_path_to(painting_sounds_checkbox)
	elif tab_container.current_tab == 1:  # Visual tab
		if hud_hue_slider:
			close_button.focus_previous = close_button.get_path_to(hud_hue_slider)
		elif hud_bg_checkbox:
			close_button.focus_previous = close_button.get_path_to(hud_hue_slider)
		elif saturation_slider:
			close_button.focus_previous = close_button.get_path_to(saturation_slider)
	elif tab_container.current_tab == 2:  # Controls tab
		pass  # No focusable items in Controls tab

func _setup_focus_navigation():
	"""Set up focus navigation for controls"""
	# Enable focus for sliders
	sfx_slider.focus_mode = Control.FOCUS_ALL
	music_slider.focus_mode = Control.FOCUS_ALL
	stick_sensitivity_slider.focus_mode = Control.FOCUS_ALL
	painting_sounds_checkbox.focus_mode = Control.FOCUS_ALL

	# Set up focus neighbors for Audio tab
	sfx_slider.focus_next = sfx_slider.get_path_to(music_slider)
	sfx_slider.focus_neighbor_bottom = sfx_slider.get_path_to(music_slider)

	music_slider.focus_previous = music_slider.get_path_to(sfx_slider)
	music_slider.focus_neighbor_top = music_slider.get_path_to(sfx_slider)
	music_slider.focus_next = music_slider.get_path_to(painting_sounds_checkbox)
	music_slider.focus_neighbor_bottom = music_slider.get_path_to(painting_sounds_checkbox)

	painting_sounds_checkbox.focus_previous = painting_sounds_checkbox.get_path_to(music_slider)
	painting_sounds_checkbox.focus_neighbor_top = painting_sounds_checkbox.get_path_to(music_slider)

	# Set up focus for Visual tab only if sliders exist
	if hue_slider and saturation_slider:
		hue_slider.focus_mode = Control.FOCUS_ALL
		hue_slider.focus_next = hue_slider.get_path_to(saturation_slider)
		hue_slider.focus_neighbor_bottom = hue_slider.get_path_to(saturation_slider)

		saturation_slider.focus_mode = Control.FOCUS_ALL
		saturation_slider.focus_previous = saturation_slider.get_path_to(hue_slider)
		saturation_slider.focus_neighbor_top = saturation_slider.get_path_to(hue_slider)

	if hud_bg_checkbox and saturation_slider:
		saturation_slider.focus_next = saturation_slider.get_path_to(hud_bg_checkbox)
		saturation_slider.focus_neighbor_bottom = saturation_slider.get_path_to(hud_bg_checkbox)

		hud_bg_checkbox.focus_mode = Control.FOCUS_ALL
		hud_bg_checkbox.focus_previous = hud_bg_checkbox.get_path_to(saturation_slider)
		hud_bg_checkbox.focus_neighbor_top = hud_bg_checkbox.get_path_to(saturation_slider)

	if hud_bg_checkbox and hud_hue_slider:
		hud_bg_checkbox.focus_next = hud_bg_checkbox.get_path_to(hud_hue_slider)
		hud_bg_checkbox.focus_neighbor_bottom = hud_bg_checkbox.get_path_to(hud_hue_slider)
		hud_hue_slider.focus_mode = Control.FOCUS_ALL
		hud_hue_slider.focus_previous = hud_hue_slider.get_path_to(hud_bg_checkbox)
		hud_hue_slider.focus_neighbor_top = hud_hue_slider.get_path_to(hud_bg_checkbox)

	if close_button != null:
		if is_embedded:
			# When embedded, close button is hidden - don't include in focus chain
			close_button.focus_mode = Control.FOCUS_NONE
		else:
			# Standalone: include close button in focus chain after painting_sounds_checkbox
			close_button.focus_mode = Control.FOCUS_ALL
			painting_sounds_checkbox.focus_next = painting_sounds_checkbox.get_path_to(close_button)
			painting_sounds_checkbox.focus_neighbor_bottom = painting_sounds_checkbox.get_path_to(close_button)
			close_button.focus_previous = close_button.get_path_to(painting_sounds_checkbox)
			close_button.focus_neighbor_top = close_button.get_path_to(painting_sounds_checkbox)
			if hud_hue_slider:
				hud_hue_slider.focus_next = hud_hue_slider.get_path_to(close_button)
				hud_hue_slider.focus_neighbor_bottom = hud_hue_slider.get_path_to(close_button)
			elif hud_bg_checkbox:
				hud_bg_checkbox.focus_next = hud_bg_checkbox.get_path_to(close_button)
				hud_bg_checkbox.focus_neighbor_bottom = hud_bg_checkbox.get_path_to(close_button)
			elif hud_hue_slider:
				hud_hue_slider.focus_next = hud_hue_slider.get_path_to(close_button)
				hud_hue_slider.focus_neighbor_bottom = hud_hue_slider.get_path_to(close_button)
			elif saturation_slider:
				saturation_slider.focus_next = saturation_slider.get_path_to(close_button)
				saturation_slider.focus_neighbor_bottom = saturation_slider.get_path_to(close_button)
			_update_close_button_focus()
