extends CanvasLayer

const HIT_INTENSITY_STEP := 0.2
const MAX_HITS := 21
const MAX_INTENSITY := MAX_HITS * HIT_INTENSITY_STEP
const HIT_DURATION_STEP := 15.0

var _hit_count: int = 0
var _remaining_time: float = 0.0
var _total_duration: float = 0.0
var _intensity: float = 0.0
var _curing: bool = false
var _cure_tween: Tween = null
var _color_rect: ColorRect


func _ready() -> void:
	layer = 99

	_color_rect = ColorRect.new()
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_color_rect)
	_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://shaders/retro_screen.gdshader")
	shader_material.set_shader_parameter("intensity", 0.0)
	_color_rect.material = shader_material


func _process(delta: float) -> void:
	if _curing or _remaining_time <= 0.0:
		return

	_remaining_time -= delta
	if _remaining_time <= 0.0:
		_remaining_time = 0.0
		_hit_count = 0
		_set_intensity(0.0)
		return

	var peak := float(_hit_count) * HIT_INTENSITY_STEP
	var t := _remaining_time / _total_duration
	_set_intensity(peak * t * t)


func apply_hit() -> void:
	if _curing:
		if _cure_tween and _cure_tween.is_valid():
			_cure_tween.kill()
		_curing = false

	_hit_count = mini(_hit_count + 1, MAX_HITS)
	_remaining_time += HIT_DURATION_STEP
	_total_duration = _remaining_time
	_set_intensity(float(_hit_count) * HIT_INTENSITY_STEP)

	if _hit_count >= MAX_HITS and SteamManager:
		SteamManager.unlock_achievement("ACH_FULLY_PIXELATED")


func cure() -> void:
	if _intensity <= 0.0:
		return
	_curing = true
	_remaining_time = 0.0
	_hit_count = 0
	if _cure_tween and _cure_tween.is_valid():
		_cure_tween.kill()
	_cure_tween = create_tween()
	_cure_tween.tween_method(_set_intensity, _intensity, 0.0, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cure_tween.finished.connect(func(): _curing = false)


func _set_intensity(value: float) -> void:
	_intensity = value
	_color_rect.material.set_shader_parameter("intensity", _intensity)
