extends Button
class_name StickerListingCard

func setup(display_name: String, price: int, seller_id: String) -> void:
	$MarginContainer/HBoxContainer/VBoxContainer/NameLabel.text = display_name
	$MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/PriceLabel.text = "$%d" % price
	$MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/SellerLabel.text = "by %s" % seller_id.substr(0, 8)


func set_preview(texture: Texture2D) -> void:
	$MarginContainer/HBoxContainer/PreviewRect.texture = texture
