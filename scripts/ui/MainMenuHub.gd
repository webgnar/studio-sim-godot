extends Control
class_name MainMenuHub

## Main menu hub - combines traditional menu with studio information
## Shows player money, mission stats, and navigation buttons

@onready var dialog = $Dialog
@onready var money_label = $Dialog/MarginContainer/HBoxContainer/LeftPanel/MoneyDisplay/MoneyLabel
@onready var completed_missions_label = $Dialog/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/CompletedMissionsLabel
@onready var total_earnings_label = $Dialog/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/TotalEarningsLabel
@onready var paintings_created_label = $Dialog/MarginContainer/HBoxContainer/LeftPanel/StatsContainer/PaintingsCreatedLabel
@onready var missions_button = $Dialog/MarginContainer/HBoxContainer/RightPanel/MissionsButton
@onready var shop_button = $Dialog/MarginContainer/HBoxContainer/RightPanel/ShopButton
@onready var quit_button = $Dialog/MarginContainer/HBoxContainer/RightPanel/QuitButton

func _ready():
	# Hide dialog initially
	dialog.visible = false

	# Register with UIManager
	if UIManager:
		UIManager.register_screen("main_menu", self)
		UIManager.money_changed.connect(_on_money_changed)

	# Connect to PaintingSpawner
	if PaintingSpawner:
		PaintingSpawner.painting_created.connect(_on_painting_created)

	# Connect button signals
	missions_button.pressed.connect(_on_missions_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Update quit button text
	quit_button.text = tr("Quit (Main Menu)")

	# Load theme
	theme = load("res://themes/ui_theme.tres")

	# Set up controller navigation
	_setup_focus_navigation()

	# Update displays
	_update_money_display()
	_update_stats_display()

func _input(event):
	# Only handle input when this menu is visible
	if not dialog.visible:
		return

	var viewport = get_viewport()
	if not viewport:
		return

	# Handle menu navigation with move_forward/move_back
	if event.is_action_pressed("move_forward"):
		_navigate_menu(-1)  # Move up
		viewport.set_input_as_handled()
	elif event.is_action_pressed("move_back"):
		_navigate_menu(1)  # Move down
		viewport.set_input_as_handled()
	elif event.is_action_pressed("jump"):
		# Confirm button selection with jump (A button)
		var focused = viewport.gui_get_focus_owner()
		if focused is Button and not focused.disabled:
			focused.pressed.emit()
			viewport.set_input_as_handled()

func _navigate_menu(direction: int):
	"""Navigate menu up (-1) or down (1)"""
	var viewport = get_viewport()
	if not viewport:
		return

	var focused = viewport.gui_get_focus_owner()

	# Create button list (only enabled buttons)
	var buttons = []
	if not missions_button.disabled:
		buttons.append(missions_button)
	if not shop_button.disabled:
		buttons.append(shop_button)
	if not quit_button.disabled:
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

func _setup_focus_navigation():
	"""Set up gamepad/keyboard focus navigation for menu buttons"""
	# Enable focus mode for all buttons
	missions_button.focus_mode = Control.FOCUS_ALL
	shop_button.focus_mode = Control.FOCUS_ALL
	quit_button.focus_mode = Control.FOCUS_ALL

	# Don't set up focus neighbors - we handle navigation manually
	# This prevents unwanted keyboard navigation behavior

func show_screen():
	"""Show the main menu hub"""
	dialog.visible = true
	_update_money_display()
	_update_stats_display()
	missions_button.grab_focus()

func hide_screen():
	"""Hide the main menu hub"""
	dialog.visible = false

func _on_money_changed(new_amount: int):
	"""Update money display when currency changes"""
	_update_money_display()

func _on_painting_created(count: int):
	"""Update stats display when a painting is created"""
	_update_stats_display()

func _update_money_display():
	"""Update the money counter"""
	if UIManager and money_label:
		money_label.text = tr("$%d") % UIManager.player_money

func _update_stats_display():
	"""Update mission completion statistics"""
	if UIManager and completed_missions_label and total_earnings_label:
		completed_missions_label.text = tr("Missions Completed: %d") % UIManager.missions_completed
		total_earnings_label.text = tr("Total Earnings: $%d") % UIManager.lifetime_earnings

	if PaintingSpawner and paintings_created_label:
		paintings_created_label.text = tr("Paintings Created: %d") % PaintingSpawner.paintings_created

func _on_missions_pressed():
	"""Open mission selection screen"""
	if UIManager:
		UIManager.change_state(UIManager.GameState.PAUSE_MENU)

func _on_shop_pressed():
	"""Open shop screen"""
	if UIManager:
		UIManager.change_state(UIManager.GameState.SHOP)

func _on_quit_pressed():
	"""Return to title screen"""
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
