extends CanvasLayer

## Loading screen shown when entering the world from the title screen.
## Random stickers get slapped onto a black background while the scene loads
## on a background thread. Once the scene is in the tree it stays up through a
## shader warm-up sweep and until frame times settle, so the player never sees
## the world's first-second hitches.
## Usage: LoadingScreen.begin_preload(path) as early as possible (optional),
##        then await LoadingScreen.load_scene(path)

signal finished

const MIN_DISPLAY_TIME: float = 1.5      ## Seconds, so a fast load still reads as a loading screen
const FADE_IN_TIME: float = 0.35
const FADE_OUT_TIME: float = 0.5
const STICKER_INTERVAL_MIN: float = 0.08
const STICKER_INTERVAL_MAX: float = 0.22
const MAX_STICKERS: int = 160            ## Oldest stickers get peeled off past this
const STICKER_SIZE_MIN: float = 120.0    ## Longest side in px at 1080p
const STICKER_SIZE_MAX: float = 300.0
const OUTLINE_PX: float = 4.0            ## On-screen die-cut outline width
const SMOOTH_FRAME_MS: float = 25.0      ## A frame under this counts as settled
const SMOOTH_FRAMES_NEEDED: int = 20
const SETTLE_TIMEOUT: float = 5.0  ## Never hold the screen longer than this waiting
const STICKER_SOUNDS := [
	"res://sounds/picotron/sticker1.ogg",
	"res://sounds/picotron/sticker2.ogg",
	"res://sounds/picotron/sticker3.ogg",
	"res://sounds/picotron/sticker4.ogg",
	"res://sounds/picotron/sticker5.ogg",
]

# Die-cut outline: like shaders/sticker_outline.gdshader, but ignores faint pixels
const OUTLINE_SHADER := """
shader_type canvas_item;
uniform float outline_width = 2.5;
float solid(sampler2D tex, vec2 uv) { return step(0.1, texture(tex, uv).a); }
void fragment() {
	vec2 px = outline_width / vec2(textureSize(TEXTURE, 0));
	float n = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			n = max(n, solid(TEXTURE, UV + vec2(float(x), float(y)) * px));
		}
	}
	COLOR = vec4(1.0, 1.0, 1.0, n * (1.0 - solid(TEXTURE, UV)));
}
"""
const ART_SHADER := """
shader_type canvas_item;
void fragment() { COLOR.a *= step(0.1, COLOR.a); }
"""

var is_loading: bool = false

var _root: Control
var _sticker_layer: Node2D
var _progress_bar: ColorRect
var _label: Label
var _sound_players: Array[AudioStreamPlayer] = []
var _next_sound_player: int = 0
var _outline_shader: Shader
var _art_material: ShaderMaterial
var _sounds: Array[AudioStream] = []
var _textures: Array[Texture2D] = []
var _next_sticker_in: float = 0.0
var _progress: float = 0.0
var _dots_timer: float = 0.0

func _ready() -> void:
	layer = 110  # Above SceneTransition (100)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_sticker_layer = Node2D.new()
	_root.add_child(_sticker_layer)

	# Thin progress strip along the bottom edge
	_progress_bar = ColorRect.new()
	_progress_bar.color = Color(1, 1, 1, 0.85)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_progress_bar)

	_label = Label.new()
	_label.text = "LOADING"
	_label.add_theme_font_override("font", load("res://fonts/studio-sim.ttf"))
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_right = -40
	_label.offset_bottom = -28

	# A few players so overlapping slaps don't cut each other off
	for i in range(4):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = -8.0
		add_child(player)
		_sound_players.append(player)

	# Some sticker PNGs have a faint near-transparent border that reads as a thin
	# box on black, so both shaders ignore pixels under 10% alpha
	_outline_shader = Shader.new()
	_outline_shader.code = OUTLINE_SHADER
	var art_shader = Shader.new()
	art_shader.code = ART_SHADER
	_art_material = ShaderMaterial.new()
	_art_material.shader = art_shader
	for path in STICKER_SOUNDS:
		var stream = load(path) as AudioStream
		if stream:
			_sounds.append(stream)

	visible = false
	set_process(false)

