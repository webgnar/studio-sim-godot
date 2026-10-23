extends RefCounted
class_name AutoplayPainter

## How the idle autoplay bot composes a painting. This is the file to tune.
##
## The bot asks for one stroke at a time with next_stroke(). A stroke says
## which sticker to use, where it ends up (canvas UV, 0..1 from the top-left),
## its rotation and size, and the path the sticker ghost takes across the
## canvas before it's placed. AutoplayBot then drags the ghost along that path
## in view of the player and places it, exactly like a player would.
##
## v1 strategy: random, but with a little hesitation so it reads as someone
## deciding. Swap in smarter strategies here (composition rules, colour
## balance, clustering, reacting to what's already on the canvas) without
## touching the bot's movement code.

const STROKES_MIN := 12
const STROKES_MAX := 30
const EDGE_MARGIN := 0.08            ## keep sticker centres this far from the canvas edges (UV)
const SCALE_MIN := 0.5
const SCALE_MAX := 1.6

const CONSIDER_POINTS_MIN := 1       ## "hmm, maybe here" stops before settling
const CONSIDER_POINTS_MAX := 3
const CONSIDER_SPREAD := 0.18        ## how far from the final spot those stops wander (UV)
const DRAG_SPEED := 0.45             ## canvas widths per second while moving the ghost
const DRAG_TIME_MIN := 0.25
const HOVER_MIN := 0.15              ## pause at each considering stop
const HOVER_MAX := 0.5
const SETTLE_MIN := 0.3              ## pause on the final spot before placing
const SETTLE_MAX := 0.8
const PAUSE_AFTER_MIN := 0.3         ## step back and look after placing
const PAUSE_AFTER_MAX := 1.0


func stroke_count() -> int:
	return randi_range(STROKES_MIN, STROKES_MAX)


## Plan the next sticker. `system` is the canvas being painted, so a strategy
## can look at what's already there (system.placed_layers).
func next_stroke(system: PaintingSystem2D, _stroke_index: int) -> Dictionary:
	var final_uv := Vector2(
		randf_range(EDGE_MARGIN, 1.0 - EDGE_MARGIN),
		randf_range(EDGE_MARGIN, 1.0 - EDGE_MARGIN))

	# A few "considering" stops near the final spot, each closer than the last
	var waypoints: Array[Vector2] = []
	var stops := randi_range(CONSIDER_POINTS_MIN, CONSIDER_POINTS_MAX)
	for i in stops:
		var spread := CONSIDER_SPREAD * float(stops - i) / float(stops)
		var p := final_uv + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		waypoints.append(p.clamp(Vector2(EDGE_MARGIN, EDGE_MARGIN), Vector2(1.0 - EDGE_MARGIN, 1.0 - EDGE_MARGIN)))
	waypoints.append(final_uv)

	return {
		"sticker_index": randi() % StickerLibrary.sticker_library.size(),
		"waypoints": waypoints,
		"rotation_deg": randf_range(0.0, 360.0),
		"scale": randf_range(SCALE_MIN, SCALE_MAX),
	}


## Seconds to drag the ghost between two canvas points.
func drag_time(from_uv: Vector2, to_uv: Vector2) -> float:
	return maxf(from_uv.distance_to(to_uv) / DRAG_SPEED, DRAG_TIME_MIN)


func hover_time() -> float:
	return randf_range(HOVER_MIN, HOVER_MAX)


func settle_time() -> float:
	return randf_range(SETTLE_MIN, SETTLE_MAX)


func pause_after_time() -> float:
	return randf_range(PAUSE_AFTER_MIN, PAUSE_AFTER_MAX)
