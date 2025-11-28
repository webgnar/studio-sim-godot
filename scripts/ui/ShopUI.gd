extends Control
class_name ShopUI

## Shop UI - Placeholder for future shop system
## Will eventually allow purchasing stickers, canvases, and studio upgrades

@onready var dialog = $Dialog
@onready var back_button = $Dialog/MarginContainer/VBoxContainer/BackButton

func _ready():
	# Hide dialog initially
	dialog.visible = false

	# Register with UIManager
	if UIManager:
		UIManager.register_screen("shop", self)

	# Connect button signals
	back_button.pressed.connect(_on_back_pressed)

	# Load theme
	theme = load("res://resources/ui_theme.tres")

func show_screen():
	"""Show the shop screen"""
	dialog.visible = true
	back_button.grab_focus()

func hide_screen():
	"""Hide the shop screen"""
	dialog.visible = false

func _on_back_pressed():
	"""Return to main menu"""
	if UIManager:
		UIManager.change_state(UIManager.GameState.MAIN_MENU)
