extends CanvasLayer

## Money HUD - Displays money in top-right corner

@onready var money_label: Label = $MarginContainer/VBoxContainer/MoneyLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var previous_money: int = 0

func _ready():
	if has_node("/root/EconomyManager"):
		EconomyManager.money_changed.connect(_on_money_changed)

	_update_display()

func _update_display():
	if has_node("/root/EconomyManager"):
		previous_money = EconomyManager.get_money()
		money_label.text = "$%d" % previous_money
	else:
		money_label.text = "$0"

func _on_money_changed(new_amount: int):
	money_label.text = "$%d" % new_amount

	if new_amount > previous_money:
		if animation_player.has_animation("money_gain"):
			animation_player.play("money_gain")
		else:
			var tween = create_tween()
			tween.tween_property(money_label, "modulate", Color.GREEN, 0.2)
			tween.tween_property(money_label, "modulate", Color.WHITE, 0.3)

	previous_money = new_amount
