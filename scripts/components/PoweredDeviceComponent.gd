extends InteractionComponent
class_name PoweredDeviceComponent
## Component for devices that require power to operate
## Automatically connects to associated PowerCordPlugComponent to track power state
## Only allows interaction when powered

# --- SIGNALS ---
signal powered_on()
signal powered_off()
signal power_state_changed(is_powered: bool)
signal device_turned_on()
signal device_turned_off()

# --- EXPORTED VARIABLES ---
@export_group("Power Settings")
@export var power_cord_plug: PowerCordPlugComponent ## The plug component for this device
@export var requires_power: bool = true ## If false, device works even when unplugged
@export var auto_turn_off_on_unplug: bool = true ## Automatically turn off when unplugged

@export_group("Device State")
@export var is_on: bool = false ## Current on/off state of the device
@export var on_interaction_text: String = "Turn Off" ## Text when device is on
@export var off_interaction_text: String = "Turn On" ## Text when device is off
@export var no_power_text: String = "No Power" ## Text when device has no power

@export_group("Device Audio")
@export var turn_on_sound: AudioStream ## Sound when device turns on
@export var turn_off_sound: AudioStream ## Sound when device turns off
@export var no_power_sound: AudioStream ## Sound when trying to use with no power

# --- PRIVATE VARIABLES ---
var has_power: bool = false

# --- GODOT METHODS ---

func _ready() -> void:
	super._ready()
	
	# Connect to power cord plug signals
	if power_cord_plug:
		power_cord_plug.plugged_into.connect(_on_plugged_in)
		power_cord_plug.unplugged_from.connect(_on_unplugged)
		
		# Check initial power state
		has_power = power_cord_plug.is_plugged
	else:
		# If no power cord, assume always powered (or never powered if required)
		has_power = not requires_power

	_update_interaction_text()

# --- INTERACTION ---

func interact(_interactor: Node3D) -> void:
	"""Toggle device on/off (only if powered)"""

	if requires_power and not has_power:
		# Play "no power" sound
		if no_power_sound:
			_play_sound(no_power_sound)
		return

	# Toggle state
	is_on = !is_on

	# Update interaction text
	_update_interaction_text()

	# Play appropriate sound and emit signals
	if is_on:
		if turn_on_sound:
			_play_sound(turn_on_sound)
		device_turned_on.emit()
	else:
		if turn_off_sound:
			_play_sound(turn_off_sound)
		device_turned_off.emit()

# --- POWER STATE ---

func _on_plugged_in(outlet: OutletComponent) -> void:
	"""Called when power cord is plugged into outlet"""
	has_power = true
	power_state_changed.emit(true)
	powered_on.emit()
	_update_interaction_text()

func _on_unplugged(outlet: OutletComponent) -> void:
	"""Called when power cord is unplugged from outlet"""
	has_power = false
	power_state_changed.emit(false)
	powered_off.emit()

	# Auto turn off if enabled
	if auto_turn_off_on_unplug and is_on:
		is_on = false
		device_turned_off.emit()

	_update_interaction_text()

func _update_interaction_text() -> void:
	"""Update the interaction text based on power and state"""
	if requires_power and not has_power:
		interaction_text = no_power_text
	elif is_on:
		interaction_text = on_interaction_text
	else:
		interaction_text = off_interaction_text

# --- PUBLIC METHODS ---

func turn_on() -> bool:
	"""Programmatically turn on the device"""
	if requires_power and not has_power:
		return false
	
	if not is_on:
		is_on = true
		if turn_on_sound:
			_play_sound(turn_on_sound)
		device_turned_on.emit()
		_update_interaction_text()
	return true

func turn_off() -> bool:
	"""Programmatically turn off the device"""
	if is_on:
		is_on = false
		if turn_off_sound:
			_play_sound(turn_off_sound)
		device_turned_off.emit()
		_update_interaction_text()
	return true

func get_power_state() -> bool:
	"""Returns true if device has power"""
	return has_power

func get_device_state() -> bool:
	"""Returns true if device is turned on"""
	return is_on
