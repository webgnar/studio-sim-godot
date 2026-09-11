extends InteractionComponent
class_name HOFDoorInteraction

## Makes the HOF door interactable — but only once HOFDoor reports it's unlocked
## (i.e. a basket has been made). Pressing interact while unlocked swings it open.

const LOCKED_TEXT: String = "Locked — Sink a Basket to Unlock"
const OPEN_TEXT: String = "Open"

@export var hof_door: HOFDoor

## No outline (see "no_outline" group on the HOF door node) and no HUD prompt —
## still interactable via the interact key, just without telegraphing itself.
var hide_prompt: bool = true

func _on_ready() -> void:
	if not hof_door:
		hof_door = _find_hof_door()
	if hof_door:
		hof_door.unlocked.connect(_update_state)
	_update_state()

func _find_hof_door() -> HOFDoor:
	var current: Node = get_parent()
	var depth := 0
	while current and depth < 10:
		if current is HOFDoor:
			return current
		current = current.get_parent()
		depth += 1
	return null

func _update_state() -> void:
	if not hof_door:
		is_disabled = true
		interaction_text = LOCKED_TEXT
		return
	if hof_door.is_open():
		is_disabled = true
		interaction_text = OPEN_TEXT
	elif hof_door.is_unlocked():
		is_disabled = false
		interaction_text = OPEN_TEXT
	else:
		is_disabled = true
		interaction_text = LOCKED_TEXT

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	if not hof_door:
		return
	hof_door.open_door()
	_update_state()
