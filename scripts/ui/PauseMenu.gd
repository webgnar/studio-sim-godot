extends Control
class_name PauseMenuUI

## Pause menu with horizontal tabs: Commissions, Inventory, Options
## Handles top-level tab switching and delegates input to active tab content

enum Tab { INVENTORY, COMMISSIONS, SHOP, OPTIONS }
enum NavMode { TAB_BAR, TAB_CONTENT }

@onready var dialog: PanelContainer = $Dialog
@onready var tab_bar: HBoxContainer = $Dialog/MarginContainer/VBoxContainer/TabBar
@onready var tab_content: Control = $Dialog/MarginContainer/VBoxContainer/TabContent

# Tab buttons
@onready var commissions_tab_button: Button = $Dialog/MarginContainer/VBoxContainer/TabBar/CommissionsTab
@onready var inventory_tab_button: Button = $Dialog/MarginContainer/VBoxContainer/TabBar/InventoryTab
@onready var options_tab_button: Button = $Dialog/MarginContainer/VBoxContainer/TabBar/OptionsTab
@onready var shop_tab_button: Button = $Dialog/MarginContainer/VBoxContainer/TabBar/ShopTabButton

# Tab content containers
@onready var commissions_content: Control = $Dialog/MarginContainer/VBoxContainer/TabContent/CommissionsContent
@onready var inventory_content: Control = $Dialog/MarginContainer/VBoxContainer/TabContent/InventoryContent
@onready var options_content: Control = $Dialog/MarginContainer/VBoxContainer/TabContent/OptionsContent
@onready var shop_content: Control = $Dialog/MarginContainer/VBoxContainer/TabContent/ShopContent

# Return to title button (in Options tab)
@onready var return_to_title_button: Button = $Dialog/MarginContainer/VBoxContainer/TabContent/OptionsContent/ReturnToTitleButton

# Sound effects
@onready var open_menu_sound: AudioStreamPlayer = $OpenMenuSound
@onready var close_menu_sound: AudioStreamPlayer = $CloseMenuSound
@onready var button_nav_sound: AudioStreamPlayer = $ButtonNavSound
@onready var button_hit_sound: AudioStreamPlayer = $ButtonHitSound

# Embedded child references (set after _ready finds them)
var mission_selection_ui: MissionSelectionUI = null
var inventory_tab: Control = null
var options_menu: Control = null
var shop_tab: ShopTab = null

# Key icon (placed in TabBar in scene)
@onready var key_icon: TextureRect = $Dialog/MarginContainer/VBoxContainer/TabBar/KeyIcon

# Money display (placed in TabBar in scene)
@onready var money_label: Label = $Dialog/MarginContainer/VBoxContainer/TabBar/MoneyLabel

# State
var current_tab: Tab = Tab.COMMISSIONS
var nav_mode: NavMode = NavMode.TAB_BAR
var tab_buttons: Array[Button] = []
var input_cooldown: float = 0.0
var input_cooldown_time: float = 0.15
var _tab_nav_held: bool = false  # Prevent rapid tab cycling from held analog stick

func _ready():
	# Keep processing while game tree is paused (menu must stay interactive)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Hide dialog initially
	dialog.visible = false

	# Build tab buttons array
	tab_buttons = [inventory_tab_button, commissions_tab_button, shop_tab_button, options_tab_button]

	# Disable Godot focus on tab buttons (navigation is script-driven via modulate)
	for button in tab_buttons:
		button.focus_mode = Control.FOCUS_NONE

	# Connect tab button signals (guard against re-clicking the active tab)
	commissions_tab_button.pressed.connect(func(): if current_tab != Tab.COMMISSIONS: _switch_tab(Tab.COMMISSIONS))
	inventory_tab_button.pressed.connect(func(): if current_tab != Tab.INVENTORY: _switch_tab(Tab.INVENTORY))
	options_tab_button.pressed.connect(func(): if current_tab != Tab.OPTIONS: _switch_tab(Tab.OPTIONS))
	shop_tab_button.pressed.connect(func(): if current_tab != Tab.SHOP: _switch_tab(Tab.SHOP))

	# Find embedded child UIs
	mission_selection_ui = _find_child_of_type(commissions_content, "MissionSelectionUI") as MissionSelectionUI
	inventory_tab = _find_child_by_class_name(inventory_content, "InventoryTab")
	options_menu = _find_child_by_script_name(options_content, "OptionsMenu")
	shop_tab = _find_child_by_class_name(shop_content, "ShopTab") as ShopTab

	# Connect return to title button
	return_to_title_button.pressed.connect(_on_return_to_title_pressed)

	# Hide key icon initially
	if key_icon:
		key_icon.visible = false

	# Connect money display
	if EconomyManager:
		EconomyManager.money_changed.connect(_on_money_changed)
		_update_money_display()

	# Register with UIManager
	if UIManager:
		UIManager.register_screen("pause_menu", self)

