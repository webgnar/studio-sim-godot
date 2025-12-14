extends Control
class_name SaveNotification

## Simple notification popup that appears and fades out
## Shows "GAME SAVED" message when save is successful

@onready var panel: PanelContainer = $Panel
@onready var sprite: TextureRect = $Panel/MarginContainer/Sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const DISPLAY_DURATION = 2.0  # How long to show before fading
const FADE_DURATION = 0.5      # How long the fade-out takes

func _ready():
	# Start hidden
	modulate.a = 0
	visible = false

	# Make sure mouse clicks pass through
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_notification():
	"""Shows the save notification with fade-in/fade-out animation"""
	visible = true

	# Fade in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)

	# Wait for display duration
	await get_tree().create_timer(DISPLAY_DURATION).timeout

	# Fade out
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.finished.connect(func(): visible = false)
