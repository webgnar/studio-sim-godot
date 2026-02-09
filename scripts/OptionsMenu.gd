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
@onready var hue_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/VisualSettings/HueSlider
@onready var hue_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/VisualSettings/HueHeader/HueValue
@onready var saturation_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/VisualSettings/SaturationSlider
@onready var saturation_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/VisualSettings/SaturationHeader/SaturationValue
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var return_to_title_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ReturnToTitleButton
@onready var controls_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Controls/ScrollContainer/ControlsList
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
var slider_hold_timer: float = 0.0
var slider_hold_delay: float = 0.3  # Initial delay before repeating
var slider_repeat_rate: float = 0.05  # Time between repeats
var is_holding_slider: bool = false
var slider_direction: int = 0  # -1 for left, 1 for right
var keyboard_nav_enabled: bool = false
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15  # Cooldown between navigation inputs
var binding_labels: Array[Label] = []  # Labels showing current bindings in Controls tab

# Controls to display: [display_name, action_name_in_glyph_map]
var controls_entries: Array = [
	["Move", "move"],
	["Look", "look"],
	["Jump", "jump"],
	["Run", "run"],
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
	
	# Only connect hue and saturation sliders if they exist
	if hue_slider:
		hue_slider.value_changed.connect(_on_hue_slider_changed)
	if saturation_slider:
		saturation_slider.value_changed.connect(_on_saturation_slider_changed)
	
	close_button.pressed.connect(_on_close_pressed)
	return_to_title_button.pressed.connect(_on_return_to_title_pressed)

	# Hide close button when embedded (PauseMenu handles closing)
	# Show return-to-title only when embedded (not on title screen)
	if is_embedded:
		close_button.visible = false
		return_to_title_button.visible = true
	else:
		return_to_title_button.visible = false
	
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

	# Set up focus navigation
	_setup_focus_navigation()

func _process(delta):
	if not visible:
		return
	
	# Update input cooldown
	if input_cooldown > 0:
		input_cooldown -= delta
	
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
		if event.is_action_pressed("ui_left"):
			if input_cooldown <= 0:
				_switch_tab(-1)
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			if input_cooldown <= 0:
				_switch_tab(1)
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			if input_cooldown <= 0:
				# Enter content mode
				is_in_tab_mode = false
				_update_tab_mode_visual()
				_focus_first_content_item()
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up"):
			# In tab mode, up does nothing (stay at tabs, no looping)
			get_viewport().set_input_as_handled()
	else:
		# Content mode: navigate within content, up from first slider returns to tabs
		if event.is_action_pressed("ui_up"):
			if input_cooldown <= 0:
				var focused_control = get_viewport().gui_get_focus_owner()
				# Check if we're at the first focusable in current tab, if so return to tab mode
				if focused_control == sfx_slider or focused_control == hue_slider or (tab_container.current_tab == 2 and focused_control == return_to_title_button):
					is_in_tab_mode = true
					_update_tab_mode_visual()
					# Play navigation sound
					if button_nav_sound:
						button_nav_sound.play()
				else:
					# Navigate up (from music slider, hue slider, or Back button)
					_navigate_focus(-1)
					# Play navigation sound
					if button_nav_sound:
						button_nav_sound.play()
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			if input_cooldown <= 0:
				var focused_control = get_viewport().gui_get_focus_owner()
				# Navigate from sliders to buttons, but stop at bottom-most button
				if focused_control == close_button or focused_control == return_to_title_button:
					# Already at bottom, don't navigate further
					pass
				else:
					_navigate_focus(1)
					# Play navigation sound
					if button_nav_sound:
						button_nav_sound.play()
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()

		# Handle slider adjustment with left/right in content mode
		var focused = get_viewport().gui_get_focus_owner()
		if focused is HSlider:
			if event.is_action_pressed("ui_left"):
				focused.value -= focused.step
				is_holding_slider = true
				slider_direction = -1
				slider_hold_timer = 0.0
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_right"):
				focused.value += focused.step
				is_holding_slider = true
				slider_direction = 1
				slider_hold_timer = 0.0
				get_viewport().set_input_as_handled()
			elif event.is_action_released("ui_left") or event.is_action_released("ui_right"):
				is_holding_slider = false
				slider_hold_timer = 0.0
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

	# Reset input cooldown
	input_cooldown = 0.0

	# Set mouse mode to visible (skip when embedded - PauseMenu handles this)
	if not is_embedded:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Enable processing so _input gets called
	process_mode = Node.PROCESS_MODE_INHERIT

func _on_sfx_slider_changed(value: float):
	"""Handle SFX volume slider change"""
	AudioManager.set_sfx_volume(value)
	sfx_value_label.text = "%d%%" % int(value)

	# Play tick sound (but don't play for initial load)
	if tick_sound and is_node_ready():
		tick_sound.play()

	save_settings()

func _on_music_slider_changed(value: float):
	"""Handle Music volume slider change"""
	AudioManager.set_music_volume(value)
	music_value_label.text = "%d%%" % int(value)

	# Play tick sound (but don't play for initial load)
	if tick_sound and is_node_ready():
		tick_sound.play()

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

	# Play tick sound (but don't play for initial load)
	if tick_sound and is_node_ready():
		tick_sound.play()

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

	# Play tick sound (but don't play for initial load)
	if tick_sound and is_node_ready():
		tick_sound.play()

	save_settings()

func _on_close_pressed():
	"""Close the options menu"""
	# Play button hit sound first
	if button_hit_sound:
		button_hit_sound.play()

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

	# Also save audio settings (in case AudioManager.save_settings() wasn't called)
	settings["sfx_volume"] = AudioManager.sfx_volume
	settings["music_volume"] = AudioManager.music_volume

	# Write to file
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

func load_settings():
	"""Load all settings from disk"""
	# Load audio settings from AudioManager
	sfx_slider.value = AudioManager.sfx_volume
	music_slider.value = AudioManager.music_volume
	sfx_value_label.text = "%d%%" % int(AudioManager.sfx_volume)
	music_value_label.text = "%d%%" % int(AudioManager.music_volume)
	
	# Load visual settings only if hue slider exists
	if not hue_slider or not saturation_slider:
		return
	
	# Load visual settings
	if not FileAccess.file_exists("user://settings.json"):
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		saturation_slider.value = current_saturation
		saturation_value_label.text = "%.0f%%" % (current_saturation * 100)
		return
	
	var file = FileAccess.open("user://settings.json", FileAccess.READ)
	if not file:
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		saturation_slider.value = current_saturation
		saturation_value_label.text = "%.0f%%" % (current_saturation * 100)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		saturation_slider.value = current_saturation
		saturation_value_label.text = "%.0f%%" % (current_saturation * 100)
		return

	var settings = json.data
	if typeof(settings) != TYPE_DICTIONARY:
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		saturation_slider.value = current_saturation
		saturation_value_label.text = "%.0f%%" % (current_saturation * 100)
		return
	
	# Load hue value
	if settings.has("bg_hue"):
		current_hue = float(settings.bg_hue)
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)

	# Load saturation value
	if settings.has("bg_saturation"):
		current_saturation = float(settings.bg_saturation)
		saturation_slider.value = current_saturation
		saturation_value_label.text = "%.0f%%" % (current_saturation * 100)

	# Convert hue and saturation to color
	current_bg_color = Color.from_hsv(current_hue / 360.0, current_saturation, 0.3, 0.9)

	# Apply to theme
	if theme_panel_style:
		theme_panel_style.bg_color = current_bg_color

