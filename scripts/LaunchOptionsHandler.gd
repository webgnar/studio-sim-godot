extends Node

## Parse and handle command-line launch options
## Available options:
##   --debug-input         Enable detailed input logging
##   --debug-overlay       Show debug overlay on startup
##   --calibrate-controller Auto-calibrate controller axes
##   --force-steam-deck    Force Steam Deck controller mode

var debug_input: bool = false
var debug_overlay: bool = false
var force_steam_deck_mode: bool = false
var calibrate_controller: bool = false

func _ready():
	parse_launch_options()
	apply_launch_options()

func parse_launch_options():
	"""Parse command-line arguments"""
	var args = OS.get_cmdline_args()

	print("[LaunchOptions] Parsing %d command-line arguments" % args.size())
	if DebugLogger:
		DebugLogger.write_log("[LaunchOptions] Parsing command-line args: %s" % str(args))

	for arg in args:
		var arg_lower = arg.to_lower()

		match arg_lower:
			"--debug-input":
				debug_input = true
				print("[LaunchOptions] Input debugging enabled")
			"--debug-overlay":
				debug_overlay = true
				print("[LaunchOptions] Debug overlay enabled")
			"--force-steam-deck":
				force_steam_deck_mode = true
				print("[LaunchOptions] Forcing Steam Deck mode")
			"--calibrate-controller":
				calibrate_controller = true
				print("[LaunchOptions] Controller calibration requested")
			_:
				# Ignore unknown args (Godot passes some automatically)
				pass

func apply_launch_options():
	"""Apply the parsed launch options"""
	# Wait a bit for other systems to initialize
	await get_tree().create_timer(0.5).timeout

	# Apply debug overlay option
	if debug_overlay and has_node("/root/ControllerDebugOverlay"):
		var overlay = get_node("/root/ControllerDebugOverlay")
		overlay.visible = true
		overlay.visible_in_export = true
		print("[LaunchOptions] Debug overlay activated")

	# Apply force Steam Deck mode
	if force_steam_deck_mode and ControllerMapper:
		ControllerMapper.controller_type = ControllerMapper.ControllerType.STEAM_DECK
		ControllerMapper.is_steam_deck = true
		print("[LaunchOptions] Forced Steam Deck controller mode")
		if DebugLogger:
			DebugLogger.write_log("[LaunchOptions] Forced Steam Deck mode")

	# Apply controller calibration
	if calibrate_controller:
		_run_controller_calibration()

	# Log active options
	if DebugLogger:
		if debug_input:
			DebugLogger.write_log("[LaunchOptions] Debug input enabled")
		if debug_overlay:
			DebugLogger.write_log("[LaunchOptions] Debug overlay enabled")

func _run_controller_calibration():
	"""Run controller auto-calibration"""
	if not ControllerMapper:
		push_error("[LaunchOptions] ControllerMapper not available for calibration")
		return

	var joypads = Input.get_connected_joypads()
	if joypads.is_empty():
		push_error("[LaunchOptions] No controllers connected for calibration")
		print("[LaunchOptions] ERROR: No controllers connected. Connect a controller and try again.")
		return

	print("\n========================================")
	print("CONTROLLER CALIBRATION MODE")
	print("========================================")
	print("Move the RIGHT STICK in circles for 3 seconds...")
	print("Calibration will start in 2 seconds...\n")

	await get_tree().create_timer(2.0).timeout

	# Run calibration on device 0
	await ControllerMapper.auto_calibrate_axes(0)

	print("\n========================================")
	print("CALIBRATION COMPLETE")
	print("========================================\n")

	if DebugLogger:
		DebugLogger.write_log("[LaunchOptions] Controller calibration completed")
