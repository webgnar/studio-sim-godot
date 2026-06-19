extends Node3D

@export var move_positions: Array[Marker3D] = []

@onready var hit_area: Area3D = $HitArea
@onready var smoke_effect: GPUParticles3D = $SmokeEffect

func _ready() -> void:
	hit_area.body_entered.connect(_on_nail_hit)

func _on_nail_hit(body: Node) -> void:
	if body is ProjectileNail:
		_emit_smoke(body.global_position)
		_move_to_next_position()

func _emit_smoke(pos: Vector3) -> void:
	smoke_effect.global_position = pos
	smoke_effect.emitting = false
	smoke_effect.restart()

@export var fly_duration: float = 2.0

var _is_flying: bool = false

func _move_to_next_position() -> void:
	if move_positions.is_empty() or _is_flying:
		return
	var candidates := move_positions.filter(func(m): return m.global_position != global_position)
	if candidates.is_empty():
		candidates = move_positions
	var target: Marker3D = candidates[randi() % candidates.size()]
	_is_flying = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", target.global_position, fly_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): _is_flying = false)