func _process(delta):
	if not dialog.visible:
		return

	if input_cooldown > 0:
		input_cooldown -= delta

	# Reset tab nav held when stick returns to center
	if _tab_nav_held:
		if not Input.is_action_pressed("ui_left") and not Input.is_action_pressed("move_left") \
			and not Input.is_action_pressed("ui_right") and not Input.is_action_pressed("move_right"):
			_tab_nav_held = false

func _input(event):
	if not dialog.visible:
		return

	var viewport = get_viewport()
	if not viewport:
		return

	# Auto-enter TAB_CONTENT mode when mouse clicks in the content area
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if nav_mode == NavMode.TAB_BAR and tab_content.get_global_rect().has_point(event.position):
			_enter_tab_content_mode(true)
			# Don't consume — let the click propagate to child controls
			return

	# Check if a text field is being edited (don't intercept input)
	if _is_text_editing():
		# Exit on Escape or gamepad B button (not keyboard B, which should type 'B')
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_release_text_focus()
			viewport.set_input_as_handled()
		elif event is InputEventJoypadButton and event.is_action_pressed("go_back"):
			_release_text_focus()
			viewport.set_input_as_handled()
		return

	# LB/RB for instant tab switching from any mode (not mouse scroll wheel)
	if event.is_action_pressed("cycle_prev"):
		if event is InputEventMouseButton:
			return  # Let scroll wheel propagate to scroll containers
		if input_cooldown <= 0:
			_cycle_tab(-1)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("cycle_next"):
		if event is InputEventMouseButton:
			return  # Let scroll wheel propagate to scroll containers
		if input_cooldown <= 0:
			_cycle_tab(1)
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	# Start button always closes the menu
	if event.is_action_pressed("start"):
		_close_menu()
		viewport.set_input_as_handled()
		return

	if nav_mode == NavMode.TAB_BAR:
		_handle_tab_bar_input(event, viewport)
	# TAB_CONTENT mode: let child content scripts handle input via their own _input()
	# The children will consume events they handle via set_input_as_handled()
	# If go_back is not consumed by children, we catch it here
	elif nav_mode == NavMode.TAB_CONTENT:
		# Check if ReturnToTitleButton is focused (Options tab bottom)
		var focused = viewport.gui_get_focus_owner()
		if focused == return_to_title_button:
			if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
				return_to_title_button.release_focus()
				# Re-enter options content at bottom
				if options_menu:
					options_menu.keyboard_nav_enabled = true
					options_menu.is_in_tab_mode = false
					options_menu._focus_last_content_item()
				viewport.set_input_as_handled()
			elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
				_on_return_to_title_pressed()
				viewport.set_input_as_handled()
			elif event.is_action_pressed("go_back"):
				return_to_title_button.release_focus()
				_enter_tab_bar_mode()
				viewport.set_input_as_handled()
			return

		# Child didn't consume these events — we're at a boundary
		if event.is_action_pressed("go_back"):
			_enter_tab_bar_mode()
			viewport.set_input_as_handled()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
			_enter_tab_bar_mode()
			viewport.set_input_as_handled()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
			# At bottom boundary — focus ReturnToTitleButton on Options tab
			if current_tab == Tab.OPTIONS:
				# Disable options keyboard nav so it doesn't consume input while button is focused
				if options_menu:
					options_menu.keyboard_nav_enabled = false
				return_to_title_button.grab_focus()
				viewport.set_input_as_handled()

func _handle_tab_bar_input(event, viewport):
	"""Handle input when navigating the tab bar"""
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		if not _tab_nav_held:
			_cycle_tab(-1)
			_tab_nav_held = true
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		if not _tab_nav_held:
			_cycle_tab(1)
			_tab_nav_held = true
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if input_cooldown <= 0:
			_enter_tab_content_mode()
			input_cooldown = input_cooldown_time
		viewport.set_input_as_handled()
		return

	if event.is_action_pressed("go_back"):
		_close_menu()
		viewport.set_input_as_handled()
		return

func show_screen():
	"""Show the pause menu (called by UIManager)"""
	dialog.visible = true

	# Restore last tab; always show Commissions if a mission is active
	if MissionManager and MissionManager.current_mission:
		_switch_tab(Tab.COMMISSIONS)
	else:
		_switch_tab(current_tab)
	_enter_tab_bar_mode()

	# Reset input cooldown
	input_cooldown = 0.0
	_tab_nav_held = false

	# Update key icon visibility
	_update_key_icon()

	# Refresh money display
	_update_money_display()

	# Play open sound
	if open_menu_sound:
		open_menu_sound.play()

