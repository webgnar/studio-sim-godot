extends PanelContainer
class_name StickerSlot

## Reusable sticker slot component for painting UI carousel
## Displays a single sticker with equipped/unequipped visual states

var sticker_image: TextureRect

var slot_index: int = 0
var is_equipped: bool = false

# Visual styling
var default_border_color = Color("#555555")
var equipped_border_color = Color("efc0cbff")
var default_bg_color = Color("#333333", 0.7)

var default_style: StyleBoxFlat
var equipped_style: StyleBoxFlat

func _ready():
	# Get the sticker image child node
	sticker_image = get_node("StickerImage")

	# Initialize styles
	default_style = StyleBoxFlat.new()
	default_style.bg_color = default_bg_color
	default_style.border_color = default_border_color
	default_style.set_border_width_all(2)
	default_style.corner_radius_top_left = 4
	default_style.corner_radius_top_right = 4
	default_style.corner_radius_bottom_left = 4
	default_style.corner_radius_bottom_right = 4

	equipped_style = StyleBoxFlat.new()
	equipped_style.bg_color = default_bg_color
	equipped_style.border_color = equipped_border_color
	equipped_style.set_border_width_all(4)
	equipped_style.corner_radius_top_left = 4
	equipped_style.corner_radius_top_right = 4
	equipped_style.corner_radius_bottom_left = 4
	equipped_style.corner_radius_bottom_right = 4

	# Set initial style
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
	if equipped:
		add_theme_stylebox_override("panel", equipped_style)
		z_index = 1  # Bring selected sticker to top
	else:
		add_theme_stylebox_override("panel", default_style)
		z_index = 0  # Reset to default layer

func set_fade(fade_amount: float):
	"""Set opacity for fade effect (0.0 - 1.0)"""
	modulate = Color(1, 1, 1, clamp(fade_amount, 0.3, 1.0))

func set_slot_scale(scale_amount: float):
	"""Set scale for this slot"""
	scale = Vector2.ONE * scale_amount
