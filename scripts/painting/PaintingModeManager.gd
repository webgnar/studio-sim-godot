extends Node

## Global manager for painting system modes
## Handles toggling between 3D (Sprite3D) and 2D (SubViewport) painting systems

enum Mode { MODE_3D, MODE_2D }

signal mode_changed(new_mode: Mode)

var current_mode: Mode = Mode.MODE_3D

# References to painting systems (set by world scene)
var painting_system_3d: PaintingSystem = null
var painting_system_2d: PaintingSystem2D = null
var painting_root_3d: Node3D = null
var painting_root_2d: Node3D = null

func _ready():
	print("PaintingModeManager ready. Starting in 3D mode.")

func _input(event):
	# Toggle between modes with Tab key
	if event.is_action_pressed("toggle_painting_mode"):
		toggle_mode()
		get_viewport().set_input_as_handled()

func toggle_mode():
	"""Switch between 3D and 2D painting modes"""
	if current_mode == Mode.MODE_3D:
		current_mode = Mode.MODE_2D
		print("Switched to 2D painting mode")
	else:
		current_mode = Mode.MODE_3D
		print("Switched to 3D painting mode")

	# Update systems
	_update_systems()

	# Emit signal
	mode_changed.emit(current_mode)

func _update_systems():
	"""Update input and visibility for both painting systems"""
	var is_3d = (current_mode == Mode.MODE_3D)

	# Enable/disable input
	if painting_system_3d:
		painting_system_3d.set_input_enabled(is_3d)

	if painting_system_2d:
		painting_system_2d.set_input_enabled(not is_3d)

	# Show/hide painting roots
	if painting_root_3d:
		painting_root_3d.visible = is_3d

	if painting_root_2d:
		painting_root_2d.visible = not is_3d

func register_3d_system(system: PaintingSystem, root: Node3D):
	"""Register the 3D painting system"""
	painting_system_3d = system
	painting_root_3d = root
	print("Registered 3D painting system")
	_update_systems()

func register_2d_system(system: PaintingSystem2D, root: Node3D):
	"""Register the 2D painting system"""
	painting_system_2d = system
	painting_root_2d = root
	print("Registered 2D painting system")
	_update_systems()

func sync_sticker_selection(index: int):
	"""Sync sticker selection across both systems"""
	if painting_system_3d:
		painting_system_3d.selected_sticker_index = index

	if painting_system_2d:
		painting_system_2d.selected_sticker_index = index