func hide_screen():
	"""Hide the pause menu (called by UIManager)"""
	dialog.visible = false
	_hide_all_tab_content()

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
	UIManager.hud = null

	# Reset CameraManager so its transition camera doesn't override the title screen camera
	CameraManager.player_camera = null
	CameraManager.current_camera = null
	CameraManager.active_zones.clear()
	if CameraManager.is_blending:
		CameraManager.is_blending = false
		CameraManager.set_process(false)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Unpause before scene transition (SceneTransition uses tweens/await)
	get_tree().paused = false

	SceneTransition.fade_to_scene("res://scenes/TitleScreen.tscn")

func open_to_painting(painting_node: CarryablePainting) -> void:
	"""Open the pause menu directly to the inventory tab with a specific painting selected"""
	# Enter pause state
	if UIManager:
		UIManager.change_state(UIManager.GameState.PAUSE_MENU)

	dialog.visible = true
	input_cooldown = 0.0
	_tab_nav_held = false
	_update_key_icon()

	# Switch to inventory tab
	_switch_tab(Tab.INVENTORY)

	# Select the specific painting
	if inventory_tab and inventory_tab.has_method("select_painting_by_node"):
		inventory_tab.select_painting_by_node(painting_node)

	# Enter content mode so user can immediately edit
	_enter_tab_content_mode()

	if open_menu_sound:
		open_menu_sound.play()

func show_mission_results(result: ValidationResult, mission: PaintingMission) -> void:
	"""Show live results in the Commissions tab after a painting is submitted"""
	_switch_tab(Tab.COMMISSIONS)
	_enter_tab_content_mode()
	if mission_selection_ui:
		mission_selection_ui.show_live_results_for_mission(result, mission)

func _close_menu():
	"""Close the pause menu and return to gameplay"""
	if close_menu_sound:
		close_menu_sound.play()

	nav_mode = NavMode.TAB_BAR

	if UIManager:
		if MissionManager and MissionManager.current_mission:
			UIManager.change_state(UIManager.GameState.IN_MISSION)
		else:
			UIManager.change_state(UIManager.GameState.GAMEPLAY)

func _switch_tab(tab: Tab):
	"""Switch to a specific tab"""
	current_tab = tab
	_hide_all_tab_content()
	_show_tab_content(tab)
	_update_tab_button_styles()

	# Play nav sound
	if button_nav_sound:
		button_nav_sound.play()

func _cycle_tab(direction: int):
	"""Cycle through tabs with clamping (no wrap)"""
	var new_tab = clampi(current_tab + direction, 0, Tab.OPTIONS)
	if new_tab != current_tab:
		# If we were in content mode, enter tab bar first
		if nav_mode == NavMode.TAB_CONTENT:
			_enter_tab_bar_mode()
		_switch_tab(new_tab as Tab)

func _enter_tab_bar_mode():
	"""Enter tab bar navigation mode"""
	nav_mode = NavMode.TAB_BAR
	_update_tab_bar_visual()

	# Deactivate current tab content so it stops processing input
	_deactivate_tab_content(current_tab)

func _enter_tab_content_mode(from_mouse: bool = false):
	"""Enter tab content navigation mode - enable keyboard nav on active tab"""
	nav_mode = NavMode.TAB_CONTENT
	_update_tab_bar_visual()

	# Enable keyboard navigation on the active tab's content
	match current_tab:
		Tab.COMMISSIONS:
			if mission_selection_ui:
				mission_selection_ui.keyboard_nav_enabled = true
				if not from_mouse:
					mission_selection_ui.nav_mode = MissionSelectionUI.NavMode.MISSION_LIST
					mission_selection_ui._clear_button_focus()
					mission_selection_ui.input_cooldown = 0.0
		Tab.INVENTORY:
			if inventory_tab:
				inventory_tab.keyboard_nav_enabled = true
				if not from_mouse:
					inventory_tab.nav_mode = InventoryTab.NavMode.PAINTING_LIST
					inventory_tab.is_editing_text = false
					inventory_tab.input_cooldown = 0.0
		Tab.OPTIONS:
			if options_menu:
				options_menu.keyboard_nav_enabled = true
				if not from_mouse:
					options_menu.is_in_tab_mode = true
					options_menu._update_tab_mode_visual()
					options_menu.input_cooldown = 0.0
		Tab.SHOP:
			if shop_tab:
				shop_tab.keyboard_nav_enabled = true
				if not from_mouse:
					shop_tab.nav_mode = ShopTab.NavMode.ITEM_LIST
					shop_tab.input_cooldown = 0.0

	if not from_mouse and button_hit_sound:
		button_hit_sound.play()