func _populate_controls_display():
	"""Build the controls list with label rows"""
	binding_labels.clear()
	for entry in controls_entries:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var action_label = Label.new()
		action_label.text = entry[0]
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_label.add_theme_font_size_override("font_size", 24)
		row.add_child(action_label)

		var binding_label = Label.new()
		binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		binding_label.add_theme_font_size_override("font_size", 24)
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

func _on_return_to_title_pressed():
	"""Quit and return to the title screen"""
	if button_hit_sound:
		button_hit_sound.play()

	# Reset UIManager state so autoload doesn't hold freed node references
	@warning_ignore("INT_AS_ENUM_WITHOUT_MATCH")
	UIManager.current_state = -1 as UIManager.GameState
	UIManager.pause_menu = null
	UIManager.main_menu = null
	UIManager.mission_selection = null
	UIManager.validation_result = null
	UIManager.shop_ui = null
	UIManager.hud = null

	# Reset CameraManager so its transition camera doesn't override the title screen camera
	CameraManager.player_camera = null
	CameraManager.current_camera = null
	CameraManager.active_zones.clear()
	if CameraManager.is_blending:
		CameraManager.is_blending = false
		CameraManager.set_process(false)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	SceneTransition.fade_to_scene("res://scenes/TitleScreen.tscn")

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
		if is_embedded and return_to_title_button.visible:
			return_to_title_button.grab_focus()

