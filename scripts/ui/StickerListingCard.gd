extends Button
class_name StickerListingCard

func setup(display_name: String, price: int, seller_id: String, seller_name: String = "") -> void:
	$MarginContainer/HBoxContainer/VBoxContainer/NameLabel.text = display_name
	$MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/PriceLabel.text = "$%d" % price
	var seller_display = seller_name if seller_name != "" else seller_id.substr(0, 8)
	$MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/SellerLabel.text = "by %s" % seller_display


func set_preview(texture: Texture2D) -> void:
	$MarginContainer/HBoxContainer/PreviewRect.texture = texture
