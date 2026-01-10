extends Control
class_name AssistantPayoutNotification

## Toast notification that appears when Studio Assistant completes a painting
## Shows "+$X from Studio Assistant" message with fade animation

@onready var label: Label = $Panel/MarginContainer/Label

const DISPLAY_DURATION = 2.5  # How long to show before fading
const FADE_DURATION = 0.4     # How long the fade-out takes

func _ready():
	# Start hidden
	modulate.a = 0
	visible = false

	# Make sure mouse clicks pass through
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect to AutomationManager signal
	if has_node("/root/AutomationManager"):
		AutomationManager.assistant_payout.connect(_on_assistant_payout)

func _on_assistant_payout(amount: int):
	"""Show notification when assistant completes a painting"""
	show_notification(amount)

func show_notification(amount: int):
	"""Shows the payout notification with fade-in/fade-out animation"""
	if label:
		label.text = "Studio Assistant: +$%d" % amount

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