func begin_preload(scene_path: String) -> void:
	"""Start loading a scene on background threads. Safe to call more than once."""
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(scene_path, "", true)

func load_scene(scene_path: String) -> void:
	"""Cover the screen, load and switch to scene_path, warm it up, then reveal it."""
	if is_loading:
		return
	is_loading = true
	var started_at = Time.get_ticks_msec()

	# Blocks UIManager's pause/menu input and other SceneTransition users
	SceneTransition.is_transitioning = true
	var input_was_enabled = CameraManager.player_input_enabled
	CameraManager.set_player_input(false)

	_start_animation()
	var fade_in = create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, FADE_IN_TIME)
	await fade_in.finished

	# 1. Background-thread load (0% - 70%)
	begin_preload(scene_path)
	var progress := []
	while true:
		var status = ResourceLoader.load_threaded_get_status(scene_path, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_set_progress(0.7 * float(progress[0]))
			await get_tree().process_frame
			continue
		break
	var scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if scene == null:
		push_error("LoadingScreen: Failed to load scene: %s" % scene_path)
		_finish(input_was_enabled)
		return
	_set_progress(0.7)

	# Let the animation breathe a bit even if the load was instant
	while Time.get_ticks_msec() - started_at < MIN_DISPLAY_TIME * 1000.0 * 0.6:
		await get_tree().process_frame

	# 2. Instantiate and enter the scene (main thread; the screen stays covered)
	var error = get_tree().change_scene_to_packed(scene)
	if error != OK:
		push_error("LoadingScreen: Failed to change scene (Error code: %d)" % error)
		_finish(input_was_enabled)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	# In case the new scene's setup turned input back on, keep it off until revealed
	CameraManager.set_player_input(false)
	_set_progress(0.8)

	# 3. Draw everything around the player once so materials compile now, not mid-play
	await _warm_up_shaders()
	_set_progress(0.9)

	# 4. Hold until the world runs smoothly (first-frame scripts, streaming, etc.)
	await _wait_for_smooth_frames()
	_set_progress(1.0)

	while Time.get_ticks_msec() - started_at < MIN_DISPLAY_TIME * 1000.0:
		await get_tree().process_frame

	_finish(input_was_enabled)

func _finish(input_was_enabled: bool) -> void:
	CameraManager.set_player_input(input_was_enabled)
	SceneTransition.is_transitioning = false
	var fade_out = create_tween()
	fade_out.tween_property(_root, "modulate:a", 0.0, FADE_OUT_TIME)
	await fade_out.finished
	_stop_animation()
	is_loading = false
	finished.emit()

# --- Warm-up ---

func _warm_up_shaders() -> void:
	"""Spin a wide camera around the player's view for a few frames.
	Godot compiles a material's shader the first time it is drawn, which is
	what makes the first look around the studio stutter."""
	var viewport = get_viewport()
	var player_cam = viewport.get_camera_3d()
	var scene = get_tree().current_scene
	if player_cam == null or scene == null:
		return

	var sweep_cam = Camera3D.new()
	sweep_cam.fov = 110.0
	sweep_cam.near = player_cam.near
	sweep_cam.far = player_cam.far
	sweep_cam.cull_mask = player_cam.cull_mask
	sweep_cam.environment = player_cam.environment
	sweep_cam.attributes = player_cam.attributes
	scene.add_child(sweep_cam)
	sweep_cam.global_position = player_cam.global_position
	sweep_cam.make_current()

	var base_yaw = player_cam.global_rotation.y
	for pitch in [0.0, -50.0, 50.0]:
		for step in range(6):
			sweep_cam.global_rotation = Vector3(deg_to_rad(pitch), base_yaw + step * TAU / 6.0, 0.0)
			await RenderingServer.frame_post_draw

	if is_instance_valid(player_cam):
		player_cam.make_current()
	sweep_cam.queue_free()
	await RenderingServer.frame_post_draw

func _wait_for_smooth_frames() -> void:
	var deadline = Time.get_ticks_msec() + SETTLE_TIMEOUT * 1000.0
	var smooth_count = 0
	var last = Time.get_ticks_usec()
	while smooth_count < SMOOTH_FRAMES_NEEDED and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var now = Time.get_ticks_usec()
		var frame_ms = (now - last) / 1000.0
		last = now
		smooth_count = smooth_count + 1 if frame_ms < SMOOTH_FRAME_MS else 0
		_set_progress(0.9 + 0.1 * float(smooth_count) / SMOOTH_FRAMES_NEEDED)

# --- Sticker animation ---

func _start_animation() -> void:
	_textures.clear()
	if StickerLibrary:
		for definition in StickerLibrary.sticker_library:
			if definition.texture:
				_textures.append(definition.texture)
	for child in _sticker_layer.get_children():
		child.queue_free()
	_root.modulate.a = 0.0
	_progress = 0.0
	_set_progress(0.0)
	_next_sticker_in = 0.0
	visible = true
	set_process(true)

func _stop_animation() -> void:
	set_process(false)
	visible = false
	for child in _sticker_layer.get_children():
		child.queue_free()

func _process(delta: float) -> void:
	# Clamp so a long hitch doesn't dump a burst of stickers at once
	_next_sticker_in -= minf(delta, 0.1)
	if _next_sticker_in <= 0.0:
		_place_random_sticker()
		_next_sticker_in = randf_range(STICKER_INTERVAL_MIN, STICKER_INTERVAL_MAX)

	_dots_timer += delta
	_label.text = "LOADING" + ".".repeat(int(_dots_timer * 3.0) % 4)

	var screen = _root.size
	_progress_bar.position = Vector2(0, screen.y - 6)
	_progress_bar.size = Vector2(screen.x * _progress, 6)

func _set_progress(value: float) -> void:
	_progress = maxf(_progress, clampf(value, 0.0, 1.0))

func _place_random_sticker() -> void:
	if _textures.is_empty():
		return
	var texture: Texture2D = _textures.pick_random()
	var tex_size = texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return

	var screen = _root.size
	var ui_scale = screen.y / 1080.0
	var target = randf_range(STICKER_SIZE_MIN, STICKER_SIZE_MAX) * ui_scale
	var final_scale = target / maxf(tex_size.x, tex_size.y)

	var sticker = Node2D.new()
	sticker.position = Vector2(randf_range(0.0, screen.x), randf_range(0.0, screen.y))
	sticker.rotation = deg_to_rad(randf_range(-30.0, 30.0))

	# White die-cut outline behind the art, like a real sticker
	var outline = Sprite2D.new()
	outline.texture = texture
	var outline_mat = ShaderMaterial.new()
	outline_mat.shader = _outline_shader
	outline_mat.set_shader_parameter("outline_width", OUTLINE_PX * ui_scale / final_scale)
	outline.material = outline_mat
	sticker.add_child(outline)

	var art = Sprite2D.new()
	art.texture = texture
	art.material = _art_material
	art.flip_h = randf() < 0.5
	outline.flip_h = art.flip_h
	sticker.add_child(art)

	_sticker_layer.add_child(sticker)
	while _sticker_layer.get_child_count() > MAX_STICKERS:
		var oldest = _sticker_layer.get_child(0)
		_sticker_layer.remove_child(oldest)
		oldest.queue_free()

	# Slap it down: start big and see-through, snap to size
	sticker.scale = Vector2.ONE * final_scale * 1.4
	sticker.modulate.a = 0.0
	var tween = sticker.create_tween().set_parallel(true)
	tween.tween_property(sticker, "scale", Vector2.ONE * final_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sticker, "modulate:a", 1.0, 0.06)

	if not _sounds.is_empty() and (not AudioManager or AudioManager.painting_sounds_enabled):
		var player = _sound_players[_next_sound_player]
		_next_sound_player = (_next_sound_player + 1) % _sound_players.size()
		player.stream = _sounds.pick_random()
		player.pitch_scale = randf_range(0.9, 1.15)
		player.play()
