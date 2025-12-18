extends Control
class_name PaintingUI

## Scrolling carousel UI for painting stickers
## Selected sticker always stays centered, column scrolls up/down
## Supports both 3D and 2D painting systems

# Preload the sticker slot scene
const StickerSlotScene = preload("res://scenes/UI/StickerSlot.tscn")

@export var painting_system_3d: PaintingSystem
@export var painting_system_2d: PaintingSystem2D

# Active system reference (changes based on mode)
var active_system = null

# UI References
@onready var slots_container: VBoxContainer = $MarginContainer/ClipContainer/SlotsContainer

# Carousel settings
@export var slot_size: Vector2 = Vector2(120, 120)  # Size of each slot
@export var slot_spacing: float = 10.0  # Gap between slots
@export var center_scale: float = 1.2  # Scale multiplier for center item
@export var side_scale: float = 0.8  # Scale multiplier for side items
@export var scroll_speed: float = 0.15  # Animation speed (lower = smoother)

# State
var slot_nodes: Array[StickerSlot] = []  # All slot UI elements
var current_scroll_offset: float = 0.0  # Current scroll position
var target_scroll_offset: float = 0.0  # Target scroll position (for smooth animation)

func _ready():
	# Use 2D system as primary reference (missions use 2D, sticker library identical)
	active_system = painting_system_2d if painting_system_2d else painting_system_3d

	# Connect to active system only (PaintingModeManager handles syncing)
	if active_system:
		active_system.layer_equipped.connect(_on_layer_equipped)

	# Build the UI once the painting system is ready
	call_deferred("_build_carousel")


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

		# Instantiate slot from scene
		var slot = StickerSlotScene.instantiate() as StickerSlot
		slot.custom_minimum_size = slot_size
		slot.setup(sticker.texture, i)

		slots_container.add_child(slot)
		slot_nodes.append(slot)

	# Wait for slot _ready() functions to complete and UI layout to be finalized
	await get_tree().process_frame

	# Manually initialize the correct slot as equipped (based on active_system's current selection)
	if not slot_nodes.is_empty() and active_system:
		var equipped_index = active_system.selected_sticker_index
		if equipped_index < slot_nodes.size():
			slot_nodes[equipped_index].set_equipped(true)
			slot_nodes[equipped_index].set_slot_scale(center_scale)

	# Wait one more frame for layout
	await get_tree().process_frame

	# Set initial scroll position and visuals
	_update_carousel_position(true)

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

		# Update equipped state
		slot.set_equipped(is_equipped)

		# Update scale
		if is_equipped:
			slot.set_slot_scale(center_scale)
		else:
			slot.set_slot_scale(side_scale)

		# Update fade based on distance from center
		var fade = clamp(1.0 - (distance_from_center / 200.0), 0.3, 1.0)
		slot.set_fade(fade)
