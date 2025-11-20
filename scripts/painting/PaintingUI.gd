extends Control
class_name PaintingUI

## Minimal painting UI - shows 5 sticker slots with visual highlight on equipped layer
## Controlled entirely by Q/E keys (no mouse interaction)

@export var painting_system: PaintingSystem

# References to the 5 layer slots (assign from scene tree)
@onready var layer_slots: Array[PanelContainer] = [
	$MarginContainer/VBoxContainer/LayerSlot1,
	$MarginContainer/VBoxContainer/LayerSlot2,
	$MarginContainer/VBoxContainer/LayerSlot3,
	$MarginContainer/VBoxContainer/LayerSlot4,
	$MarginContainer/VBoxContainer/LayerSlot5
]

# Visual style settings
var default_border_color = Color("#555555")  # Gray border for unselected
var equipped_border_color = Color("#3399FF")  # Blue border for equipped
var default_border_width = 2
var equipped_border_width = 4

func _ready():
	# Set up initial styles for all slots
	_setup_slot_styles()

	# Connect to painting system signals
	if painting_system:
		painting_system.layer_equipped.connect(_on_layer_equipped)

	# Update highlight to show initial selection
	_update_highlight()

func _setup_slot_styles():
	"""Initialize the visual style for all 5 layer slots"""
	for i in range(layer_slots.size()):
		var slot = layer_slots[i]
		if slot:
			# Create default style
			var style = StyleBoxFlat.new()
			style.bg_color = Color("#333333", 0.7)  # Semi-transparent dark gray
			style.border_color = default_border_color
			style.set_border_width_all(default_border_width)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4

			# Apply style
			slot.add_theme_stylebox_override("panel", style)

func _update_highlight():
	"""Update visual highlight to show which layer is currently equipped"""
	if not painting_system:
		return

	var equipped_index = painting_system.selected_sticker_index

	# Update all 5 slots
	for i in range(layer_slots.size()):
		var slot = layer_slots[i]
		if not slot:
			continue

		# Create new style for this slot
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#333333", 0.7)  # Same background for all
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4

		# Apply equipped style or default style
		if i == equipped_index:
			# This is the equipped layer - bright blue border
			style.border_color = equipped_border_color
			style.set_border_width_all(equipped_border_width)
		else:
			# Not equipped - subtle gray border
			style.border_color = default_border_color
			style.set_border_width_all(default_border_width)

		slot.add_theme_stylebox_override("panel", style)

func _on_layer_equipped(index: int):
	"""Called when the equipped layer changes (via Q/E keys)"""
	_update_highlight()
