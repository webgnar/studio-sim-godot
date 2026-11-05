extends Node2D

## The paint-plotter simulator: watch the machine paint a job.
##
## Shows the canvas, the motor beam above it, both cords and the gondola,
## with paint going down stroke by stroke in machine time (PlotPlayer +
## StrokeRenderer). A speed control runs it from real time (1×) up to
## 100000×, and a panel shows where the job is.
##
## Loads a plotted job (tools/plotter/plot_job.gd output). Command line
## (after --): --plot=path.json  --speed=N  --paused  --quit-when-done
## --snapshot=path.png saves the painted canvas on exit.
## Keys: space play/pause, up/down speed ×2, R restart, S save the canvas
## to user://plotter_canvas.png.
## Run it with tools/plotter/run_simulator.sh, which uses a bare project so
## none of the game's autoloads start.

const DEFAULT_PLOT := "res://job/plotted.json"

var machine := Polargraph.new()
var player := PlotPlayer.new()
var renderer: StrokeRenderer
var speed := 1000.0
var playing := true
var quit_when_done := false
var job := {}

var _camera: Camera2D
var _paper: Sprite2D
var _stats: Label
var _speed_label: Label
var _slider: HSlider
var _play_button: Button
var _swatch: ColorRect
var _loaded := false
var _sticker_of_layer: Array = []
var _snapshot := ""   ## save the painted canvas here on exit


func _ready() -> void:
	var path := DEFAULT_PLOT
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plot="):
			path = a.trim_prefix("--plot=")
		elif a.begins_with("--speed="):
			speed = float(a.trim_prefix("--speed="))
		elif a == "--paused":
			playing = false
		elif a == "--quit-when-done":
			quit_when_done = true
		elif a.begins_with("--snapshot="):
			_snapshot = a.trim_prefix("--snapshot=")
	RenderingServer.set_default_clear_color(Color(0.16, 0.16, 0.17))
	_camera = Camera2D.new()
	add_child(_camera)
	_build_ui()
	get_viewport().size_changed.connect(_frame_camera)
	_stats.text = "Loading %s ..." % path
	_load.call_deferred(path)


func _load(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		_stats.text = "Couldn't read %s" % path
		return
	job = JSON.parse_string(text)
	var canvas := Vector2(job.canvas_mm[0], job.canvas_mm[1])
	machine = Polargraph.new(2440.0, 450.0, canvas)
	var layers: Array = []
	for L in job.layers:
		var lines: Array = []
		for flat in L.lines:
			var pts := PackedVector2Array()
			pts.resize(flat.size() / 2)
			for i in pts.size():
				pts[i] = Vector2(flat[2 * i], flat[2 * i + 1])
			lines.append(pts)
		layers.append({"stamp": int(L.stamp), "color": Color.html(L.color), "lines": lines})
		_sticker_of_layer.append(str(L.get("sticker", "?")))
	job.layers = []   # the player has its own copy; free the JSON
	player.setup(layers, Vector2(canvas.x * 0.5, 0.0))
	renderer = StrokeRenderer.new(canvas, 2.0, float(job.get("marker_mm", 2.0)))
	add_child(renderer)
	_paper = Sprite2D.new()
	_paper.centered = false
	_paper.texture = renderer.get_texture()
	_paper.scale = Vector2.ONE / renderer.px_per_mm
	_paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# The paint texture's alpha isn't meaningful (it's never cleared): show it opaque
	var opaque := ShaderMaterial.new()
	opaque.shader = Shader.new()
	opaque.shader.code = "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0); }"
	_paper.material = opaque
	add_child(_paper)
	move_child(_rig, -1)   # cords and gondola stay on top
	_frame_camera()
	_loaded = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _loaded:
		return
	if playing and not player.done() and renderer.is_ready():
		renderer.paint(player.advance_to(player.time + delta * speed))
		queue_redraw()
	elif quit_when_done and player.done():
		get_tree().quit()
	_update_stats()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_toggle_play()
			KEY_UP:
				_set_speed(speed * 2.0)
			KEY_DOWN:
				_set_speed(speed * 0.5)
			KEY_R:
				player.rewind()
				renderer.clear()
			KEY_S:
				save_canvas("user://plotter_canvas.png")


func _exit_tree() -> void:
	if _snapshot != "" and _loaded:
		save_canvas(_snapshot)


## Saves the painted canvas as a PNG (canvas only, at the renderer's resolution).
func save_canvas(path: String) -> void:
	var img := renderer.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(path)
	print("canvas saved to ", ProjectSettings.globalize_path(path))


# --- Drawing the machine -----------------------------------------------------------

func _draw() -> void:
	if not _loaded:
		return
	var canvas := machine.canvas_size
	var m1 := machine.left_motor()
	var m2 := machine.right_motor()
	# Canvas board with a soft shadow
	draw_rect(Rect2(Vector2(12, 12), canvas), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2(-6, -6), canvas + Vector2(12, 12)), Color(0.55, 0.5, 0.42))
	# Beam and motors
	draw_line(m1 + Vector2(-60, 0), m2 + Vector2(60, 0), Color(0.75, 0.75, 0.78), 18.0)
	for m in [m1, m2]:
		draw_rect(Rect2(m - Vector2(42, 42), Vector2(84, 84)), Color(0.2, 0.2, 0.22))
		draw_circle(m, 14.0, Color(0.85, 0.85, 0.85))


