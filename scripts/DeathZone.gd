extends Area3D

@export var spawn_position: Vector3 = Vector3(-0.947, 1.207, 12.446)
@export var watch_duration: float = 1.5

var _is_respawning: bool = false
var _death_camera: Camera3D
var _target_player: CharacterBody3D
var _death_sound: AudioStream = preload("res://sounds/die.ogg")

func _ready():
	body_entered.connect(_on_body_entered)
	set_process(false)
	set_collision_mask_value(3, true)  # Also detect CarryablePainting layer
	set_collision_mask_value(8, true)  # Also detect basketball layer

func _process(_delta):
	if _death_camera and _target_player:
		_death_camera.look_at(_target_player.global_position)

func _on_body_entered(body):
	if body.is_in_group("player") and not _is_respawning:
		_respawn(body)
	elif body.is_in_group("respawnable"):
		body.respawn()
	elif body is CarryablePainting:
		_spawn_fire_effect(body.global_position)
		body.queue_free()

func _respawn(player):
	_is_respawning = true
	_target_player = player

	# Unlock death achievement
	if SteamManager:
		SteamManager.unlock_achievement("ACH_DIE")

	# Play death sound
	var sfx = AudioStreamPlayer.new()
	sfx.stream = _death_sound
	sfx.bus = "SFX"
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	# Disable player input (gravity still applies)
	CameraManager.set_player_input(false)

	# Play fall animation during the watch window
	if player.has_method("play_death_animation"):
		player.play_death_animation()

	# Create a temp camera at the player's current eye position
	_death_camera = Camera3D.new()
	_death_camera.fov = CameraManager.player_camera.fov
	get_tree().root.add_child(_death_camera)
	_death_camera.global_transform = CameraManager.player_camera.global_transform
	_death_camera.make_current()

	# Start tracking the falling player
	set_process(true)

	# Watch them fall
	await get_tree().create_timer(watch_duration).timeout

	# Fade to black
	await SceneTransition.fade_out(0.5)

	# Stop tracking
	set_process(false)

	# Teleport player and reset velocity
	player.velocity = Vector3.ZERO
	player.global_position = spawn_position

	# Reset animation while screen is black so player appears in idle on fade-in
	if player.has_method("reset_animation"):
		player.reset_animation()

	# Restore player camera
	_death_camera.queue_free()
	_death_camera = null
	_target_player = null
	CameraManager.player_camera.make_current()

	# Brief pause while black
	await get_tree().create_timer(0.3).timeout

	# Fade back in
	await SceneTransition.fade_in(0.5)

	# Re-enable input
	CameraManager.set_player_input(true)
	_is_respawning = false

var _flame_texture: Texture2D = preload("res://sprites/flame.png")

func _spawn_fire_effect(pos: Vector3) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 80.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 10.0
	mat.angular_velocity_min = -30.0
	mat.angular_velocity_max = 30.0
	mat.gravity = Vector3(0, 1, 0)
	mat.scale_min = 4.0
	mat.scale_max = 10.0
	mat.color = Color(1.0, 0.5, 0.1, 0.9)

	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_texture = _flame_texture
	draw_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	draw_mat.disable_receive_shadows = true
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.particles_anim_h_frames = 1
	draw_mat.particles_anim_v_frames = 1
	draw_mat.particles_anim_loop = false

	var mesh := QuadMesh.new()
	mesh.material = draw_mat
	mesh.size = Vector2(2, 2)

	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 40
	particles.lifetime = 3.0
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.process_material = mat
	particles.draw_pass_1 = mesh
	particles.global_position = pos

	get_tree().root.add_child(particles)
	get_tree().create_timer(particles.lifetime + 1.0).timeout.connect(particles.queue_free)
