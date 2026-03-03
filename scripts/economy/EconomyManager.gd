extends Node

## Global economy manager - Tracks money and transactions
## Autoload singleton for managing the game's currency system

# Currency
var money: int = 0

# Signals
signal money_changed(new_amount: int)
signal painting_sold(amount: int, source: String)

func _ready():
	# DEBUG: Start with test money and reputation
	money = 5000
	if has_node("/root/ReputationManager"):
		ReputationManager.set_reputation(10.0, 1)  # Level 1, 10 points

	print("EconomyManager: [DEBUG MODE] Starting with $%d and Rep Level 1" % money)
	money_changed.emit(money)  # Update HUD

func add_money(amount: int, source: String = "unknown"):
	"""Add money and emit signals"""
	money += amount
	money_changed.emit(money)
	painting_sold.emit(amount, source)
	print("EconomyManager: +$%d from %s (Total: $%d)" % [amount, source, money])

func spend_money(amount: int, purpose: String = "unknown") -> bool:
	"""Spend money if possible, returns true if successful"""
	if money < amount:
		print("EconomyManager: Cannot afford $%d (have $%d)" % [amount, money])
		return false

	money -= amount
	money_changed.emit(money)
	print("EconomyManager: -$%d for %s (Total: $%d)" % [amount, purpose, money])
	return true

func can_afford(amount: int) -> bool:
	"""Check if player can afford a purchase"""
	return money >= amount

func get_money() -> int:
	"""Get current money amount"""
	return money

func set_money(amount: int):
	"""Set money directly (used by save system)"""
	money = amount
	money_changed.emit(money)
