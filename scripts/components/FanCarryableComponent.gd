extends CarryableComponent
class_name FanCarryableComponent
## Fan carryable component - allows pickup with E-key interaction to control power

@export var powered_device: PoweredDeviceComponent

func _ready() -> void:
	super._ready()
	
	# Enable E-key interaction while allowing pickup
	has_e_key_interaction = true
	can_interact_while_carried = false  # Can't toggle while carrying
	
	# Find PoweredDeviceComponent if not set
	if not powered_device:
		powered_device = _find_powered_device_component()
	
	# Update interaction text based on power state
	if powered_device:
		powered_device.device_turned_on.connect(_update_interaction_text)
		powered_device.device_turned_off.connect(_update_interaction_text)
		powered_device.power_state_changed.connect(_on_power_changed)
		_update_interaction_text()

func _on_e_key_interacted(player_interaction: PlayerInteractionComponent) -> void:
	"""E-key toggles the fan on/off via PoweredDeviceComponent"""
	if powered_device:
		powered_device.interact(player_interaction)
		if powered_device.is_on and SteamManager:
			SteamManager.unlock_achievement("ACH_FAN")

func _update_interaction_text() -> void:
	"""Update the E-key text based on fan state"""
	if not powered_device:
		e_key_interaction_text = "Turn On Fan"
		return
	
	if powered_device.requires_power and not powered_device.has_power:
		e_key_interaction_text = "No Power"
	elif powered_device.is_on:
		e_key_interaction_text = "Turn Off Fan"
	else:
		e_key_interaction_text = "Turn On Fan"

func _on_power_changed(_is_powered: bool) -> void:
	"""Update text when power state changes"""
	_update_interaction_text()

func _find_powered_device_component() -> PoweredDeviceComponent:
	"""Search for PoweredDeviceComponent in parent's children"""
	if not parent_object:
		return null
	
	for child in parent_object.get_children():
		if child is PoweredDeviceComponent:
			return child
		# Search deeper
		var result = _find_in_children(child)
		if result:
			return result
	
	return null

func _find_in_children(node: Node) -> PoweredDeviceComponent:
	"""Recursively search for PoweredDeviceComponent"""
	for child in node.get_children():
		if child is PoweredDeviceComponent:
			return child
		var result = _find_in_children(child)
		if result:
			return result
	return null
