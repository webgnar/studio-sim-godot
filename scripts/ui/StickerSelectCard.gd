extends Button
class_name StickerSelectCard

func setup(texture: Texture2D, display_name: String) -> void:
	$VBoxContainer/PreviewRect.texture = texture
	$VBoxContainer/NameLabel.text = display_name

func set_selected(selected: bool) -> void:
	modulate = Color(1, 1, 1, 1) if selected else Color(0.6, 0.6, 0.6, 1)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.6, 0.3, 0.5) if selected else Color(0, 0, 0, 0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 1, 0.5, 1) if selected else Color(0, 0, 0, 0)
	add_theme_stylebox_override("normal", style)