func _switch_tab(direction: int):
	"""Switch between tabs (Audio/Visual) - no looping"""
	var current_tab = tab_container.current_tab
	var new_tab = current_tab + direction

	# Clamp to valid tab range (no wrapping)
	new_tab = clamp(new_tab, 0, tab_container.get_tab_count() - 1)

	# Only change tab and play sound if we actually moved
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
	if tab_container.current_tab == 0:  # Audio tab
		close_button.focus_previous = close_button.get_path_to(music_slider)
	elif tab_container.current_tab == 1 and saturation_slider:  # Visual tab
		close_button.focus_previous = close_button.get_path_to(saturation_slider)
	elif tab_container.current_tab == 2:  # Controls tab
		close_button.focus_previous = close_button.get_path_to(return_to_title_button)

func _setup_focus_navigation():
	"""Set up focus navigation for controls"""
	# Enable focus for sliders and buttons
	sfx_slider.focus_mode = Control.FOCUS_ALL
	music_slider.focus_mode = Control.FOCUS_ALL
	close_button.focus_mode = Control.FOCUS_ALL
	return_to_title_button.focus_mode = Control.FOCUS_ALL

	# Set up focus neighbors for Audio tab
	sfx_slider.focus_neighbor_bottom = sfx_slider.get_path_to(music_slider)
	sfx_slider.focus_neighbor_top = sfx_slider.get_path_to(close_button)
	sfx_slider.focus_next = sfx_slider.get_path_to(music_slider)

	music_slider.focus_neighbor_top = music_slider.get_path_to(sfx_slider)
	music_slider.focus_neighbor_bottom = music_slider.get_path_to(close_button)
	music_slider.focus_previous = music_slider.get_path_to(sfx_slider)
	music_slider.focus_next = music_slider.get_path_to(close_button)

	# Set up focus for Visual tab only if sliders exist
	if hue_slider and saturation_slider:
		hue_slider.focus_mode = Control.FOCUS_ALL
		hue_slider.focus_neighbor_bottom = hue_slider.get_path_to(saturation_slider)
		hue_slider.focus_next = hue_slider.get_path_to(saturation_slider)

		saturation_slider.focus_mode = Control.FOCUS_ALL
		saturation_slider.focus_neighbor_top = saturation_slider.get_path_to(hue_slider)
		saturation_slider.focus_neighbor_bottom = saturation_slider.get_path_to(close_button)
		saturation_slider.focus_previous = saturation_slider.get_path_to(hue_slider)
		saturation_slider.focus_next = saturation_slider.get_path_to(close_button)

	# Close button navigation (will be updated per tab)
	close_button.focus_neighbor_top = close_button.get_path_to(music_slider)
	close_button.focus_neighbor_bottom = close_button.get_path_to(sfx_slider)
	close_button.focus_previous = close_button.get_path_to(music_slider)

	# Update close button focus for current tab
	_update_close_button_focus()
