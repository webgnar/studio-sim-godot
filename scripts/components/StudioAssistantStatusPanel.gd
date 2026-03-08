extends Node3D

## Status panel for Studio Assistant room
## Shows progress, earnings, and next payout timer
## Renders via SubViewport → ViewportTexture on a QuadMesh

@export var timer_label: Label
@export var progress_bar: ProgressBar
@export var earnings_label: Label

var total_earnings: int = 0

func _ready():
	if not timer_label or not progress_bar or not earnings_label:
		push_error("StudioAssistantStatusPanel: UI node exports not assigned!")
		return

	# Connect to AutomationManager signals
	if has_node("/root/AutomationManager"):
		AutomationManager.assistant_payout.connect(_on_assistant_payout)
		AutomationManager.assistant_progress.connect(_on_assistant_progress)

	_update_display()

func _process(_delta: float):
	# Update display every frame to show live timer
	if has_node("/root/AutomationManager") and AutomationManager.is_assistant_active():
		_update_display()

func _on_assistant_payout(amount: int):
	"""Called when assistant completes a painting"""
	total_earnings += amount
	_update_display()

func _on_assistant_progress(_time_remaining: float, _progress_percent: float):
	"""Called periodically with progress updates"""
	# Display updates in _process instead
	pass

func _update_display():
	"""Update the status panel UI with current info"""
	if not timer_label or not progress_bar or not earnings_label:
		return
	if not has_node("/root/AutomationManager"):
		return

	var status = AutomationManager.get_assistant_status()

	if not status.active:
		timer_label.text = "Awaiting Employment"
		progress_bar.value = 0.0
		earnings_label.text = ""
		return

	var time_remaining = status.time_remaining
	@warning_ignore("integer_division")
	var minutes: int = int(time_remaining) / 60
	@warning_ignore("integer_division")
	var seconds: int = int(time_remaining) % 60

	timer_label.text = "Next painting: %d:%02d" % [minutes, seconds]
	progress_bar.value = status.progress_percent
	earnings_label.text = "Session Earnings: $%d" % total_earnings
