extends CanvasLayer

## On-screen voice level meter - shows automatically whenever MicRecorder is
## recording (regardless of what triggered it: Studio Assistant, debug overlay,
## etc.) so the player can visually confirm they're being picked up.
##
## Mirrored scrolling amplitude graph, like a voice-chat mic visualizer -
## one loudness value per frame, fast attack / slow release so speech feels
## alive, rendered as mirrored columns around a center line with a soft glow.

const HISTORY_SIZE := 200
const COLUMN_WIDTH := 3.0
const GRAPH_HEIGHT := 90.0
const BOTTOM_MARGIN := 140.0
const ATTACK := 0.5    # fast rise toward louder input
const RELEASE := 0.08  # slower decay back toward quiet
const GLOW_WIDTH := COLUMN_WIDTH + 3.0
const GLOW_COLOR := Color(0.4, 1.0, 0.85, 0.25)
const LINE_COLOR := Color(0.55, 1.0, 0.9, 1.0)
const CENTER_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.18)

var _graph: Control
var _history: PackedFloat32Array
var _display_volume: float = 0.0

func _ready() -> void:
	layer = 129
	visible = false

	_history = PackedFloat32Array()
	_history.resize(HISTORY_SIZE)
	_history.fill(0.0)

	_graph = Control.new()
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.custom_minimum_size = Vector2(HISTORY_SIZE * COLUMN_WIDTH, GRAPH_HEIGHT)
	_graph.size = _graph.custom_minimum_size
	_graph.draw.connect(_on_graph_draw)
	add_child(_graph)

func _process(_delta: float) -> void:
	var recording: bool = MicRecorder.is_recording
	visible = recording
	if not recording:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	_graph.position = Vector2(
		viewport_size.x / 2.0 - _graph.size.x / 2.0,
		viewport_size.y - BOTTOM_MARGIN
	)

	var target := MicRecorder.get_current_level()
	var rate := ATTACK if target > _display_volume else RELEASE
	_display_volume = lerpf(_display_volume, target, rate)

	_history.remove_at(0)
	_history.append(_display_volume)
	_graph.queue_redraw()

func _on_graph_draw() -> void:
	var w: float = _graph.size.x
	var h: float = _graph.size.y
	var center_y := h / 2.0

	_graph.draw_line(Vector2(0, center_y), Vector2(w, center_y), CENTER_LINE_COLOR, 1.0)

	for i in range(_history.size()):
		var level: float = _history[i]
		if level <= 0.01:
			continue
		var x := i * COLUMN_WIDTH
		var half_height: float = maxf(1.5, level * center_y)
		_graph.draw_line(
			Vector2(x, center_y - half_height - 2.0),
			Vector2(x, center_y + half_height + 2.0),
			GLOW_COLOR, GLOW_WIDTH
		)
		_graph.draw_line(
			Vector2(x, center_y - half_height),
			Vector2(x, center_y + half_height),
			LINE_COLOR, COLUMN_WIDTH - 1.0
		)
