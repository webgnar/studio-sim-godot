class_name CriticMemory

## Each art critic remembers the paintings they've reviewed for this player.
## Stored in the save file (WorldStateManager misc data) under "critic_memory":
## { critic_type: { "count": int, "note": String, "reviews": [ {title, critique}, ... ] } }
## The AI critic gets this as context and writes a private "note to self"
## (its running opinion of the artist) that is saved and sent back next time.
## The template critic uses it for callback lines.

const SAVE_KEY := "critic_memory"
const MAX_REVIEWS := 3 # past reviews kept per critic
const MAX_CRITIQUE_CHARS := 700 # each remembered critique is trimmed to this
const NOTE_MARKER := "NOTE TO SELF:" # must match the gallery server's critique route


## Returns this critic's memory, or an empty dict if they haven't reviewed anything yet.
static func get_memory(critic_type: String) -> Dictionary:
	var all: Dictionary = WorldStateManager.get_data(SAVE_KEY, {})
	var mem = all.get(critic_type, {})
	return mem if typeof(mem) == TYPE_DICTIONARY else {}


static func times_reviewed(critic_type: String) -> int:
	return int(get_memory(critic_type).get("count", 0))


## The most recent painting title this critic reviewed, or "".
static func last_title(critic_type: String) -> String:
	var reviews: Array = get_memory(critic_type).get("reviews", [])
	if reviews.is_empty():
		return ""
	return str(reviews[-1].get("title", ""))


## The memory payload sent with an AI critique request.
static func to_request(critic_type: String) -> Dictionary:
	var mem := get_memory(critic_type)
	return {
		"timesReviewed": int(mem.get("count", 0)),
		"note": str(mem.get("note", "")),
		"pastReviews": mem.get("reviews", []),
	}


## Splits an AI response into [critique, note]. The note is "" if the critic didn't write one.
static func split_note(text: String) -> Array:
	var idx := text.rfind(NOTE_MARKER)
	if idx < 0:
		return [text.strip_edges(), ""]
	var note := text.substr(idx + NOTE_MARKER.length()).strip_edges()
	return [text.left(idx).strip_edges(), note]


## Records a finished review. Pass note = "" to keep the previous note.
## Does not write to disk; the caller saves the world state afterwards.
static func remember(critic_type: String, title: String, critique: String, note: String = "") -> void:
	var all: Dictionary = WorldStateManager.get_data(SAVE_KEY, {}).duplicate(true)
	var mem: Dictionary = get_memory(critic_type).duplicate(true)
	var reviews: Array = mem.get("reviews", [])
	reviews.append({
		"title": title if title.strip_edges() != "" else "Untitled",
		"critique": critique.left(MAX_CRITIQUE_CHARS),
	})
	while reviews.size() > MAX_REVIEWS:
		reviews.remove_at(0)
	mem["reviews"] = reviews
	mem["count"] = int(mem.get("count", 0)) + 1
	if note != "":
		mem["note"] = note
	all[critic_type] = mem
	WorldStateManager.set_data(SAVE_KEY, all)
