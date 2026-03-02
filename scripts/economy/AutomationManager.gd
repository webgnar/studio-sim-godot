extends Node

## Automation Manager - Handles all purchasable upgrades and passive income
## Phase 1: Studio Assistant (passive income generator)

# Studio Assistant state
var studio_assistant_active: bool = false
var assistant_timer: float = 0.0

# Studio Assistant constants
const ASSISTANT_COST: int = 2000
const ASSISTANT_INTERVAL: float = 300.0  # 5 minutes in seconds
const ASSISTANT_PAYOUT: int = 100  # $100 per painting

# Audio
@export var payout_sound: AudioStream  # Sound played when assistant completes painting
var audio_player: AudioStreamPlayer = null

# Signals
signal assistant_purchased
signal assistant_payout(amount: int)
signal assistant_progress(time_remaining: float, progress_percent: float)

func _ready():
	print("AutomationManager: Initialized")

	# Create audio player for payout sounds
	if payout_sound:
		audio_player = AudioStreamPlayer.new()
		audio_player.name = "AssistantAudio"
		audio_player.bus = "SFX"
		add_child(audio_player)

func _process(delta: float):
	if studio_assistant_active:
		_tick_assistant(delta)

func _tick_assistant(delta: float):
	"""Tick the assistant timer and generate payouts"""
	assistant_timer += delta

	# Emit progress signal for UI updates
	var time_remaining = ASSISTANT_INTERVAL - assistant_timer
	var progress_percent = (assistant_timer / ASSISTANT_INTERVAL) * 100.0
	assistant_progress.emit(time_remaining, progress_percent)

	# Check if painting is complete
	if assistant_timer >= ASSISTANT_INTERVAL:
		_complete_assistant_painting()
		assistant_timer = 0.0  # Reset timer

func _complete_assistant_painting():
	"""Complete one assistant painting and award money"""
	if not has_node("/root/EconomyManager"):
		push_error("AutomationManager: EconomyManager not found!")
		return

	EconomyManager.add_money(ASSISTANT_PAYOUT, "studio_assistant")
	assistant_payout.emit(ASSISTANT_PAYOUT)
	print("AutomationManager: Studio Assistant completed painting (+$%d)" % ASSISTANT_PAYOUT)

	# Play payout sound
	if payout_sound and audio_player:
		audio_player.stream = payout_sound
		audio_player.play()

func can_purchase_assistant() -> bool:
	"""Check if player can afford studio assistant"""
	if studio_assistant_active:
		return false  # Already purchased

	if not has_node("/root/EconomyManager"):
		return false

	return EconomyManager.get_money() >= ASSISTANT_COST

func purchase_studio_assistant() -> bool:
	"""Purchase the studio assistant upgrade"""
	if not can_purchase_assistant():
		push_warning("AutomationManager: Cannot purchase studio assistant (insufficient funds)")
		return false

	if not has_node("/root/EconomyManager"):
		return false

	# Spend money
	if not EconomyManager.spend_money(ASSISTANT_COST, "studio_assistant_purchase"):
		return false

	# Activate assistant
	studio_assistant_active = true
	assistant_timer = 0.0

	print("AutomationManager: Studio Assistant purchased! Passive income active.")
	assistant_purchased.emit()

	return true

func get_assistant_status() -> Dictionary:
	"""Get current assistant status for UI display"""
	return {
		"active": studio_assistant_active,
		"cost": ASSISTANT_COST,
		"interval": ASSISTANT_INTERVAL,
		"payout": ASSISTANT_PAYOUT,
		"time_remaining": ASSISTANT_INTERVAL - assistant_timer if studio_assistant_active else 0.0,
		"progress_percent": (assistant_timer / ASSISTANT_INTERVAL) * 100.0 if studio_assistant_active else 0.0
	}

func is_assistant_active() -> bool:
	"""Check if studio assistant is active"""
	return studio_assistant_active

# ============================================================================
# Save/Load Support
# ============================================================================

func get_save_data() -> Dictionary:
	"""Get automation state for saving"""
	return {
		"studio_assistant_active": studio_assistant_active,
		"assistant_timer": assistant_timer
	}

func load_save_data(data: Dictionary):
	"""Load automation state from save"""
	studio_assistant_active = data.get("studio_assistant_active", false)
	assistant_timer = data.get("assistant_timer", 0.0)

	if studio_assistant_active:
		print("AutomationManager: Studio Assistant restored (%.1fs until next payout)" % (ASSISTANT_INTERVAL - assistant_timer))

func clear_state():
	"""Reset all automation state (called on new game)"""
	studio_assistant_active = false
	assistant_timer = 0.0
	print("AutomationManager: State cleared")
