extends Button
class_name ShopItemCard

func setup(display_name: String) -> void:
	get_node("MarginContainer/HBoxContainer/NameLabel").text = display_name
