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

	# Load theme
	theme = load("res://themes/ui_theme.tres")

	# Update displays
	_update_money_display()
	_update_stats_display()

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
		money_label.text = "$%d" % UIManager.player_money

func _update_stats_display():
	"""Update mission completion statistics"""
	if UIManager and completed_missions_label and total_earnings_label:
		completed_missions_label.text = "Missions Completed: %d" % UIManager.missions_completed
		total_earnings_label.text = "Total Earnings: $%d" % UIManager.lifetime_earnings

	if PaintingSpawner and paintings_created_label:
		paintings_created_label.text = "Paintings Created: %d" % PaintingSpawner.paintings_created

func _on_missions_pressed():
	"""Open mission selection screen"""
	if UIManager:
		UIManager.change_state(UIManager.GameState.MISSION_SELECT)

func _on_shop_pressed():
	"""Open shop screen"""
	if UIManager:
		UIManager.change_state(UIManager.GameState.SHOP)

func _on_quit_pressed():
	"""Quit the game"""
	get_tree().quit()
