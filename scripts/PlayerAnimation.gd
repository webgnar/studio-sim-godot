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

@export_group("Skate Animation Speeds")
@export var skate_idle_speed: float = 1.0
@export var skate_ollie_speed: float = 1.0
@export var skate_freefall_speed: float = 1.0
@export var skate_impact_speed: float = 1.0

var _is_moving: bool = false
var _is_sprinting: bool = false
var _is_jumping: bool = false
var _was_crouching: bool = false
var _crouch_entered: bool = false  # true after "crouch" transition completes
var _un_crouching: bool = false    # true while playing "crouch" backwards
var _lindy_hop_active: bool = false

# Skateboard animation state
var _skate_board_animation_player: AnimationPlayer = null
var _skate_pending_landing: bool = false  # true whenever airborne, so landing triggers "skate.impact"
var _skate_playing_impact: bool = false   # true while the one-shot impact clip is still playing
var _skate_ollie_apex_time: float = 0.0   # physics time-to-apex (skate_ollie_impulse / gravity); 0 = unset
var _skate_freefall_locked_speed: float = 1.0  # speed_scale locked in once at freefall entry

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

	# skate_impact is a one-shot landing pose, not a looping cycle.
	# Note: Godot's Blender/glTF import converts dots in animation names to
	# underscores, so clips authored as "skate.impact" in Blender land here
	# as "skate_impact" — always reference the underscored form.
	if animation_player.has_animation("skate_impact"):
		animation_player.get_animation("skate_impact").loop_mode = Animation.LOOP_NONE

	# skate_freefall should hold its last frame if the fall runs longer than
	# predicted, not loop back to the start mid-air.
	if animation_player.has_animation("skate_freefall"):
		animation_player.get_animation("skate_freefall").loop_mode = Animation.LOOP_NONE

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

# Called once by PlayerController.start_skating()/stop_skating() so the rider
# and the board's own AnimationPlayer switch states together. Pass null to
# clear the reference on dismount.
func set_skate_board_animation_player(player: AnimationPlayer) -> void:
	_skate_board_animation_player = player
	_skate_pending_landing = false
	_skate_playing_impact = false
	if player and player.has_animation("board_freefall"):
		player.get_animation("board_freefall").loop_mode = Animation.LOOP_NONE

# Called once by PlayerController.start_skating() with the physics time-to-apex
# (skate_ollie_impulse / gravity) so the ollie clip's speed_scale can be
# computed to land its last frame exactly at the jump's peak.
func set_skate_ollie_apex_time(apex_time: float) -> void:
	_skate_ollie_apex_time = apex_time

# Called by PlayerController every physics frame while skating.
# ollie = airborne and still rising, freefall = airborne and falling,
# impact = the one-shot pose that plays the instant the board touches down.
func update_skate_animation_state(_skate_speed: float, is_on_floor: bool, vertical_velocity: float, time_to_land: float = -1.0) -> void:
	if animation_player == null:
		return

	if not is_on_floor:
		_skate_pending_landing = true
		_skate_playing_impact = false
		if vertical_velocity > 0.0:
			_play_skate_pair("skate_ollie", "board_ollie", _compute_ollie_speed())
		else:
			# Lock the speed in once, on the frame freefall starts, instead of
			# recomputing every physics frame — see _compute_freefall_speed.
			if animation_player.current_animation != "skate_freefall":
				_skate_freefall_locked_speed = _compute_freefall_speed(time_to_land)
			_play_skate_pair("skate_freefall", "board_freefall", _skate_freefall_locked_speed)
		return

	if _skate_pending_landing:
		_skate_pending_landing = false
		_skate_playing_impact = true
		_play_skate_pair("skate_impact", "board_impact", skate_impact_speed)
		return

	if _skate_playing_impact:
		return  # let the impact clip finish; _on_animation_finished clears this

	_play_skate_pair("skate_idle", "board_idle", skate_idle_speed)

# Scales "skate_ollie" so its full length plays out exactly across the rise
# phase of the jump — anim_length / time_to_apex — with skate_ollie_speed left
# as a manual multiplier on top (1.0 = exact physics match).
func _compute_ollie_speed() -> float:
	if _skate_ollie_apex_time <= 0.0 or not animation_player.has_animation("skate_ollie"):
		return skate_ollie_speed
	var anim_length := animation_player.get_animation("skate_ollie").length
	if anim_length <= 0.0:
		return skate_ollie_speed
	return (anim_length / _skate_ollie_apex_time) * skate_ollie_speed

# Scales "skate_freefall" so its full length plays out exactly across the
# predicted remaining fall time — anim_length / time_to_land — computed once
# at the moment freefall starts (same one-shot approach as _compute_ollie_speed,
# not recomputed every frame: AnimationPlayer advances on the render tick while
# this runs on the physics tick, and re-deriving speed_scale from
# current_animation_position every physics frame amplifies that clock mismatch
# badly on short falls, even though it averages out fine over a long one).
func _compute_freefall_speed(time_to_land: float) -> float:
	if time_to_land <= 0.0 or not animation_player.has_animation("skate_freefall"):
		return skate_freefall_speed
	var anim_length := animation_player.get_animation("skate_freefall").length
	if anim_length <= 0.0:
		return skate_freefall_speed
	return (anim_length / time_to_land) * skate_freefall_speed

func _play_skate_pair(rider_anim: String, board_anim: String, speed: float = 1.0) -> void:
	play_animation(rider_anim, speed)
	if _skate_board_animation_player and _skate_board_animation_player.has_animation(board_anim):
		if _skate_board_animation_player.current_animation != board_anim:
			_skate_board_animation_player.play(board_anim)
		_skate_board_animation_player.speed_scale = speed

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "crouch":
		if _un_crouching:
			_un_crouching = false
		else:
			_crouch_entered = true
	elif anim_name == "skate_impact":
		_skate_playing_impact = false

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
