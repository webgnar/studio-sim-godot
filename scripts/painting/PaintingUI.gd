extends Control
class_name PaintingUI

## Simple UI for painting system
## Shows current sticker, placed layers, and controls

@export var painting_system: PaintingSystem

# UI References - assigned from scene tree
@onready var sticker_label: Label = $Panel/MarginContainer/VBoxContainer/CurrentStickerLabel
@onready var layers_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/LayersList
@onready var delete_btn: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/DeleteButton
@onready var clear_btn: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ClearButton

var last_key_time: float = 0.0

func _ready():
	# Connect buttons
	if delete_btn:
		delete_btn.pressed.connect(_on_delete_pressed)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_pressed)

func _process(_delta):
	if not painting_system:
		return

	# Update current sticker label
	if painting_system.sticker_library.size() > 0:
		var idx = painting_system.selected_sticker_index
		var sticker = painting_system.sticker_library[idx]
		sticker_label.text = "Current Sticker: %s (%d/%d)" % [
			sticker.id,
			idx + 1,
			painting_system.sticker_library.size()
		]

	# Update placed layers list
	_update_layers_list()

	# Handle number keys for selection (with debounce)
	var current_time = Time.get_ticks_msec() / 1000.0
	if (current_time - last_key_time) > 0.2:
		for i in range(min(9, painting_system.placed_layers.size())):
			if Input.is_physical_key_pressed(KEY_1 + i):
				painting_system.select_layer_by_index(i)
				last_key_time = current_time
				break

func _update_layers_list():
	if not layers_list:
		return

	# Clear existing buttons
	for child in layers_list.get_children():
		child.queue_free()

	# Add button for each placed layer
	for i in range(painting_system.placed_layers.size()):
		var layer = painting_system.placed_layers[i]

		var btn = Button.new()
		btn.text = "%d. %s (Order: %d)" % [i + 1, layer.id, layer.order]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 30)

		# Highlight if selected
		if painting_system.selected_layer == layer:
			btn.modulate = Color(1.0, 1.0, 0.6)  # Yellow tint

		# Connect button press
		var layer_index = i
		btn.pressed.connect(func(): painting_system.select_layer_by_index(layer_index))

		layers_list.add_child(btn)

func _on_delete_pressed():
	if painting_system:
		painting_system.delete_selected_layer()

func _on_clear_pressed():
	if painting_system:
		painting_system.clear_canvas()
