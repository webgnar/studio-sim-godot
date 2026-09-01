extends CanvasLayer

## "Now playing" toast for the boombox/radio. Same slide-in/slide-out toast
## pattern as AchievementToast, but with an animated shader background
## (shaders/music_toast_bg.gdshader) instead of the flat ui_theme panel —
## so this stays a separate, purpose-built popup rather than another
## AchievementToast.show_toast() call sharing the achievement look.

const UI_THEME: Theme = preload("res://themes/ui_theme.tres")
const BG_SHADER: Shader = preload("res://shaders/music_toast_bg.gdshader")

enum _State { IDLE, SLIDING_IN, HOLDING, SLIDING_OUT }

var _panel: PanelContainer
var _bg: ColorRect
var _title_label: Label
var _track_label: Label
var _state: _State = _State.IDLE
var _current_tween: Tween
var _hold_timer: Timer

const SLIDE_DURATION := 0.5
const DISPLAY_DURATION := 4.0
const EDGE_MARGIN := 16.0
const MIN_SIZE := Vector2(380, 130)

func _ready() -> void:
	layer = 90
	_build_ui()
	_panel.visible = false

	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = DISPLAY_DURATION
	_hold_timer.timeout.connect(_slide_out)
	add_child(_hold_timer)

## Shows/refreshes the "NOW PLAYING" toast for track_label. If one is already
## visible (or mid-exit), the newest call always takes precedence immediately:
## content refreshes in place and the display timer resets, rather than
## queuing behind whatever came before (tracks can cycle quickly).
func show_toast(track_label: String) -> void:
	_track_label.text = track_label
	_panel.reset_size()  # grows past MIN_SIZE if the track name needs more room
	# Keep the panel pinned to the top-left regardless of how its size changed.
	_panel.position.y = EDGE_MARGIN

	match _state:
		_State.IDLE:
			_slide_in()
		_State.SLIDING_IN, _State.HOLDING:
			# Already visible — snap the (possibly resized) panel back to its
			# left-aligned resting spot and restart the hold timer.
			_panel.position.x = _resting_x()
			_hold_timer.start()
		_State.SLIDING_OUT:
			_slide_in()  # reverse course back into view with the new content

func _resting_x() -> float:
	return EDGE_MARGIN

func _slide_in() -> void:
	# Only jump to the off-screen starting position when coming from a fully
	# hidden state. A SLIDING_OUT reversal should continue smoothly from
	# wherever it currently is, not snap back off-screen first.
	var was_idle := _state == _State.IDLE
	_state = _State.SLIDING_IN
	if _current_tween:
		_current_tween.kill()
	_panel.visible = true

	if was_idle:
		_panel.position.x = -_panel.size.x - 10

	_current_tween = create_tween()
	_current_tween.tween_property(_panel, "position:x", _resting_x(), SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.finished.connect(func():
		_state = _State.HOLDING
		_hold_timer.start()
	)

func _slide_out() -> void:
	_state = _State.SLIDING_OUT
	if _current_tween:
		_current_tween.kill()

	var offscreen_x: float = -_panel.size.x - 10
	_current_tween = create_tween()
	_current_tween.tween_property(_panel, "position:x", offscreen_x, SLIDE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_current_tween.finished.connect(func():
		_panel.visible = false
		_state = _State.IDLE
	)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Border-only stylebox (transparent fill — the shader ColorRect below is
	# the actual background). PanelContainer draws this behind its children
	# and auto-insets them by the border width, so the shader fill ends up
	# flush inside the border ring instead of covering it. Matches the
	# amber-on-dark border already used elsewhere (themes/ui_theme.tres,
	# StyleBoxFlat_panel) for visual consistency.
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.border_width_left = 3
	border.border_width_top = 3
	border.border_width_right = 3
	border.border_width_bottom = 3
	border.border_color = Color(0.701188, 0.43148756, 0.07110313, 1)
	_panel.add_theme_stylebox_override("panel", border)
	# Floor the panel at a fixed rectangular size so a short track name still
	# reads as a solid card — reset_size() in show_toast() only grows it
	# past this if a longer track name actually needs more room.
	_panel.custom_minimum_size = MIN_SIZE

	# PanelContainer fits every direct child to its content rect (inset by the
	# border above), so this ColorRect (behind) and the margin/labels (in
	# front) simply overlay — the shader always exactly fills the area inside
	# the border ring.
	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = BG_SHADER
	_bg.material = bg_mat
	_panel.add_child(_bg)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)

	_title_label = Label.new()
	_title_label.text = "NOW PLAYING"
	_title_label.add_theme_font_override("font", UI_THEME.default_font)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	_track_label = Label.new()
	_track_label.add_theme_font_override("font", UI_THEME.default_font)
	_track_label.add_theme_font_size_override("font_size", 40)
	_track_label.add_theme_color_override("font_color", Color.WHITE)
	_track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_track_label)

	margin.add_child(vbox)
	_panel.add_child(margin)
	add_child(_panel)

	_panel.reset_size()
	_panel.position = Vector2(-_panel.size.x - 10, EDGE_MARGIN)
