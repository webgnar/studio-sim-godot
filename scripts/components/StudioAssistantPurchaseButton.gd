extends InteractionComponent
class_name StudioAssistantPurchaseButton

## Purchase button for Studio Assistant upgrade
## Extends InteractionComponent for proper player interaction

var _purchase_stream: AudioStream = preload("res://sounds/picotron/lougnar_sound.ogg")
var _error_stream: AudioStream = preload("res://sounds/picotron/error.ogg")
var _purchase_sound: AudioStreamPlayer3D
var _error_sound: AudioStreamPlayer3D

func _ready() -> void:
	print("StudioAssistantPurchaseButton: _ready() called on node: ", name)
	super._ready()  # Call parent InteractionComponent._ready() first

	_purchase_sound = AudioStreamPlayer3D.new()
	_purchase_sound.name = "PurchaseSound"
	_purchase_sound.max_distance = 15.0
	_purchase_sound.bus = "SFX"
	_purchase_sound.stream = _purchase_stream
	add_child(_purchase_sound)

	_error_sound = AudioStreamPlayer3D.new()
	_error_sound.name = "ErrorSound"
	_error_sound.max_distance = 15.0
	_error_sound.bus = "SFX"
	_error_sound.stream = _error_stream
	add_child(_error_sound)

	_update_interaction_text()
	print("StudioAssistantPurchaseButton: Interaction text set to: ", interaction_text)

	# Connect to AutomationManager signal to update text when purchased
	if has_node("/root/AutomationManager"):
		AutomationManager.assistant_purchased.connect(_on_assistant_purchased)
		print("StudioAssistantPurchaseButton: Connected to AutomationManager signals")

func interact(player_interaction_component: PlayerInteractionComponent) -> void:
	if is_disabled:
		_error_sound.play()
		return
	super.interact(player_interaction_component)

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

		print("StudioAssistantPurchaseButton: Cannot afford!")
		print("  Cost: $%d (you have $%d)" % [status.cost, money])

		# TODO: Show "not enough money" UI feedback
		return

	# Attempt purchase
	if AutomationManager.purchase_studio_assistant():
		print("StudioAssistantPurchaseButton: Purchase successful!")
		_update_interaction_text()

		# Play success sound
		_purchase_sound.play()

		# Visual feedback - flash green
		_play_purchase_animation()
	else:
		print("StudioAssistantPurchaseButton: Purchase failed!")

func _on_assistant_purchased():
	"""Called when assistant is purchased (from anywhere)"""
	_update_interaction_text()
	_play_purchase_animation()

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
		interaction_text = "Hire Assistant ($%d)" % status.cost
		is_disabled = false  # Allow looking at it to see requirements

func _play_purchase_animation() -> void:
	"""Press the green button and leave it down — one-time use."""
	var anim_player = get_node_or_null("../green button/AnimationPlayer")
	if not anim_player:
		return
	anim_player.play("press")
