extends Node3D

## Status panel for Studio Assistant room.
## Renders via SubViewport → ViewportTexture on a QuadMesh.

@export var progress_bar: Control

func _ready():
	if not progress_bar:
		push_error("StudioAssistantStatusPanel: progress_bar export not assigned!")
		return

	if has_node("/root/AutomationManager"):
		AutomationManager.assistant_payout.connect(_on_assistant_payout)

	_update_display()

func _process(_delta: float):
	if has_node("/root/AutomationManager") and AutomationManager.is_assistant_active():
		_update_display()

func _on_assistant_payout(_amount: int):
	_update_display()

func _update_display():
	if not progress_bar or not has_node("/root/AutomationManager"):
		return

	var status = AutomationManager.get_assistant_status()
	progress_bar.value = status.progress_percent if status.active else 0.0