# The cords and gondola move every frame: drawn by a child on top of the paper
var _rig: Node2D


func _enter_tree() -> void:
	_rig = Node2D.new()
	_rig.z_index = 1
	_rig.draw.connect(_draw_rig)
	add_child(_rig)


func _draw_rig() -> void:
	if not _loaded:
		return
	var p := player.position
	var cord := Color(0.95, 0.95, 0.9, 0.9)
	_rig.draw_line(machine.left_motor(), p, cord, 2.5, true)
	_rig.draw_line(machine.right_motor(), p, cord, 2.5, true)
	var colour := player.layer_color(player.current_layer)
	_rig.draw_circle(p, 34.0, Color(0.12, 0.12, 0.13))
	_rig.draw_circle(p, 26.0, Color(0.85, 0.85, 0.86))
	# The marker: its paint colour, solid when touching the canvas
	_rig.draw_circle(p, 12.0, colour if player.pen_down else colour.lerp(Color.WHITE, 0.6))
	if player.pen_down:
		_rig.draw_arc(p, 40.0, 0.0, TAU, 32, colour, 4.0, true)


func _frame_camera() -> void:
	var lo := machine.left_motor() + Vector2(-120, -120)
	var hi := Vector2(machine.right_motor().x + 120, machine.canvas_size.y + 80)
	var view := Vector2(get_viewport().get_visible_rect().size)
	var panel_w := 330.0
	var usable := view - Vector2(panel_w, 0)
	var z := minf(usable.x / (hi.x - lo.x), usable.y / (hi.y - lo.y))
	_camera.zoom = Vector2(z, z)
	_camera.position = (lo + hi) * 0.5 - Vector2(panel_w * 0.5 / z, 0)


# --- Panel ------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(300, 0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Paint plotter"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(28, 28)
	row.add_child(_swatch)
	var hint := Label.new()
	hint.text = "  current paint"
	row.add_child(hint)
	_stats = Label.new()
	_stats.custom_minimum_size = Vector2(290, 0)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_stats)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	_play_button = Button.new()
	_play_button.custom_minimum_size = Vector2(80, 0)
	_play_button.pressed.connect(_toggle_play)
	controls.add_child(_play_button)
	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(func(): player.rewind(); renderer.clear())
	controls.add_child(restart)
	_speed_label = Label.new()
	box.add_child(_speed_label)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 5.0
	_slider.step = 0.01
	_slider.custom_minimum_size = Vector2(290, 0)
	_slider.value_changed.connect(func(v): _set_speed(pow(10.0, v), false))
	box.add_child(_slider)
	var keys := Label.new()
	keys.text = "Space play/pause · ↑↓ speed · R restart"
	keys.modulate = Color(1, 1, 1, 0.6)
	box.add_child(keys)
	_set_speed(speed)


func _toggle_play() -> void:
	playing = not playing


func _set_speed(v: float, move_slider := true) -> void:
	speed = clampf(v, 1.0, 100000.0)
	if move_slider and _slider:
		_slider.set_value_no_signal(log(speed) / log(10.0))


func _update_stats() -> void:
	_play_button.text = "Pause" if playing else "Play"
	_speed_label.text = "Speed: %s× (1× = real time)" % _num(speed)
	_rig.queue_redraw()
	if not _loaded:
		return
	var li := player.current_layer
	_swatch.color = player.layer_color(li)
	var stamp := player.layer_stamp(li)
	var t := player.time
	var total := player.total_time
	var left := (total - t) / speed if playing and speed > 0 else 0.0
	_stats.text = "\n".join([
		str(job.get("style", "")),
		"",
		"Machine time  %s / %s  (%.1f%%)" % [_dur(t), _dur(total), 100.0 * t / maxf(total, 1e-9)],
		"At this speed, done in %s" % _dur(left) if playing else "Paused",
		"Sticker  %d / %d  (sticker %s)" % [stamp + 1, int(job.get("stamp_count", 0)), _sticker_of_layer[li] if li >= 0 else "-"],
		"Paint layer  %d / %d" % [li + 1, player.layer_count],
		"Colour changes  %s" % _num(player.colour_changes),
		"Pen lifts + drops  %s" % _num(player.pen_changes),
		"Ink laid  %.2f km" % (player.draw_length / 1e6),
		"Pen  %s" % ("down" if player.pen_down else "up"),
	])


static func _dur(s: float) -> String:
	var t := int(s)
	if t >= 86400:
		return "%dd %02dh %02dm" % [t / 86400, (t % 86400) / 3600, (t % 3600) / 60]
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	return "%dm %02ds" % [t / 60, t % 60]


static func _num(v: float) -> String:
	var s := str(int(round(v)))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
