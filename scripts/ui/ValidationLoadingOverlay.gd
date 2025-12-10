extends CanvasLayer

## Loading overlay shown during painting validation to prevent perceived freeze

@onready var title_label = $ColorRect/CenterContainer/VBoxContainer/TitleLabel
@onready var step_label = $ColorRect/CenterContainer/VBoxContainer/StepLabel

func _ready():
	visible = false
	layer = 101  # Above gameplay UI, just above debug overlay

func show_loading():
	"""Show the loading overlay"""
	visible = true
	title_label.text = "ANALYZING PAINTING..."
	step_label.text = "Preparing..."

func update_step(step: int, total: int, description: String):
	"""Update the progress step message"""
	step_label.text = "Step %d/%d: %s" % [step, total, description]

func hide_loading():
	"""Hide the loading overlay"""
	visible = false
