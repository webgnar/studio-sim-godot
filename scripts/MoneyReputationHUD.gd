extends CanvasLayer

## Money and Reputation HUD - Displays economy stats in top-right corner
## Phase 0: Basic economy display with animations

@onready var money_label: Label = $MarginContainer/VBoxContainer/MoneyLabel
@onready var reputation_label: Label = $MarginContainer/VBoxContainer/ReputationLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var previous_money: int = 0
var previous_rep_level: int = 0

func _ready():
	# Connect to economy signals
	if has_node("/root/EconomyManager"):
		EconomyManager.money_changed.connect(_on_money_changed)

	if has_node("/root/ReputationManager"):
		ReputationManager.reputation_changed.connect(_on_reputation_changed)
		ReputationManager.level_up.connect(_on_level_up)

	# Initial update
	_update_display()

func _update_display():
	"""Update all labels with current values"""
	if has_node("/root/EconomyManager"):
		previous_money = EconomyManager.get_money()
		money_label.text = "$%d" % previous_money
	else:
		money_label.text = "$0"

	if has_node("/root/ReputationManager"):
		previous_rep_level = ReputationManager.get_reputation_level()
		var rep_points = ReputationManager.get_reputation_points()
		reputation_label.text = "Rep Level %d (%.1f)" % [previous_rep_level, rep_points]
	else:
		reputation_label.text = "Rep Level 0 (0.0)"

func _on_money_changed(new_amount: int):
	"""Animate money change"""
	money_label.text = "$%d" % new_amount

	# Play animation if money increased
	if new_amount > previous_money:
		if animation_player.has_animation("money_gain"):
			animation_player.play("money_gain")
		else:
			# Fallback: simple modulate flash
			var tween = create_tween()
			tween.tween_property(money_label, "modulate", Color.GREEN, 0.2)
			tween.tween_property(money_label, "modulate", Color.WHITE, 0.3)

	previous_money = new_amount

func _on_reputation_changed(new_points: float, new_level: int):
	"""Update reputation display"""
	reputation_label.text = "Rep Level %d (%.1f)" % [new_level, new_points]

	# Simple flash on reputation gain
	var tween = create_tween()
	tween.tween_property(reputation_label, "modulate", Color(1.0, 0.8, 0.2), 0.2)  # Gold color
	tween.tween_property(reputation_label, "modulate", Color.WHITE, 0.3)

func _on_level_up(new_level: int, old_level: int):
	"""Play special animation on level up"""
	print("MoneyReputationHUD: Level up detected! %d → %d" % [old_level, new_level])

	# TODO: Add more dramatic level-up animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(reputation_label, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(reputation_label, "modulate", Color.YELLOW, 0.3)
	tween.set_parallel(false)
	tween.tween_property(reputation_label, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_property(reputation_label, "modulate", Color.WHITE, 0.3)
