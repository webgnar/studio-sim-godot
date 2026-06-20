extends Control
class_name PaintingUI

## Scrolling carousel UI for painting stickers
## Selected sticker always stays centered, column scrolls up/down
## Supports both 3D and 2D painting systems

# Preload the sticker slot scene
const StickerSlotScene = preload("res://scenes/UI/StickerSlot.tscn")

@export var painting_system_3d: PaintingSystem3D
@export var painting_system_2d: PaintingSystem2D
@export var sticker_slot_theme: Theme  # Theme for sticker slot styling

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

# Auto-hide animation settings
@export var auto_hide_delay: float = 3.0  # Seconds of inactivity before hiding
@export var animation_duration: float = 0.3  # Duration of show/hide animation
@export var hidden_scale: float = 0.7  # Scale when hidden

# State
var slot_nodes: Array[StickerSlot] = []  # All slot UI elements
var current_scroll_offset: float = 0.0  # Current scroll position
var target_scroll_offset: float = 0.0  # Target scroll position (for smooth animation)

# Auto-hide state
var ui_idle_time: float = 0.0  # Time since last activity
var is_ui_visible: bool = false  # Current visibility state
var visible_position_x: float = 0.0  # X position when visible
var hidden_position_x: float = 0.0  # X position when hidden (off-screen)
var animation_tween: Tween = null  # Active animation tween

func _ready():
	# Use 2D system as primary reference (missions use 2D, sticker library identical)
	active_system = (painting_system_2d as Node) if painting_system_2d else (painting_system_3d as Node)

	# Connect to active system only (PaintingModeManager handles syncing)
	if active_system:
		active_system.layer_equipped.connect(_on_layer_equipped)

	# Build the UI once the painting system is ready
	call_deferred("_build_carousel")

	# Rebuild whenever StickerLibrary reloads (e.g. custom modder purchased, new game)
	StickerLibrary.library_changed.connect(_build_carousel)
	
	# Initialize auto-hide positions
	visible_position_x = position.x
	hidden_position_x = -(size.x + 50)  # Fully off-screen to the left
	
	# Start hidden
	position.x = hidden_position_x
	scale = Vector2(hidden_scale, hidden_scale)
	is_ui_visible = false


func _build_carousel():
	"""Create all the slot UI elements dynamically"""
	if StickerLibrary.sticker_library.is_empty():
		push_error("PaintingUI: Cannot build carousel - no stickers loaded")
		return

	# Clear any existing slots
	for child in slots_container.get_children():
		child.queue_free()
	slot_nodes.clear()

	# Create a slot for each sticker in the library
	for i in range(StickerLibrary.sticker_library.size()):
		var sticker = StickerLibrary.sticker_library[i]

		# Instantiate slot from scene
		var slot = StickerSlotScene.instantiate() as StickerSlot
		slot.custom_minimum_size = slot_size

		# Assign theme to slot for variation support
		if sticker_slot_theme:
			slot.theme = sticker_slot_theme

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
	
	# Auto-hide tracking
	if is_ui_visible:
		ui_idle_time += delta
		if ui_idle_time > auto_hide_delay:
			_hide_ui()

func set_active_system(new_system) -> void:
	"""Switch the active painting system and reconnect signals"""
	if active_system and active_system.layer_equipped.is_connected(_on_layer_equipped):
		active_system.layer_equipped.disconnect(_on_layer_equipped)
	active_system = new_system
	if active_system:
		active_system.layer_equipped.connect(_on_layer_equipped)

func _on_layer_equipped(_index: int):
	"""Called when Q/E or mouse wheel changes the equipped sticker"""
	ui_idle_time = 0.0  # Reset idle timer
	_show_ui()  # Show UI when cycling stickers
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

func _show_ui():
	"""Animate UI into view from the left with scale"""
	if is_ui_visible:
		return  # Already visible
	
	is_ui_visible = true
	
	# Kill existing tween if any
	if animation_tween:
		animation_tween.kill()
	
	# Create new tween
	animation_tween = create_tween()
	animation_tween.set_parallel(true)  # Run position and scale animations simultaneously
	animation_tween.set_trans(Tween.TRANS_SINE)
	animation_tween.set_ease(Tween.EASE_OUT)
	
	# Animate position and scale
	animation_tween.tween_property(self, "position:x", visible_position_x, animation_duration)
	animation_tween.tween_property(self, "scale", Vector2.ONE, animation_duration)

func _hide_ui():
	"""Animate UI off-screen to the left with scale"""
	if not is_ui_visible:
		return  # Already hidden

	is_ui_visible = false

	# Kill existing tween if any
	if animation_tween:
		animation_tween.kill()

	# Create new tween
	animation_tween = create_tween()
	animation_tween.set_parallel(true)  # Run position and scale animations simultaneously
	animation_tween.set_trans(Tween.TRANS_SINE)
	animation_tween.set_ease(Tween.EASE_OUT)

	# Animate position and scale
	animation_tween.tween_property(self, "position:x", hidden_position_x, animation_duration)
	animation_tween.tween_property(self, "scale", Vector2(hidden_scale, hidden_scale), animation_duration)
