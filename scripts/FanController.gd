extends Node3D
## Controls fan blade animation based on power state

@export var powered_device: PoweredDeviceComponent
@export var animation_player: AnimationPlayer
@export var spin_animation_name: String = "spin"

func _ready() -> void:
	if not powered_device:
		print("⚠️ FanController: No PoweredDeviceComponent assigned!")
		return
	
	if not animation_player:
		print("⚠️ FanController: No AnimationPlayer assigned!")
		return
	
	# Connect to power signals
	powered_device.device_turned_on.connect(_on_fan_turned_on)
	powered_device.device_turned_off.connect(_on_fan_turned_off)
	powered_device.powered_off.connect(_on_power_lost)
	
	# Set initial state
	if powered_device.is_on and powered_device.has_power:
		animation_player.play(spin_animation_name)
	else:
		animation_player.stop()
	
	print("✅ FanController ready")

func _on_fan_turned_on() -> void:
	"""Start spinning the fan"""
	if animation_player:
		animation_player.play(spin_animation_name)
		print("🌀 Fan spinning")

func _on_fan_turned_off() -> void:
	"""Stop spinning the fan"""
	if animation_player:
		animation_player.stop()
		print("⏹️ Fan stopped")

func _on_power_lost() -> void:
	"""Power cut - stop the fan"""
	if animation_player:
		animation_player.stop()
		print("⚡ Fan lost power")
