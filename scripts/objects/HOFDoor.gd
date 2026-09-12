extends Node3D
class_name HOFDoor

## Gates the Hall of Fame door: stays locked until the basketball hoop registers a
## make (BasketballHoop.basket_scored). Scoring only UNLOCKS the door and plays the
## hoop's make sound — the actual swing-open animation only plays once the player
## interacts with the door (see HOFDoorInteraction.gd, a child InteractionComponent).
## Unlock state persists across save/load via WorldStateManager flags.

signal unlocked

const UNLOCK_FLAG: String = "hof_door_unlocked"
const ACHIEVEMENT_ID: String = "ACH_HALL_OF_FAME"

@export var basketball_hoop: BasketballHoop
@export var animation_player: AnimationPlayer
@export var open_animation_name: String = "open"
@export var make_sound: AudioStream = preload("res://sounds/basketball.ogg")

var _is_unlocked: bool = false
var _is_open: bool = false
var _sfx: AudioStreamPlayer3D

func _ready() -> void:
	if not basketball_hoop:
		basketball_hoop = get_tree().get_first_node_in_group("basketball_hoop") as BasketballHoop
	if not animation_player:
		animation_player = get_node_or_null("AnimationPlayer")

	_sfx = AudioStreamPlayer3D.new()
	_sfx.name = "MakeSound"
	_sfx.stream = make_sound
	_sfx.max_distance = 20.0
	add_child(_sfx)

	if basketball_hoop:
		basketball_hoop.basket_scored.connect(_on_basket_scored)
	else:
		push_warning("HOFDoor: no BasketballHoop found (group 'basketball_hoop') — door will never unlock")

	# Already unlocked from a previous session — snap straight to open, no re-interaction needed.
	if WorldStateManager and WorldStateManager.has_flag(UNLOCK_FLAG):
		_is_unlocked = true
		_snap_open()

func is_unlocked() -> bool:
	return _is_unlocked

func is_open() -> bool:
	return _is_open

func _on_basket_scored() -> void:
	if _is_unlocked:
		return
	_is_unlocked = true
	if WorldStateManager:
		WorldStateManager.set_flag(UNLOCK_FLAG)
	print("[HOFDoor] Basket made — door unlocked, interact to open")
	_sfx.play()
	unlocked.emit()

## Called by HOFDoorInteraction once the player interacts with the (unlocked) door.
func open_door() -> void:
	if not _is_unlocked or _is_open:
		return
	_is_open = true
	print("[HOFDoor] Door opened")
	SteamManager.unlock_achievement(ACHIEVEMENT_ID)
	if animation_player and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)
	else:
		push_warning("HOFDoor: AnimationPlayer/'%s' animation missing" % open_animation_name)

func _snap_open() -> void:
	_is_open = true
	# Retroactive — covers saves where the door was already unlocked before this
	# achievement existed. unlock_achievement() is idempotent.
	SteamManager.unlock_achievement(ACHIEVEMENT_ID)
	if animation_player and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)
		animation_player.seek(animation_player.current_animation_length, true)
