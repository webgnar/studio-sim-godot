extends Node3D

enum Phase { MOVE, COMBAT }

@export var move_positions: Array[Marker3D] = []
@export var combat_positions: Array[Marker3D] = []
@export var fly_duration: float = 2.0
@export var shoot_interval: float = 1.5
@export var projectile_speed: float = 12.0

@onready var hit_area: Area3D = $HitArea
@onready var smoke_effect: GPUParticles3D = $SmokeEffect

var _phase: Phase = Phase.MOVE
var _position_index: int = 0
var _is_flying: bool = false
var _shoot_timer: float = 0.0
var _mantis_texture: Texture2D = preload("res://sprites/mantis.png")
var _spark_texture: Texture2D = preload("res://sprites/spark.png")
var _thruster_sound: AudioStream = preload("res://sounds/picotron/thruster.ogg")
var _tomhit_sound: AudioStream = preload("res://sounds/picotron/tomhit.ogg")
var _alienthit_sound: AudioStream = preload("res://sounds/picotron/alienthit.ogg")
var _mantis_frames: SpriteFrames

func _ready() -> void:
	hit_area.body_entered.connect(_on_nail_hit)
	_mantis_frames = _build_mantis_frames()

func _process(delta: float) -> void:
	if _phase == Phase.COMBAT and not _is_flying:
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = shoot_interval
			_shoot_mantis()

func _on_nail_hit(body: Node) -> void:
	if body is ProjectileNail:
		_play_sound_at(_tomhit_sound, body.global_position)
		_emit_smoke(body.global_position)
		_advance()

func _emit_smoke(pos: Vector3) -> void:
	smoke_effect.global_position = pos
	smoke_effect.emitting = false
	smoke_effect.restart()

func _advance() -> void:
	if _is_flying:
		return

	var positions: Array[Marker3D]
	match _phase:
		Phase.MOVE:
			positions = move_positions
		Phase.COMBAT:
			positions = combat_positions

	if positions.is_empty():
		return

	if _position_index >= positions.size():
		if _phase == Phase.MOVE:
			_phase = Phase.COMBAT
			_position_index = 0
			_shoot_timer = shoot_interval
			_advance()
			return
		else:
			_position_index = 0

	var target := positions[_position_index]
	_position_index += 1
	_fly_to(target.global_position)

func _fly_to(target_pos: Vector3) -> void:
	_is_flying = true
	_play_sound_at(_thruster_sound, global_position)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, fly_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): _is_flying = false)

func _shoot_mantis() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	var dir := (player.global_position - global_position).normalized()

	var projectile := MantisProjectile.new()
	projectile.direction = dir
	projectile.speed = projectile_speed
	projectile.sprite_frames = _mantis_frames
	projectile.spark_texture = _spark_texture
	projectile.hit_player_sound = _alienthit_sound
	get_tree().root.add_child(projectile)
	projectile.global_position = global_position

func _play_sound_at(stream: AudioStream, pos: Vector3) -> void:
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = stream
	sfx.bus = "SFX"
	sfx.max_distance = 50.0
	get_tree().root.add_child(sfx)
	sfx.global_position = pos
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _build_mantis_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var atlas: Texture2D = _mantis_texture
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = atlas
		at.region = Rect2(i * 112, 0, 112, 122)
		frames.add_frame("default", at)
	frames.set_animation_speed("default", 8.0)
	frames.set_animation_loop("default", true)
	return frames
