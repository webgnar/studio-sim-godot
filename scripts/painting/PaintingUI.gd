extends Control
class_name PaintingUI

## Scrolling carousel UI for painting stickers
## Selected sticker always stays centered, column scrolls up/down
## Supports both 3D and 2D painting systems

@export var painting_system_3d: PaintingSystem
@export var painting_system_2d: PaintingSystem2D

# Active system reference (changes based on mode)
var active_system = null

# UI References
@onready var slots_container: VBoxContainer = $MarginContainer/ClipContainer/SlotsContainer

# Carousel settings
@export var slot_size: Vector2 = Vector2(80, 80)  # Size of each slot
@export var slot_spacing: float = 10.0  # Gap between slots
@export var center_scale: float = 1.2  # Scale multiplier for center item
@export var side_scale: float = 0.8  # Scale multiplier for side items
@export var scroll_speed: float = 0.15  # Animation speed (lower = smoother)

# State
var slot_nodes: Array[PanelContainer] = []  # All slot UI elements
var current_scroll_offset: float = 0.0  # Current scroll position
var target_scroll_offset: float = 0.0  # Target scroll position (for smooth animation)

# Visual style
var default_border_color = Color("#555555")
var equipped_border_color = Color("#3399FF")
var default_bg_color = Color("#333333", 0.7)

func _ready():
	# Connect to mode manager to handle system switching
	if PaintingModeManager:
		PaintingModeManager.mode_changed.connect(_on_mode_changed)

	# Set initial active system based on current mode
	_set_active_system(PaintingModeManager.current_mode)

	# Build the UI once the painting system is ready
	call_deferred("_build_carousel")

func _set_active_system(mode):
	"""Switch to the appropriate painting system based on mode"""
	# Disconnect from old system if connected
	if active_system and active_system.layer_equipped.is_connected(_on_layer_equipped):
		active_system.layer_equipped.disconnect(_on_layer_equipped)

	# Set new active system
	if mode == PaintingModeManager.Mode.MODE_3D:
		active_system = painting_system_3d
	else:
		active_system = painting_system_2d

	# Connect to new system
	if active_system:
		active_system.layer_equipped.connect(_on_layer_equipped)
	else:
		push_error("PaintingUI: Active system is null for mode %d" % mode)

func _on_mode_changed(new_mode):
	"""Called when painting mode switches between 3D and 2D"""
	_set_active_system(new_mode)
	# Rebuild carousel for the new system
	_build_carousel()

func _build_carousel():
	"""Create all the slot UI elements dynamically"""
	if not active_system or active_system.sticker_library.is_empty():
		push_error("PaintingUI: Cannot build carousel - no stickers loaded")
		return

	# Clear any existing slots
	for child in slots_container.get_children():
		child.queue_free()
	slot_nodes.clear()

	# Create a slot for each sticker in the library
	for i in range(active_system.sticker_library.size()):
		var sticker = active_system.sticker_library[i]

		# Create PanelContainer for this slot
		var panel = PanelContainer.new()
		panel.custom_minimum_size = slot_size

		# Set pivot offset to center so scaling happens from center point
		panel.pivot_offset = slot_size / 2.0

		# Create style
		var style = StyleBoxFlat.new()
		style.bg_color = default_bg_color
		style.border_color = default_border_color
		style.set_border_width_all(2)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", style)

		# Create TextureRect for the sticker image
		var tex_rect = TextureRect.new()
		tex_rect.texture = sticker.texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = slot_size * 0.9  # Slightly smaller for border visibility

		panel.add_child(tex_rect)
		slots_container.add_child(panel)
		slot_nodes.append(panel)

	# Set initial scroll position to center the first item
	_update_carousel_position(true)

	print("PaintingUI: Built carousel with %d slots" % slot_nodes.size())

func _process(delta):
	# Smoothly animate scroll position
	if abs(target_scroll_offset - current_scroll_offset) > 0.1:
		current_scroll_offset = lerp(current_scroll_offset, target_scroll_offset, scroll_speed)
		_apply_scroll_position()
		_update_slot_visuals()
	else:
		current_scroll_offset = target_scroll_offset

func _on_layer_equipped(index: int):
	"""Called when Q/E or mouse wheel changes the equipped sticker"""
	_update_carousel_position(false)

func _update_carousel_position(instant: bool):
	"""Update scroll position to center the currently equipped sticker"""
	if not active_system or slot_nodes.is_empty():
		return

	var equipped_index = active_system.selected_sticker_index

	# Calculate target position to center the equipped item
	# The center of the ClipContainer should show the equipped item
	var clip_height = $MarginContainer/ClipContainer.size.y
	var center_y = clip_height / 2.0

	# Each slot takes up (slot_size.y + spacing)
	var slot_height = slot_size.y + slot_spacing
	var equipped_position = equipped_index * slot_height + (slot_size.y / 2.0)

	# Offset needed to center this item
	target_scroll_offset = equipped_position - center_y

	if instant:
		current_scroll_offset = target_scroll_offset
		_apply_scroll_position()
		_update_slot_visuals()

func _apply_scroll_position():
	"""Move the SlotsContainer vertically to create scrolling effect"""
	slots_container.position.y = -current_scroll_offset

func _update_slot_visuals():
	"""Update visual appearance of slots based on distance from center"""
	if not active_system or slot_nodes.is_empty():
		return

	var equipped_index = active_system.selected_sticker_index
	var clip_height = $MarginContainer/ClipContainer.size.y
	var center_y = clip_height / 2.0

	for i in range(slot_nodes.size()):
		var slot = slot_nodes[i]
		var is_equipped = (i == equipped_index)

		# Calculate distance from center
		var slot_height = slot_size.y + slot_spacing
		var slot_center_y = (i * slot_height + slot_size.y / 2.0) - current_scroll_offset
		var distance_from_center = abs(slot_center_y - center_y)

		# Update style based on equipped state
		var style = StyleBoxFlat.new()
		style.bg_color = default_bg_color
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4

		if is_equipped:
			# Equipped item - bright blue, thicker border
			style.border_color = equipped_border_color
			style.set_border_width_all(4)
			slot.scale = Vector2.ONE * center_scale
			slot.modulate = Color.WHITE  # Full brightness
		else:
			# Not equipped - gray border, smaller
			style.border_color = default_border_color
			style.set_border_width_all(2)
			slot.scale = Vector2.ONE * side_scale

			# Fade out items further from center
			var fade = clamp(1.0 - (distance_from_center / 200.0), 0.3, 1.0)
			slot.modulate = Color(1, 1, 1, fade)

		slot.add_theme_stylebox_override("panel", style)
