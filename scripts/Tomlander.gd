extends Node3D

@onready var hit_area: Area3D = $HitArea
@onready var smoke_effect: GPUParticles3D = $SmokeEffect

func _ready() -> void:
	hit_area.body_entered.connect(_on_nail_hit)

func _on_nail_hit(body: Node) -> void:
	print("Tomlander: body entered HitArea — ", body.name)
	if body is ProjectileNail:
		print("Tomlander: nail hit! emitting smoke at ", body.global_position)
		_emit_smoke(body.global_position)

func _emit_smoke(pos: Vector3) -> void:
	smoke_effect.global_position = pos
	smoke_effect.emitting = false
	smoke_effect.restart()
