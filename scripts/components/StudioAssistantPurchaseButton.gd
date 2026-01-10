extends InteractionComponent
class_name StudioAssistantPurchaseButton

## Purchase button for Studio Assistant upgrade
## Extends InteractionComponent for proper player interaction

func _ready() -> void:
	print("StudioAssistantPurchaseButton: _ready() called on node: ", name)
	super._ready()  # Call parent InteractionComponent._ready() first
	_update_interaction_text()
	print("StudioAssistantPurchaseButton: Interaction text set to: ", interaction_text)

	# Connect to AutomationManager signal to update text when purchased
	if has_node("/root/AutomationManager"):
		AutomationManager.assistant_purchased.connect(_on_assistant_purchased)
		print("StudioAssistantPurchaseButton: Connected to AutomationManager signals")

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	print("StudioAssistantPurchaseButton: _on_interacted() called!")

	# Check if already purchased
	if AutomationManager.is_assistant_active():
		print("StudioAssistantPurchaseButton: Already purchased")
		return

	# Check if can afford
	if not AutomationManager.can_purchase_assistant():
		var status = AutomationManager.get_assistant_status()
		var money = EconomyManager.get_money()
		var level = ReputationManager.get_reputation_level()

		print("StudioAssistantPurchaseButton: Cannot afford!")
		print("  Cost: $%d (you have $%d)" % [status.cost, money])
		print("  Requires: Rep Level %d (you are Level %d)" % [status.rep_required, level])

		# TODO: Show "not enough money/reputation" UI feedback
		return

	# Attempt purchase
	if AutomationManager.purchase_studio_assistant():
		print("StudioAssistantPurchaseButton: Purchase successful!")
		_update_interaction_text()

		# TODO: Play success sound/animation
	else:
		print("StudioAssistantPurchaseButton: Purchase failed!")

func _on_assistant_purchased():
	"""Called when assistant is purchased (from anywhere)"""
	_update_interaction_text()

func _update_interaction_text():
	"""Update the interaction prompt based on purchase state"""
	if not has_node("/root/AutomationManager"):
		interaction_text = "Upgrade Unavailable"
		is_disabled = true
		return

	var status = AutomationManager.get_assistant_status()

	if status.active:
		interaction_text = "Studio Assistant Active"
		is_disabled = true
	elif AutomationManager.can_purchase_assistant():
		interaction_text = "Hire Studio Assistant ($%d)" % status.cost
		is_disabled = false
	else:
		var money = EconomyManager.get_money() if has_node("/root/EconomyManager") else 0
		var level = ReputationManager.get_reputation_level() if has_node("/root/ReputationManager") else 0

		if money < status.cost:
			interaction_text = "Hire Assistant ($%d) - Need $%d more" % [status.cost, status.cost - money]
		elif level < status.rep_required:
			interaction_text = "Hire Assistant - Need Rep Level %d" % status.rep_required
		else:
			interaction_text = "Hire Assistant ($%d)" % status.cost

		is_disabled = false  # Allow looking at it to see requirements
