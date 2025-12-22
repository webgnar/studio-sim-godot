extends Control

## OptionsMenu - Tabbed settings menu for Audio and Visual options

signal closed

@onready var tab_container: TabContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var sfx_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/AudioSettings/SFXSlider
@onready var music_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/AudioSettings/MusicSlider
@onready var sfx_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/AudioSettings/SFXValue
@onready var music_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/AudioSettings/MusicValue
@onready var hue_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/VisualSettings/HueSlider
@onready var hue_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Visual/VisualSettings/HueValue
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var panel_container: PanelContainer = $PanelContainer

var theme_panel_style: StyleBoxFlat = null
var current_bg_color: Color = Color(0.2, 0.2, 0.2, 0.9)  # Default from theme
var is_in_tab_mode: bool = true  # true = navigating tabs, false = navigating content
var current_hue: float = 0.0  # Hue value 0-360
var slider_hold_timer: float = 0.0
var slider_hold_delay: float = 0.3  # Initial delay before repeating
var slider_repeat_rate: float = 0.05  # Time between repeats
var is_holding_slider: bool = false
var slider_direction: int = 0  # -1 for left, 1 for right
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15  # Cooldown between navigation inputs

func _ready():
	# Hide by default
	hide()
	
	# Connect signals
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	
	# Only connect hue slider if it exists
	if hue_slider:
		hue_slider.value_changed.connect(_on_hue_slider_changed)
	
	close_button.pressed.connect(_on_close_pressed)
	
	# Get theme panel style
	var theme_res = load("res://themes/ui_theme.tres")
	if theme_res:
		theme_panel_style = theme_res.get_stylebox("panel", "PanelContainer")
		if theme_panel_style:
			current_bg_color = theme_panel_style.bg_color
	
	# Load settings from AudioManager and file
	load_settings()
	
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
	
	# ESC or B button to close
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("go_back"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
		return
	
	if is_in_tab_mode:
		# Tab mode: left/right switches tabs, down enters content
		if Input.is_action_just_pressed("ui_left"):
			if input_cooldown <= 0:
				_switch_tab(-1)
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
		elif Input.is_action_just_pressed("ui_right"):
			if input_cooldown <= 0:
				_switch_tab(1)
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
		elif Input.is_action_just_pressed("ui_down"):
			if input_cooldown <= 0:
				# Enter content mode
				is_in_tab_mode = false
				_focus_first_content_item()
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
	else:
		# Content mode: navigate within content, up returns to tabs
		if Input.is_action_just_pressed("ui_up"):
			if input_cooldown <= 0:
				var focused = get_viewport().gui_get_focus_owner()
				# Check if we're at the first item, if so return to tab mode
				if focused == sfx_slider or focused == hue_slider:
					is_in_tab_mode = true
				else:
					_navigate_focus(-1)
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
		elif Input.is_action_just_pressed("ui_down"):
			if input_cooldown <= 0:
				_navigate_focus(1)
				input_cooldown = input_cooldown_time
			get_viewport().set_input_as_handled()
		
		# Handle slider adjustment with left/right in content mode
		var focused = get_viewport().gui_get_focus_owner()
		if focused is HSlider:
			if Input.is_action_just_pressed("ui_left"):
				focused.value -= focused.step
				is_holding_slider = true
				slider_direction = -1
				slider_hold_timer = 0.0
				get_viewport().set_input_as_handled()
			elif Input.is_action_just_pressed("ui_right"):
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
	
	# Ensure menu is above other UI layers
	z_index = 100
	
	# Start in tab mode
	is_in_tab_mode = true
	
	# Reset input cooldown
	input_cooldown = 0.0
	
	# Set mouse mode to visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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

func _on_hue_slider_changed(value: float):
	"""Handle hue slider change"""
	current_hue = value
	hue_value_label.text = "%d°" % int(value)
	
	# Convert hue to color (using HSV with full saturation and value)
	current_bg_color = Color.from_hsv(value / 360.0, 0.3, 0.3, 0.9)
	
	# Update the theme panel style
	if theme_panel_style:
		theme_panel_style.bg_color = current_bg_color
	
	save_settings()

func _on_close_pressed():
	"""Close the options menu"""
	hide()
	
	# Reset z-index
	z_index = 0
	
	closed.emit()

func save_settings():
	"""Save all settings to disk"""
	# AudioManager handles audio settings
	AudioManager.save_settings()
	
	# Save visual settings
	var settings = {}
	
	# Load existing settings first
	if FileAccess.file_exists("user://settings.json"):
		var file = FileAccess.open("user://settings.json", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_string) == OK:
				settings = json.data
	
	# Update visual settings - save hue instead of RGBA
	settings["bg_hue"] = current_hue
	
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
	if not hue_slider:
		return
	
	# Load visual settings
	if not FileAccess.file_exists("user://settings.json"):
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		return
	
	var file = FileAccess.open("user://settings.json", FileAccess.READ)
	if not file:
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		return
	
	var settings = json.data
	if typeof(settings) != TYPE_DICTIONARY:
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		return
	
	# Load hue value
	if settings.has("bg_hue"):
		current_hue = float(settings.bg_hue)
		hue_slider.value = current_hue
		hue_value_label.text = "%d°" % int(current_hue)
		
		# Convert hue to color
		current_bg_color = Color.from_hsv(current_hue / 360.0, 0.3, 0.3, 0.9)
		
		# Apply to theme
		if theme_panel_style:
			theme_panel_style.bg_color = current_bg_color

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
	else:  # Visual tab
		if hue_slider:
			hue_slider.grab_focus()

func _switch_tab(direction: int):
	"""Switch between tabs (Audio/Visual)"""
	var current_tab = tab_container.current_tab
	var new_tab = (current_tab + direction) % tab_container.get_tab_count()
	if new_tab < 0:
		new_tab = tab_container.get_tab_count() - 1
	
	tab_container.current_tab = new_tab

func _setup_focus_navigation():
	"""Set up focus navigation for controls"""
	# Enable focus for sliders and button
	sfx_slider.focus_mode = Control.FOCUS_ALL
	music_slider.focus_mode = Control.FOCUS_ALL
	close_button.focus_mode = Control.FOCUS_ALL
	
	# Set up focus neighbors for Audio tab
	sfx_slider.focus_neighbor_bottom = sfx_slider.get_path_to(music_slider)
	sfx_slider.focus_neighbor_top = sfx_slider.get_path_to(close_button)
	sfx_slider.focus_next = sfx_slider.get_path_to(music_slider)
	
	music_slider.focus_neighbor_top = music_slider.get_path_to(sfx_slider)
	music_slider.focus_neighbor_bottom = music_slider.get_path_to(close_button)
	music_slider.focus_previous = music_slider.get_path_to(sfx_slider)
	music_slider.focus_next = music_slider.get_path_to(close_button)
	
	# Set up focus for Visual tab only if hue slider exists
	if hue_slider:
		hue_slider.focus_mode = Control.FOCUS_ALL
		hue_slider.focus_neighbor_bottom = hue_slider.get_path_to(close_button)
		hue_slider.focus_next = hue_slider.get_path_to(close_button)
	
	# Close button navigation
	close_button.focus_neighbor_top = close_button.get_path_to(music_slider)
	close_button.focus_neighbor_bottom = close_button.get_path_to(sfx_slider)
	close_button.focus_previous = close_button.get_path_to(music_slider)
