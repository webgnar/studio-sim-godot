extends CanvasLayer

## Loading screen shown when entering the world from the title screen.
## Every chunk of data the scene is made of (each texture, model, material,
## sound...) gets slapped onto a black background as a sticker the moment it is
## loaded on the background thread. The same file always gets the same sticker,
## bigger files get bigger stickers, and files from the same folder land near
## each other. Once the scene is in the tree it stays up through a
## shader warm-up sweep and until frame times settle, so the player never sees
## the world's first-second hitches.
## Usage: LoadingScreen.begin_preload(path) as early as possible (optional),
##        then await LoadingScreen.load_scene(path)

signal finished

const MIN_DISPLAY_TIME: float = 1.5      ## Seconds, so a fast load still reads as a loading screen
const FADE_IN_TIME: float = 0.35
const FADE_OUT_TIME: float = 0.5
const CHUNK_INTERVAL: float = 0.05       ## Pace for placing loaded chunks when only a few are waiting
const IDLE_STICKER_AFTER: float = 0.5    ## Nothing loading (warm-up, settle): place a random sticker this often
const MAX_STICKERS: int = 400            ## Oldest stickers get peeled off past this
const MAX_CHUNKS: int = 3000             ## Cap on how many dependencies get tracked
const STICKER_SIZE_MIN: float = 90.0     ## Longest side in px at 1080p, for the smallest files
const STICKER_SIZE_MAX: float = 340.0    ## ...and for the biggest
const CLUSTER_SPREAD: float = 200.0      ## How far a folder's stickers scatter from its spot
const TEXT_CLEARANCE: float = 40.0       ## Stickers keep this far from the LOADING text
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

# Some sticker PNGs have a faint near-transparent border that reads as a thin
# box on black, so drop pixels under 10% alpha
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
var _art_material: ShaderMaterial
var _sounds: Array[AudioStream] = []
var _textures: Array[Texture2D] = []
var _scan_task: int = -1
var _watch: Array = []          ## Chunks not loaded yet: {path, size, folder}
var _watch_cursor: int = 0
var _chunk_queue: Array = []    ## Loaded chunks waiting for their sticker
var _folder_spots: Dictionary = {}
var _chunk_timer: float = 0.0
var _idle_timer: float = 0.0
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
	_label.text = "LOADING..."
	# Dots appear one by one without the word sliding around
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.add_theme_font_override("font", load("res://fonts/studio-sim.ttf"))
	_label.add_theme_font_size_override("font_size", 120)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# A few players so overlapping slaps don't cut each other off
	for i in range(4):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = -8.0
		add_child(player)
		_sound_players.append(player)

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
	"""Start loading a scene on background threads. Safe to call more than once.
	Also starts tracking its chunks, so ones that finish before the screen shows
	still get their sticker."""
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(scene_path, "", true)
	if _scan_task == -1 and _watch.is_empty() and _chunk_queue.is_empty():
		_scan_task = WorkerThreadPool.add_task(_scan_chunks.bind(scene_path), false, "LoadingScreen chunk scan")
		set_process(true)

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
	_collect_loaded_chunks(true)

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

	# Every loaded chunk gets its sticker before the reveal
	while not _chunk_queue.is_empty() or Time.get_ticks_msec() - started_at < MIN_DISPLAY_TIME * 1000.0:
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

# --- Data chunks ---

func _scan_chunks(scene_path: String) -> void:
	"""Worker thread: list every file the scene depends on, recursively"""
	var found: Array = []
	var seen = {scene_path: true}
	var pending: Array[String] = [scene_path]
	while not pending.is_empty() and found.size() < MAX_CHUNKS:
		var path = pending.pop_back()
		for dependency in ResourceLoader.get_dependencies(path):
			var dep_path = _dependency_path(dependency)
			if dep_path == "" or seen.has(dep_path):
				continue
			seen[dep_path] = true
			found.append({"path": dep_path, "size": _data_size(dep_path), "folder": dep_path.get_base_dir()})
			pending.append(dep_path)
	_watch = found

func _dependency_path(dependency: String) -> String:
	"""Dependencies come back as 'uid::type::path' (or just 'path')"""
	for part in dependency.split("::"):
		if part.begins_with("res://"):
			return part
	if dependency.begins_with("uid://"):
		var id = ResourceUID.text_to_id(dependency.get_slice("::", 0))
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return ""

func _data_size(path: String) -> int:
	"""Bytes on disk, following the import remap in exported builds"""
	if FileAccess.file_exists(path):
		return FileAccess.get_size(path)
	var import_file = ConfigFile.new()
	if import_file.load(path + ".import") == OK:
		var imported = str(import_file.get_value("remap", "path", ""))
		if imported != "" and FileAccess.file_exists(imported):
			return FileAccess.get_size(imported)
	return 50000

func _collect_loaded_chunks(take_all: bool = false) -> void:
	"""Move chunks that are now in memory to the sticker queue. Checks a slice
	of the list each frame; take_all flushes it once the scene has loaded."""
	if _scan_task != -1:
		if not WorkerThreadPool.is_task_completed(_scan_task):
			return
		WorkerThreadPool.wait_for_task_completion(_scan_task)
		_scan_task = -1
	if _watch.is_empty():
		return
	if take_all:
		_chunk_queue.append_array(_watch)
		_watch.clear()
		return
	var checks = mini(64, _watch.size())
	for i in range(checks):
		_watch_cursor = _watch_cursor % _watch.size()
		var chunk = _watch[_watch_cursor]
		if ResourceLoader.has_cached(chunk.path):
			_chunk_queue.append(chunk)
			_watch.remove_at(_watch_cursor)
			if _watch.is_empty():
				return
		else:
			_watch_cursor += 1

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
	_folder_spots.clear()
	_chunk_timer = 0.0
	_idle_timer = 0.0
	visible = true
	set_process(true)

