extends CharacterBody3D

const SPEED = 5.0
const JUMP_VEL = 4.5
const MOUSE_SENS = 0.002
const INTERACT_RANGE = 3.0

var camera: Camera3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _zap_sound: AudioStreamPlayer

func _ready():
	_setup_input()

	var col = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col.shape = capsule
	add_child(col)

	camera = Camera3D.new()
	camera.position.y = 0.65
	camera.current = true
	add_child(camera)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_zap_sound = AudioStreamPlayer.new()
	_zap_sound.stream = preload("res://scenes/rubens_coin_pusher/zap_c_02.wav")
	_zap_sound.volume_db = -5.0
	add_child(_zap_sound)

func _setup_input():
	var keys = {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev = InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_handle_interact()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VEL

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if dir:
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_update_interact_prompt()

func _is_aiming_at_coin_slot() -> bool:
	var coin_slot = get_tree().root.find_child("CoinSlot", true, false)
	if not coin_slot:
		return false
	var dist = camera.global_position.distance_to(coin_slot.global_position)
	if dist > INTERACT_RANGE:
		return false
	var cam_forward = -camera.global_basis.z
	var to_slot = (coin_slot.global_position - camera.global_position).normalized()
	return cam_forward.dot(to_slot) > 0.95

func _update_interact_prompt():
	if not GameManager.interact_prompt:
		return
	if _is_aiming_at_coin_slot():
		GameManager.interact_prompt.text = "E to insert $1"
		GameManager.interact_prompt.visible = true
	else:
		GameManager.interact_prompt.visible = false

func _handle_interact():
	if _is_aiming_at_coin_slot():
		GameManager.try_insert_dollar()
		return

	if not GameManager.coin_spawn_point:
		return
	if not GameManager.try_shoot_coin():
		return
	_zap_sound.play()
	var spawn = GameManager.coin_spawn_point
	var anim = spawn.get_node_or_null("Gun/AnimationPlayer")
	if anim:
		anim.play("fire")
	var pos = spawn.global_position
	pos += Vector3(randf_range(-0.02, 0.02), 0, 0)
	var dir = -spawn.global_transform.basis.z
	var impulse = dir * 0.015 + Vector3(randf_range(-0.004, 0.004), 0, 0)
	GameManager.spawn_coin(pos, impulse)
