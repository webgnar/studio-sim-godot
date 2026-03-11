extends CanvasLayer

## Lightweight FPS monitor overlay — toggle with F3

var _label: Label
var _timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1

func _ready() -> void:
	layer = 127  # Just below ControllerDebugOverlay (128)

	var panel = PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)

	visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_F3 and event.pressed and not event.echo:
			visible = not visible

func _process(delta: float) -> void:
	if not visible:
		return

	_timer += delta
	if _timer < UPDATE_INTERVAL:
		return
	_timer = 0.0

	var fps = Engine.get_frames_per_second()
	var ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000
	_label.text = "FPS: %d  (%.1fms)" % [fps, ms]