func _deactivate_tab_content(tab: Tab):
	"""Deactivate keyboard navigation on a tab's content (keep visible and mouse-interactive)"""
	match tab:
		Tab.COMMISSIONS:
			if mission_selection_ui:
				mission_selection_ui.keyboard_nav_enabled = false
		Tab.INVENTORY:
			if inventory_tab:
				inventory_tab.keyboard_nav_enabled = false
		Tab.OPTIONS:
			if options_menu:
				options_menu.keyboard_nav_enabled = false
		Tab.SHOP:
			if shop_tab:
				shop_tab.keyboard_nav_enabled = false

func _hide_all_tab_content():
	"""Hide all tab content areas and disable input processing"""
	commissions_content.visible = false
	inventory_content.visible = false
	options_content.visible = false
	shop_content.visible = false

	# Disable input processing
	if mission_selection_ui:
		mission_selection_ui.process_mode = Node.PROCESS_MODE_DISABLED
	if inventory_tab:
		inventory_tab.process_mode = Node.PROCESS_MODE_DISABLED
	if options_menu:
		options_menu.hide()
		options_menu.process_mode = Node.PROCESS_MODE_DISABLED
	if shop_tab:
		shop_tab.process_mode = Node.PROCESS_MODE_DISABLED

func _show_tab_content(tab: Tab):
	"""Show the content area for a specific tab (mouse-interactive immediately, keyboard nav controlled by flag)"""
	match tab:
		Tab.COMMISSIONS:
			commissions_content.visible = true
			if mission_selection_ui:
				mission_selection_ui.activate()
				# Enable process_mode so mouse works, but disable keyboard nav
				mission_selection_ui.process_mode = Node.PROCESS_MODE_INHERIT
				mission_selection_ui.keyboard_nav_enabled = false
		Tab.INVENTORY:
			inventory_content.visible = true
			if inventory_tab and inventory_tab.has_method("activate"):
				inventory_tab.activate()
				# Enable process_mode so mouse works, but disable keyboard nav
				inventory_tab.process_mode = Node.PROCESS_MODE_INHERIT
				inventory_tab.keyboard_nav_enabled = false
		Tab.OPTIONS:
			options_content.visible = true
			if options_menu and options_menu.has_method("show_menu"):
				options_menu.show_menu()
				# Enable process_mode so mouse works, but disable keyboard nav
				options_menu.process_mode = Node.PROCESS_MODE_INHERIT
				options_menu.keyboard_nav_enabled = false
		Tab.SHOP:
			shop_content.visible = true
			if shop_tab:
				shop_tab.activate()
				shop_tab.process_mode = Node.PROCESS_MODE_INHERIT
				shop_tab.keyboard_nav_enabled = false

func _update_tab_button_styles():
	"""Update tab button visual states"""
	for i in range(tab_buttons.size()):
		var button = tab_buttons[i]
		if i == current_tab:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			button.modulate = Color(0.6, 0.6, 0.6, 1.0)

func _update_tab_bar_visual():
	"""Update tab bar highlight for tab mode"""
	if nav_mode == NavMode.TAB_BAR:
		tab_bar.modulate = Color(0.7, 1.0, 1.0, 1.0)  # Cyan tint
	else:
		tab_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal

func _is_text_editing() -> bool:
	"""Check if a LineEdit or TextEdit currently has keyboard focus"""
	var focused = get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

func _release_text_focus():
	"""Release keyboard focus from text fields"""
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()

func _update_key_icon():
	if key_icon:
		key_icon.visible = WorldStateManager.has_flag("studio_key")

func _update_money_display():
	if money_label and EconomyManager:
		money_label.text = "$%d" % EconomyManager.get_money()

func _on_money_changed(new_amount: int):
	if money_label:
		money_label.text = "$%d" % new_amount

# ============================================================================
# Child finding helpers
# ============================================================================

func _find_child_of_type(parent: Node, type_name: String) -> Node:
	"""Find first child node that matches a class name"""
	for child in parent.get_children():
		if child.get_class() == type_name or (child.get_script() and child.get_script().get_global_name() == type_name):
			return child
		var result = _find_child_of_type(child, type_name)
		if result:
			return result
	return null

func _find_child_by_class_name(parent: Node, class_name_str: String) -> Node:
	"""Find first child whose script has a matching global name"""
	for child in parent.get_children():
		if child.get_script() and child.get_script().get_global_name() == class_name_str:
			return child
		var result = _find_child_by_class_name(child, class_name_str)
		if result:
			return result
	return null

func _find_child_by_script_name(parent: Node, script_name: String) -> Node:
	"""Find first child whose script resource path contains the script name"""
	for child in parent.get_children():
		if child.get_script():
			var path = child.get_script().resource_path
			if path.get_file().get_basename() == script_name:
				return child
		var result = _find_child_by_script_name(child, script_name)
		if result:
			return result
	return null
