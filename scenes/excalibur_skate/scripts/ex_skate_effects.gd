class_name ExSkateEffects
extends Node2D
## Particles, pickup flash and floating score text
## (port of particle-manager.ts + floating-text-manager.ts). Lives in world space.

const GOLD := Color("#FFD700")
const CYAN := Color("#00FFFF")

var _grind: CPUParticles2D
var _transient: Node2D
var _previous_state: int = -1


func _ready() -> void:
	z_index = 8
	_transient = Node2D.new()
	add_child(_transient)
	_make_grind_emitter()


func update(player: ExSkatePlayer) -> void:
	_grind.position = player.position

	var state := player.get_state()
	if state == ExSkatePlayer.State.LANDING and _previous_state != ExSkatePlayer.State.LANDING \
			and not player.get_is_ufo_bounce():
		_burst(ExSkateAssets.DUST_PUFF, player.position, randi_range(8, 12), 0.5,
			Vector2.RIGHT, 180.0, 100.0, 200.0, 1.0, 1.5, 10.0, Vector2.ZERO)
	_previous_state = state

	var grinding := player.current_grind_rail != null
	_grind.emitting = grinding
	if grinding and randf() < 0.1:
		_grind.texture = ExSkateAssets.SPARKS[randi() % ExSkateAssets.SPARKS.size()]


func on_collectible(value: int, pos: Vector2) -> void:
	_pickup_smash(pos)
	_floating_text("+%d" % value, pos, GOLD)


func on_ufo_destroyed(pos: Vector2, value: int) -> void:
	# Upward star spray.
	_burst(ExSkateAssets.STAR, pos, randi_range(12, 17), 0.6,
		Vector2.UP, 54.0, 150.0, 250.0, 0.8, 1.5, 5.0, Vector2(0, 100))
	_floating_text("+%d" % value, pos, CYAN)


func cleanup() -> void:
	for child in _transient.get_children():
		child.queue_free()
	_grind.queue_free()
	_make_grind_emitter()
	_previous_state = -1


func _make_grind_emitter() -> void:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = 6 # 10/s at 0.6s lifetime
	p.lifetime = 0.6
	p.local_coords = false
	p.texture = ExSkateAssets.SPARKS[0]
	# Sparks spray left/back and down: 90deg..252deg => centre 171deg, +-81deg.
	p.direction = Vector2.from_angle(deg_to_rad(171.0))
	p.spread = 81.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 120.0
	p.gravity = Vector2(0, 100)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 5.0
	p.color_ramp = _fade_ramp()
	add_child(p)
	_grind = p


func _burst(tex: Texture2D, pos: Vector2, count: int, life: float, dir: Vector2, spread: float,
		v_min: float, v_max: float, s_min: float, s_max: float, radius: float, gravity: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.texture = tex
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = gravity
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.color_ramp = _fade_ramp()
	_transient.add_child(p)
	p.position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


func _pickup_smash(pos: Vector2) -> void:
	var smash := Sprite2D.new()
	smash.texture = ExSkateAssets.GREEN_SMASH
	smash.position = pos
	smash.scale = Vector2(0.2, 0.2)
	_transient.add_child(smash)
	var tween := smash.create_tween()
	tween.tween_property(smash, "scale", Vector2(1.2, 1.2), 0.25)
	tween.tween_property(smash, "modulate:a", 0.0, 0.6)
	tween.tween_callback(smash.queue_free)


func _floating_text(text: String, pos: Vector2, color: Color) -> void:
	var holder := Node2D.new()
	holder.position = pos
	var label := ExSkateUI.make_label(text, 48, color)
	holder.add_child(label)
	_transient.add_child(holder)
	label.reset_size()
	label.position = -label.size / 2.0
	var rise := randf_range(100.0, 120.0)
	var tween := holder.create_tween()
	tween.tween_property(holder, "position:y", pos.y - rise, 1.0)
	tween.tween_property(holder, "modulate:a", 0.0, 0.5)
	tween.tween_callback(holder.queue_free)


static func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	return g
