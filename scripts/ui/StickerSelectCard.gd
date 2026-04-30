extends Button
class_name StickerSelectCard

func setup(texture: Texture2D, display_name: String) -> void:
	$VBoxContainer/PreviewRect.texture = texture
	$VBoxContainer/NameLabel.text = display_name

func set_selected(selected: bool) -> void:
	modulate = Color(1, 1, 1, 1) if selected else Color(0.6, 0.6, 0.6, 1)