func _stop_animation() -> void:
	set_process(false)
	visible = false
	_watch.clear()
	_chunk_queue.clear()
	for child in _sticker_layer.get_children():
		child.queue_free()

func _process(delta: float) -> void:
	_collect_loaded_chunks()
	if not visible:
		return  # Tracking chunks before the screen shows; they're placed once it does

	# One sticker per loaded chunk. A big backlog (chunks that finished while the
	# title camera was still moving) goes down in a quick decaying burst.
	_chunk_timer -= delta
	var backlog = _chunk_queue.size()
	var to_place = 0
	if backlog >= 15:
		to_place = ceili(backlog / 15.0)
	elif backlog > 0 and _chunk_timer <= 0.0:
		to_place = 1
		_chunk_timer = CHUNK_INTERVAL
	for i in range(to_place):
		_place_chunk_sticker(_chunk_queue.pop_front())

	# Warm-up and settling don't load files; keep the screen alive meanwhile
	_idle_timer = 0.0 if to_place > 0 else _idle_timer + delta
	if _idle_timer >= IDLE_STICKER_AFTER:
		_idle_timer = 0.0
		_place_random_sticker()

	_dots_timer += delta
	_label.visible_characters = 7 + int(_dots_timer * 3.0) % 4

	var screen = _root.size
	_progress_bar.position = Vector2(0, screen.y - 6)
	_progress_bar.size = Vector2(screen.x * _progress, 6)

func _set_progress(value: float) -> void:
	_progress = maxf(_progress, clampf(value, 0.0, 1.0))

func _text_rect() -> Rect2:
	"""Screen area the LOADING text covers, including the dots"""
	var font = _label.get_theme_font("font")
	var font_size = _label.get_theme_font_size("font_size")
	var text_size = font.get_string_size("LOADING...", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Rect2(_root.size * 0.5 - text_size * 0.5, text_size)

func _clear_of_text(spot: Vector2, radius: float) -> bool:
	"""Whether a sticker's bounding circle stays off the text"""
	var keep_out = _text_rect().grow(TEXT_CLEARANCE)
	return spot.distance_to(spot.clamp(keep_out.position, keep_out.end)) > radius

func _random_spot(center: Vector2, spread: float, radius: float) -> Variant:
	"""A sticker center near center (anywhere on screen if spread is 0) that
	stays off the text, or null"""
	var screen = _root.size
	for attempt in range(20):
		var spot: Vector2
		if spread > 0.0:
			spot = center + Vector2.from_angle(randf() * TAU) * spread * sqrt(randf())
			spot = spot.clamp(Vector2.ZERO, screen)
		else:
			spot = Vector2(randf_range(0.0, screen.x), randf_range(0.0, screen.y))
		if _clear_of_text(spot, radius):
			return spot
	return null

func _new_folder_spot(ui_scale: float) -> Vector2:
	"""Center for a new folder's cluster: on screen, off the text, and as far
	from the other folders as a handful of tries can find"""
	var inset = _root.size * 0.12
	var best = _root.size * 0.5
	var best_gap = -1.0
	for attempt in range(16):
		var spot = Vector2(randf_range(inset.x, _root.size.x - inset.x), randf_range(inset.y, _root.size.y - inset.y))
		if not _clear_of_text(spot, CLUSTER_SPREAD * ui_scale * 0.5):
			continue
		var gap = INF
		for other in _folder_spots.values():
			gap = minf(gap, spot.distance_to(other))
		if gap > best_gap:
			best = spot
			best_gap = gap
	return best

func _place_chunk_sticker(chunk: Dictionary) -> void:
	"""Sticker for one loaded file: picked by its path, sized by its bytes,
	placed around its folder's spot"""
	if _textures.is_empty():
		return
	var ui_scale = _root.size.y / 1080.0
	# ~1 KB files get the smallest stickers, ~10 MB the biggest
	var weight = clampf((log(maxf(chunk.size, 1.0)) / log(10.0) - 3.0) / 4.0, 0.0, 1.0)
	var target = lerpf(STICKER_SIZE_MIN, STICKER_SIZE_MAX, weight) * ui_scale

	if not _folder_spots.has(chunk.folder):
		_folder_spots[chunk.folder] = _new_folder_spot(ui_scale)
	var spot = _random_spot(_folder_spots[chunk.folder], CLUSTER_SPREAD * ui_scale, target * 0.5)
	if spot == null:
		return
	var texture: Texture2D = _textures[absi(hash(chunk.path)) % _textures.size()]
	_slap_sticker(texture, spot, target)

func _place_random_sticker() -> void:
	if _textures.is_empty():
		return
	var ui_scale = _root.size.y / 1080.0
	var target = randf_range(STICKER_SIZE_MIN, STICKER_SIZE_MAX) * ui_scale
	var spot = _random_spot(Vector2.ZERO, 0.0, target * 0.5)
	if spot != null:
		_slap_sticker(_textures.pick_random(), spot, target)

func _slap_sticker(texture: Texture2D, spot: Vector2, target: float) -> void:
	"""Place texture centered on spot with its longest side target px"""
	var tex_size = texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return
	var final_scale = target / maxf(tex_size.x, tex_size.y)

	var sticker = Node2D.new()
	sticker.position = spot
	sticker.rotation = deg_to_rad(randf_range(-30.0, 30.0))

	var art = Sprite2D.new()
	art.texture = texture
	art.material = _art_material
	art.flip_h = randf() < 0.5
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
