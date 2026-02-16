extends Control
class_name ValidationResultUI

## Thin wrapper around MissionResultsDisplay for the post-submission validation screen
## Handles keyboard shortcuts and UIManager integration

@onready var dialog: PanelContainer = $Dialog
@onready var results_display: MissionResultsDisplay = $Dialog/MarginContainer/MissionResultsDisplay

func _ready():
	dialog.visible = false

	if UIManager:
		UIManager.register_screen("validation", self)

	results_display.retry_pressed.connect(_on_retry_mission)
	results_display.back_pressed.connect(_on_back_to_missions)

func _input(event):
	if not dialog.visible:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_on_retry_mission(results_display.current_mission)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("go_back"):
		_on_back_to_missions()
		get_viewport().set_input_as_handled()
		return

func show_screen():
	dialog.visible = true

func hide_screen():
	dialog.visible = false

func show_results(result: ValidationResult, mission: PaintingMission):
	var painting_system = PaintingModeManager.painting_system_2d
	results_display.show_live_results(result, mission, painting_system)
	dialog.visible = true

func _on_retry_mission(mission: PaintingMission = null):
	var target_mission = mission if mission else results_display.current_mission
	if not target_mission:
		push_error("ValidationResultUI: No mission to retry!")
		return

	var painting_system = PaintingModeManager.painting_system_2d
	if not painting_system:
		push_error("ValidationResultUI: No painting system found!")
		return

	painting_system.start_mission(target_mission)
	MissionManager.start_mission(target_mission)

func _on_back_to_missions():
	MissionManager.current_mission = null

	if UIManager:
		UIManager.change_state(UIManager.GameState.PAUSE_MENU)
