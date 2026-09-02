extends CSGBox3D
class_name HiddenDoorFog

## Gates the gallery's "Hidden Door" behind the coin pusher's first scored
## ball: swaps this doormesh's material for the fog_door shader once that
## happens, so the door visually reveals itself as a passable-looking fog
## wall instead of a plain solid wall. Once revealed, it's a "press E to
## traverse" interactable — dissolves the fog (shader `dissolve` 0 -> 1),
## plays the traverse sound, and opens the passage, permanently, via its own
## persisted flag.

const FOG_SHADER: Shader = preload("res://shaders/fog_door.gdshader")
const TRAVERSE_SOUND: AudioStream = preload("res://sounds/picotron/hidden door.ogg")
const TRAVERSED_FLAG := "hidden_door_traversed"
const DISSOLVE_DURATION := 2.0
const ACHIEVEMENT_ID := "ACH_MORE_GALLERY_SPACE"

var interaction_text: String = "Traverse the White Light?"

var _mat: ShaderMaterial
var _dissolved := false
var _sound: AudioStreamPlayer3D

func _ready() -> void:
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = TRAVERSE_SOUND
	_sound.max_distance = 15.0
	_sound.bus = "SFX"
	add_child(_sound)

	if WorldStateManager.has_flag(TRAVERSED_FLAG):
		_apply_fog()
		_open_passage(1.0)  # already traversed in a past session — skip straight to "gone", no animation/sound
	elif WorldStateManager.has_flag(GameManager.FIRST_BALL_FLAG):
		_apply_fog()
	else:
		# Flag data may not be loaded from the save file yet when this node's
		# own _ready() runs (same reasoning as BoomboxInteraction.gd's
		# rf_receiver re-sync) — re-check once world state actually loads.
		WorldStateManager.world_state_loaded.connect(_recheck_flag, CONNECT_ONE_SHOT)
		# Not unlocked yet — the real material swap happens later, whenever the
		# player scores their first ball. Warm the shader's render pipeline now
		# (off-screen, during load) instead of letting it compile for the first
		# time at that moment, which is what caused the noticeable hitch.
		ShaderPrewarmer.prewarm(FOG_SHADER, self)
	GameManager.first_ball_scored.connect(_apply_fog)

func _recheck_flag() -> void:
	if WorldStateManager.has_flag(TRAVERSED_FLAG):
		_apply_fog()
		_open_passage(1.0)
	elif WorldStateManager.has_flag(GameManager.FIRST_BALL_FLAG):
		_apply_fog()

func _apply_fog() -> void:
	if _mat:
		return  # already applied — e.g. first_ball_scored firing after a flag-based apply already ran
	_mat = ShaderMaterial.new()
	_mat.shader = FOG_SHADER
	material = _mat
	if not _dissolved:
		add_to_group("interactable")

func interact(_interactor) -> void:
	if _dissolved:
		return
	_dissolved = true
	remove_from_group("interactable")
	WorldStateManager.set_flag(TRAVERSED_FLAG)
	SteamManager.unlock_achievement(ACHIEVEMENT_ID)
	_sound.play()
	# Collision drops immediately — the player just pressed "traverse" and
	# shouldn't stand there blocked while the fog visually burns away.
	use_collision = false
	var tween := create_tween()
	# tween_method + set_shader_parameter explicitly, rather than
	# tween_property(_mat, "shader_parameter/dissolve", ...) — that string
	# path relies on Godot's NodePath parsing treating "/" as a nested-property
	# separator on a plain Resource, which isn't something to keep trusting
	# blindly if it's not visibly working.
	tween.tween_method(_set_dissolve, 0.0, 1.0, DISSOLVE_DURATION)
	# The shader's own alpha already hits exactly 0 at dissolve = 1 (verified
	# against its math), but explicitly hiding it once the fade finishes
	# guarantees "gone" is really gone — no lingering fully-transparent quad
	# still costing a draw call — rather than relying on alpha alone.
	tween.tween_callback(func(): visible = false)

func _set_dissolve(value: float) -> void:
	if _mat:
		_mat.set_shader_parameter("dissolve", value)

func _open_passage(dissolve_value: float) -> void:
	_dissolved = true
	remove_from_group("interactable")
	use_collision = false
	if _mat:
		_mat.set_shader_parameter("dissolve", dissolve_value)
	visible = false
	# Retroactive — covers saves where the door was already traversed before
	# this achievement existed. unlock_achievement() is documented as
	# idempotent, matching SteamManager's existing retroactive-unlock pattern
	# (_check_retroactive_export_achievements etc.) for players who'd already
	# earned something before the achievement got added.
	SteamManager.unlock_achievement(ACHIEVEMENT_ID)
