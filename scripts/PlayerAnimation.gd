extends Node
class_name PlayerAnimation

@export var animation_player: AnimationPlayer

@export_group("Animation Speeds")
@export var idle_speed: float = 1.0
@export var walk_speed: float = 1.5
@export var run_speed: float = 2.0

var _is_moving: bool = false
var _is_sprinting: bool = false
var _is_jumping: bool = false

func _ready() -> void:
	# Get reference to AnimationPlayer node
	animation_player = get_node("AnimationPlayer")
	
	if animation_player == null:
		print("AnimationPlayer not found! Please check scene structure.")
	else:
		# List available animations for debugging
		var available_animations := animation_player.get_animation_list()
		print("Available animations: " + str(available_animations))

# Called by PlayerController to update animation state
func update_animation_state(velocity: Vector3, is_on_floor: bool, is_sprinting: bool) -> void:
	if animation_player == null:
		print("AnimationPlayer is null!")
		return
	
	var was_moving := _is_moving
	_is_moving = velocity.length() > 0.1
	_is_sprinting = is_sprinting and _is_moving
	
	# Handle jumping/falling
	if not is_on_floor:
		if not _is_jumping:
			# Try jump animation, fall back to idle if not available
			if not play_animation("jump", idle_speed):
				play_animation("idle", idle_speed)
			_is_jumping = true
	else:
		_is_jumping = false
		
		# Handle ground movement animations
		if _is_moving:
			if _is_sprinting:
				play_animation("run", run_speed) # Use "run" for sprinting with faster speed
			else:
				play_animation("walk", walk_speed) # Use "walk" for normal movement with moderate speed
		else:
			play_animation("idle", idle_speed)

func play_animation(animation_name: String, speed: float = 1.0) -> bool:
	if animation_player != null and animation_player.has_animation(animation_name):
		if animation_player.current_animation != animation_name:
			animation_player.play(animation_name)
			print("Successfully playing animation: " + animation_name + " at speed " + str(speed) + "x")
		
		# Set the speed multiplier
		animation_player.speed_scale = speed
		return true
	else:
		print("Animation '" + animation_name + "' not found or AnimationPlayer is null!")
		return false
