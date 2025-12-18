extends PanelContainer
class_name StickerSlot

## Reusable sticker slot component for painting UI carousel
## Displays a single sticker with equipped/unequipped visual states

var sticker_image: TextureRect

var slot_index: int = 0
var is_equipped: bool = false

# Theme variations (can be customized in inspector)
@export var default_theme_variation: String = "StickerSlotDefault"
@export var equipped_theme_variation: String = "StickerSlotEquipped"

# Fallback styling if no theme is assigned
@export_group("Fallback Styles")
@export var default_border_color: Color = Color("#555555")
@export var equipped_border_color: Color = Color("efc0cbff")
@export var default_bg_color: Color = Color("#333333", 0.7)
@export var border_width_default: int = 2
@export var border_width_equipped: int = 4
@export var corner_radius: int = 4

var default_style: StyleBoxFlat
var equipped_style: StyleBoxFlat
var use_theme_variations: bool = false

func _ready():
	# Get the sticker image child node
	sticker_image = get_node("StickerImage")

	# Always create fallback styles (in case theme isn't loaded yet)
	default_style = StyleBoxFlat.new()
	default_style.bg_color = default_bg_color
	default_style.border_color = default_border_color
	default_style.set_border_width_all(border_width_default)
	default_style.corner_radius_top_left = corner_radius
	default_style.corner_radius_top_right = corner_radius
	default_style.corner_radius_bottom_left = corner_radius
	default_style.corner_radius_bottom_right = corner_radius

	equipped_style = StyleBoxFlat.new()
	equipped_style.bg_color = default_bg_color
	equipped_style.border_color = equipped_border_color
	equipped_style.set_border_width_all(border_width_equipped)
	equipped_style.corner_radius_top_left = corner_radius
	equipped_style.corner_radius_top_right = corner_radius
	equipped_style.corner_radius_bottom_left = corner_radius
	equipped_style.corner_radius_bottom_right = corner_radius

	# Check if theme has our custom styles defined
	if theme and theme.has_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", default_theme_variation):
		use_theme_variations = false  # Use direct style retrieval instead
		# Get styles from theme
		default_style = theme.get_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", default_theme_variation)
		equipped_style = theme.get_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", equipped_theme_variation)
		# Set initial style
		add_theme_stylebox_override("panel", default_style)
	else:
		use_theme_variations = false
		# Set initial fallback style
		add_theme_stylebox_override("panel", default_style)

	# Set pivot for center scaling
	pivot_offset = custom_minimum_size / 2.0

func setup(texture: Texture2D, index: int):
	"""Configure the slot with sticker data"""
	if not sticker_image:
		sticker_image = get_node("StickerImage")
	sticker_image.texture = texture
	slot_index = index

func set_equipped(equipped: bool):
	"""Update visual state based on equipped status"""
	is_equipped = equipped

	if use_theme_variations:
		# Use theme variation switching
		theme_type_variation = equipped_theme_variation if equipped else default_theme_variation
	else:
		# Use style override (fallback)
		if equipped:
			add_theme_stylebox_override("panel", equipped_style)
		else:
			add_theme_stylebox_override("panel", default_style)

	# Update z-index for proper layering
	z_index = 1 if equipped else 0

func set_fade(fade_amount: float):
	"""Set opacity for fade effect (0.0 - 1.0)"""
	modulate = Color(1, 1, 1, clamp(fade_amount, 0.3, 1.0))

func set_slot_scale(scale_amount: float):
	"""Set scale for this slot"""
	scale = Vector2.ONE * scale_amount
