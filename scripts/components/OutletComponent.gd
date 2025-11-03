extends Node3D
class_name OutletComponent
## Electrical outlet that power cords can plug into
## Manages plug connections and power state
## Note: Outlet is NOT interactable - plugs detect and connect to outlets, not the other way around

# --- SIGNALS ---
signal power_state_changed(is_powered: bool)
signal plug_inserted(plug: PowerCordPlugComponent)
signal plug_removed(plug: PowerCordPlugComponent)

# --- EXPORTED VARIABLES ---
@export_group("Outlet Settings")
@export var plug_socket_marker: Node3D ## Marker3D where plug snaps to (create as child)
@export var auto_power_on_plug: bool = true ## Automatically power connected devices when plugged
@export var allow_unplug: bool = true ## Can the plug be removed?

@export_group("Visual Feedback")
@export var powered_material: Material ## Material to show when powered
@export var unpowered_material: Material ## Material to show when unpowered
@export var indicator_mesh: MeshInstance3D ## Optional LED/indicator mesh

@export_group("Audio")
@export var plug_in_sound: AudioStream
@export var plug_out_sound: AudioStream

# --- PRIVATE VARIABLES ---
var is_occupied: bool = false
var plugged_cord: PowerCordPlugComponent = null
var is_powered: bool = false
var _audio_player: AudioStreamPlayer3D

# --- INTERNAL REFERENCES ---
var parent_object: Node3D  ## Reference to parent object for positioning

# --- COMPUTED PROPERTIES ---

var plug_socket_position: Vector3:
	get:
		if plug_socket_marker:
			return plug_socket_marker.global_position
		# Fallback: slightly in front of parent object
		return parent_object.global_position + parent_object.global_transform.basis.z * -0.1

# --- GODOT METHODS ---

func _ready() -> void:
	# Get parent reference
	parent_object = get_parent() as Node3D
	if not parent_object:
		push_error("OutletComponent must be child of a Node3D!")
		return
	
	# Ensure audio player exists for outlet sounds
	_ensure_audio_player()
	
	# Add to outlets group for easy finding
	add_to_group("outlets")
	
	# Update visual state
	_update_visual_state()
	
	print("✅ OutletComponent ready: " + parent_object.name)

func _ensure_audio_player() -> void:
	"""Make sure we have an audio player for plug sounds"""
	if (plug_in_sound or plug_out_sound) and not _audio_player:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "OutletAudio"
		_audio_player.max_distance = 10.0
		_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(_audio_player)
		print("Created audio player for outlet sounds")

# --- PLUG MANAGEMENT ---

func accept_plug(plug: PowerCordPlugComponent) -> bool:
	"""Accept a plug into this outlet"""
	
	if is_occupied:
		print("⚠️ Outlet already occupied!")
		return false
	
	if not plug or not is_instance_valid(plug):
		print("⚠️ Invalid plug!")
		return false
	
	# Plug it in
	if plug.plug_into(self):
		is_occupied = true
		plugged_cord = plug
		
		# Update power state
		if auto_power_on_plug:
			set_powered(true)
		
		# Play sound
		if plug_in_sound and _audio_player:
			_audio_player.stream = plug_in_sound
			_audio_player.play()
			print("🔊 Playing plug IN sound")
		else:
			print("⚠️ No plug_in_sound assigned!")
		
		# Emit signal
		plug_inserted.emit(plug)
		
		print("🔌 Plug inserted into outlet: " + parent_object.name)
		return true
	
	return false

func remove_plug() -> bool:
	"""Remove the current plug from this outlet"""
	
	if not is_occupied or not plugged_cord:
		print("⚠️ No plug to remove!")
		return false
	
	if not allow_unplug:
		print("⚠️ Outlet is locked, cannot unplug!")
		return false
	
	var plug = plugged_cord
	
	# Unplug it
	if plug.unplug():
		is_occupied = false
		plugged_cord = null
		
		# Update power state
		if auto_power_on_plug:
			set_powered(false)
		
		# Play sound
		if plug_out_sound and _audio_player:
			_audio_player.stream = plug_out_sound
			_audio_player.play()
			print("🔊 Playing plug OUT sound")
		else:
			print("⚠️ No plug_out_sound assigned!")
		
		# Emit signal
		plug_removed.emit(plug)
		
		print("🔌 Plug removed from outlet: " + parent_object.name)
		return true
	
	return false

# --- POWER STATE ---

func set_powered(powered: bool) -> void:
	"""Set the power state of this outlet"""
	
	if is_powered == powered:
		return
	
	is_powered = powered
	_update_visual_state()
	power_state_changed.emit(is_powered)
	
	print("⚡ Outlet " + parent_object.name + " powered: " + str(is_powered))

func get_is_powered() -> bool:
	"""Check if outlet is currently powered"""
	return is_powered

# --- VISUAL UPDATES ---

func _update_visual_state() -> void:
	"""Update visual indicators based on power state"""
	
	if not indicator_mesh:
		return
	
	# Update material
	if is_powered and powered_material:
		indicator_mesh.material_override = powered_material
	elif not is_powered and unpowered_material:
		indicator_mesh.material_override = unpowered_material

# --- PUBLIC METHODS ---

func get_plugged_cord() -> PowerCordPlugComponent:
	"""Get the currently plugged cord (or null)"""
	return plugged_cord

func force_unplug() -> void:
	"""Force unplug without restrictions (for scripted events)"""
	var temp_allow = allow_unplug
	allow_unplug = true
	remove_plug()
	allow_unplug = temp_allow

func lock_outlet() -> void:
	"""Prevent unplugging"""
	allow_unplug = false

func unlock_outlet() -> void:
	"""Allow unplugging"""
	allow_unplug = true
