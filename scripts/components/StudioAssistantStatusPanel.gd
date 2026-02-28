extends Node3D

## Status panel for Studio Assistant room
## Shows progress, earnings, and next payout timer

@export var status_label: Label3D

var total_earnings: int = 0

func _ready():
	if not status_label:
		push_error("StudioAssistantStatusPanel: status_label not assigned!")
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

func _update_display():
	"""Update the status label with current info"""
	if not status_label or not has_node("/root/AutomationManager"):
		return

	var status = AutomationManager.get_assistant_status()

	if not status.active:
		status_label.text = "Studio Assistant\n\nAwaiting Employment"
		return

	var time_remaining = status.time_remaining
	@warning_ignore("integer_division")
	var minutes: int = int(time_remaining) / 60
	@warning_ignore("integer_division")
	var seconds: int = int(time_remaining) % 60

	var progress_bar = _make_progress_bar(status.progress_percent)

	status_label.text = "Studio Assistant\n\n"
	status_label.text += "Next painting: %d:%02d\n" % [minutes, seconds]
	status_label.text += "%s\n\n" % progress_bar
	status_label.text += "Session Earnings: $%d" % total_earnings

func _make_progress_bar(percent: float) -> String:
	"""Create a simple ASCII progress bar"""
	var bar_length = 20
	var filled = int((percent / 100.0) * bar_length)
	var empty = bar_length - filled

	var bar = "["
	for i in range(filled):
		bar += "="
	for i in range(empty):
		bar += " "
	bar += "]"

	return bar + " %.0f%%" % percent
