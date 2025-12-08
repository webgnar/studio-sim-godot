extends CanvasLayer

## Global scene transition manager with fade effects
## Usage: SceneTransition.fade_to_scene("res://scenes/world.tscn")

signal fade_out_completed
signal fade_in_completed
signal transition_completed

@export var default_fade_out_duration: float = 0.8
@export var default_fade_in_duration: float = 0.5

var is_transitioning: bool = false
var color_rect: ColorRect

func _ready():
	# Set layer to always be on top
	layer = 100

	# Create full-screen ColorRect for fade effect
	color_rect = ColorRect.new()
	color_rect.color = Color(0, 0, 0, 0)  # Start transparent
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Add to tree FIRST before setting anchors
	add_child(color_rect)

	# THEN set anchors and size to cover entire viewport
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.z_index = 100


func fade_out(duration: float = -1.0) -> void:
	"""Fade to black"""
	if duration < 0:
		duration = default_fade_out_duration

	if is_transitioning:
		push_warning("SceneTransition: Already transitioning, ignoring fade_out call")
		return

	is_transitioning = true

	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished

	is_transitioning = false
	fade_out_completed.emit()


func fade_in(duration: float = -1.0) -> void:
	"""Fade from black to transparent"""
	if duration < 0:
		duration = default_fade_in_duration

	if is_transitioning:
		push_warning("SceneTransition: Already transitioning, ignoring fade_in call")
		return

	is_transitioning = true

	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished

	is_transitioning = false
	fade_in_completed.emit()


func fade_to_scene(scene_path: String, fade_out_dur: float = -1.0, fade_in_dur: float = -1.0) -> void:
	"""Complete transition: fade out, change scene, fade in"""
	if is_transitioning:
		push_warning("SceneTransition: Already transitioning, ignoring fade_to_scene call")
		return

	# Use defaults if not specified
	if fade_out_dur < 0:
		fade_out_dur = default_fade_out_duration
	if fade_in_dur < 0:
		fade_in_dur = default_fade_in_duration

	is_transitioning = true

	# Fade out
	var tween_out = create_tween()
	tween_out.tween_property(color_rect, "color:a", 1.0, fade_out_dur)
	await tween_out.finished

	fade_out_completed.emit()

	# Change scene
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneTransition: Failed to load scene: %s (Error code: %d)" % [scene_path, error])
		is_transitioning = false
		return

	# Wait one frame to ensure scene is loaded
	await get_tree().process_frame

	# Fade in
	var tween_in = create_tween()
	tween_in.tween_property(color_rect, "color:a", 0.0, fade_in_dur)
	await tween_in.finished

	fade_in_completed.emit()
	is_transitioning = false
	transition_completed.emit()


func set_fade_visible(visible: bool) -> void:
	"""Manually set fade to fully visible or invisible (no animation)"""
	if visible:
		color_rect.color = Color(0, 0, 0, 1.0)  # Full black
	else:
		color_rect.color = Color(0, 0, 0, 0.0)  # Transparent
