extends Node3D

var wheel_body: AnimatableBody3D
var rotation_speed: float = 2

var bonus_queue: int = 0
var dispense_left: bool = true
var dispensing: bool = false

var left_dispenser: Node3D
var right_dispenser: Node3D
var top_lights: Array[Light3D] = []
var _jingle_sound: AudioStreamPlayer

var _shader_mesh: MeshInstance3D
var _shader_show_id: int = 0

func _ready():
	wheel_body = $WheelBody
	get_parent().get_node("BonusZone").body_entered.connect(_on_bonus)
	left_dispenser = get_parent().get_node("LeftDispenser")
	right_dispenser = get_parent().get_node("RightDispenser")
	for light_name in ["TopLight1", "TopLight2"]:
		var light = get_parent().get_node_or_null(light_name)
		if light:
			top_lights.append(light)
	_jingle_sound = AudioStreamPlayer.new()
	_jingle_sound.stream = preload("res://scenes/rubens_coin_pusher/happy-jingle.wav")
	_jingle_sound.volume_db = -5.0
	add_child(_jingle_sound)

	_shader_mesh = get_parent().get_node_or_null("Shader")
	if _shader_mesh:
		_shader_mesh.visible = false

func _physics_process(delta):
	wheel_body.rotation.z += rotation_speed * delta

func _on_bonus(body: Node3D):
	if body.is_in_group("coins"):
		bonus_queue += 10
		if not dispensing:
			dispensing = true
			_dispense_next()
		_flash_lights_green()
		_jingle_sound.play()
		_show_shader_briefly(3.0)

func _show_shader_briefly(duration: float):
	if not _shader_mesh:
		return
	_shader_mesh.visible = true
	_shader_show_id += 1
	var my_id := _shader_show_id
	get_tree().create_timer(duration).timeout.connect(func():
		if _shader_show_id == my_id:
			_shader_mesh.visible = false
	)

var _flash_tween: Tween

func _flash_lights_green():
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_set_lights_color(Color.GREEN)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_lerp_lights, 0.0, 1.0, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _lerp_lights(t: float):
	var color = Color.GREEN.lerp(Color.WHITE, t)
	_set_lights_color(color)

func _set_lights_color(color: Color):
	for light in top_lights:
		light.light_color = color

func _dispense_next():
	if bonus_queue <= 0:
		dispensing = false
		return
	bonus_queue -= 1
	dispense_left = !dispense_left

	var dispenser = left_dispenser if dispense_left else right_dispenser
	var pos = dispenser.global_position
	var forward = -dispenser.global_basis.z
	var power = randf_range(0.004, 0.009)
	var impulse = forward * power + Vector3(
		randf_range(-0.001, 0.001),
		randf_range(-0.001, 0.001),
		0
	)
	GameManager.spawn_coin(pos, impulse, PI / 2)

	get_tree().create_timer(0.18).timeout.connect(_dispense_next)
