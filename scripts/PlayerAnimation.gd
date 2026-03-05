extends Node
class_name PlayerAnimation

@export var animation_player: AnimationPlayer

@export_group("Animation Speeds")
@export var idle_speed: float = 1.0
@export var walk_speed: float = 1.5
@export var run_speed: float = 2.0
@export var jump_speed: float = 1.0
@export var crouch_speed: float = 1.0
@export var lindy_hop_speed: float = 1.0

var _is_moving: bool = false
var _is_sprinting: bool = false
var _is_jumping: bool = false
var _was_crouching: bool = false
var _crouch_entered: bool = false  # true after "crouch" transition completes
var _un_crouching: bool = false    # true while playing "crouch" backwards
var _lindy_hop_active: bool = false

func _ready() -> void:
	# Get reference to AnimationPlayer node
	animation_player = get_node("AnimationPlayer")

	if animation_player == null:
		push_warning("AnimationPlayer not found! Please check scene structure.")
		return

	# Crouch plays once as a transition; crouchidle and crouchwalk loop
	if animation_player.has_animation("crouch"):
		animation_player.get_animation("crouch").loop_mode = Animation.LOOP_NONE
	if animation_player.has_animation("crouchidle"):
		animation_player.get_animation("crouchidle").loop_mode = Animation.LOOP_LINEAR
	if animation_player.has_animation("crouchwalk"):
		animation_player.get_animation("crouchwalk").loop_mode = Animation.LOOP_LINEAR

	animation_player.animation_finished.connect(_on_animation_finished)

# Called by PlayerController to update animation state
func update_animation_state(velocity: Vector3, is_on_floor: bool, is_sprinting: bool, is_crouching: bool = false, lindy_hop: bool = false) -> void:
	if animation_player == null:
		return

	_is_moving = velocity.length() > 0.1
	_is_sprinting = is_sprinting and _is_moving

	# Handle jumping/falling
	if not is_on_floor:
		if not _is_jumping:
			# Try jump animation, fall back to idle if not available
			if not play_animation("jump", jump_speed):
				play_animation("idle", idle_speed)
			_is_jumping = true
			_crouch_entered = false
			_un_crouching = false
	else:
		_is_jumping = false

		if _was_crouching and not is_crouching:
			# Start un-crouch: play transition backwards
			_un_crouching = true
			_crouch_entered = false
			if animation_player.has_animation("crouch"):
				animation_player.play_backwards("crouch")
				animation_player.speed_scale = crouch_speed
		elif _un_crouching:
			# Don't interrupt the backwards crouch transition
			pass
		elif is_crouching:
			if _is_moving:
				play_animation("crouchwalk", crouch_speed)
			elif _crouch_entered:
				play_animation("crouchidle", crouch_speed)
			else:
				# Play enter-crouch transition if not already playing
				if animation_player.current_animation != "crouch":
					animation_player.play("crouch")
					animation_player.speed_scale = crouch_speed
		elif _is_moving:
			if _is_sprinting:
				play_animation("run", run_speed)
			else:
				play_animation("walk", walk_speed)
		else:
			if lindy_hop:
				play_animation("lindy hop", lindy_hop_speed)
				_lindy_hop_active = true
			else:
				_lindy_hop_active = false
				play_animation("idle", idle_speed)

	_was_crouching = is_crouching

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "crouch":
		if _un_crouching:
			_un_crouching = false
		else:
			_crouch_entered = true

func play_animation(animation_name: String, speed: float = 1.0) -> bool:
	if animation_player != null and animation_player.has_animation(animation_name):
		if animation_player.current_animation != animation_name:
			animation_player.play(animation_name)
		
		# Set the speed multiplier
		animation_player.speed_scale = speed
		return true
	else:
		push_warning("Animation '" + animation_name + "' not found or AnimationPlayer is null!")
		return false
