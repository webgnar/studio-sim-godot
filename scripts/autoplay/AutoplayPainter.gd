extends RefCounted
class_name AutoplayPainter

## How the idle autoplay bot composes a painting. This is the file to tune.
##
## When the bot steps up to a canvas it calls begin_painting(), which plans
## the whole painting up front as a list of strokes, then asks for them one at
## a time with next_stroke(). A stroke says which sticker to use, where it ends
## up (canvas UV), its rotation and size, and the path the sticker ghost takes
## across the canvas before it's placed. AutoplayBot drags the ghost along that
## path in view of the player and places it, exactly like a player would.
##
## v2 strategy: modelled on the paintings in the Hall of Fame (res://hall_of_fame).
## Those almost never leave bare canvas, build up in layers, repeat a few
## stickers instead of using many, and keep rotations aligned. So a painting is
## planned the same way, back to front:
##   1. Background: one fill sticker tiled big over the whole canvas.
##   2. Structure: a horizon, a split, stripes, a border, panels, or nothing.
##   3. Motif: one sticker repeated in a row, grid, ring, stack or mirrored pairs.
##   4. Focal: one big subject (sometimes a stacked "figure") on a strong spot.
##   5. Accents: a few lines and small shapes near the focal point.
## Each painting also gets a colour scheme (a key colour family that changes
## from painting to painting, plus a second and an accent colour), and stickers
## are picked by how well their own colours fit it, so the colour fields vary.
## About a third of paintings are "meticulous" instead: an even ground and then
## stickers set out in exact grids, rings or mirror symmetry, each one nudged
## into place before it goes down.
## Plans are made in "viewer space" (x right, y down, 0..1 across the canvas as
## the player sees it, rotation 0 = upright) and converted to the canvas's own
## UV and rotation at the end, so they come out upright on any canvas.

## Stroke timing: tiles go down briskly, the bits you look at get mulled over.
const CONSIDER_POINTS_MIN := 1       ## "hmm, maybe here" stops before settling
const CONSIDER_POINTS_MAX := 3
const CONSIDER_SPREAD := 0.18        ## how far from the final spot those stops wander (viewer space)
const DRAG_SPEED := 0.45             ## canvas widths per second while moving the ghost
const DRAG_TIME_MIN := 0.25
const HOVER_MIN := 0.15              ## pause at each considering stop
const HOVER_MAX := 0.5
const SETTLE_MIN := 0.3              ## pause on the final spot before placing
const SETTLE_MAX := 0.8
const QUICK_SETTLE := 0.15           ## same, for background tiles
const PAUSE_AFTER_MIN := 0.3         ## step back and look after placing
const PAUSE_AFTER_MAX := 1.0
const QUICK_PAUSE_AFTER := 0.15
const NUDGES_MIN := 2                ## meticulous strokes: tiny corrections before placing
const NUDGES_MAX := 4
const NUDGE_SPREAD := 0.012          ## viewer space
const PRECISE_SETTLE_MIN := 0.6
const PRECISE_SETTLE_MAX := 1.2

## Where sticker centres may go, in viewer space. A little past the edges is
## fine (and needed to tile to the edge); the canvas's hitbox reaches further.
const BLEED := 0.08
## Tiles are spaced at this fraction of their size, so they overlap and leave no gaps.
## Sparser stickers get packed tighter: spacing = size x (TILE_OVERLAP_SPARSE..TILE_OVERLAP) by coverage.
const TILE_OVERLAP := 0.75
const TILE_OVERLAP_SPARSE := 0.45
## Stickers that cover at least this much of their image can tile into a colour
## field even when ROLES doesn't call them a fill.
const FILL_COVERAGE := 0.45
## Fills covering less than this get a second, offset pass of tiles to close the gaps.
const SECOND_PASS_BELOW := 0.7
## Meticulous grounds use fills, plus shapes at least this dense (so most colours have one).
const GROUND_COVERAGE := 0.55
## Smallest sticker a plan asks for (canvas widths). begin_painting() replaces
## it with what the canvas's minimum scale allows.
const DEFAULT_MIN_SIZE := 0.13

## How often a painting is meticulous rather than layered.
const METICULOUS_CHANCE := 0.35
const METICULOUS := {"catalog": 3, "checker": 2, "rings": 2, "mandala": 3, "gradient": 2}

## Colour families a painting's key colour is drawn from (hue 0..1, -1 = black/white/grey).
## The last few used are skipped, so consecutive paintings change colour.
const FAMILIES := {
	"yellow": 0.13, "orange": 0.07, "red": 0.99, "pink": 0.93, "purple": 0.75,
	"blue": 0.62, "teal": 0.5, "green": 0.3, "neutral": -1.0,
}
const RECENT_FAMILIES := 3
const SCHEMES := {"mono": 2, "analogous": 3, "complement": 3, "neutral_accent": 2}
const HUE_TOLERANCE := 0.06          ## how far a sticker's hue can stray from the target and still fit

## What each built-in sticker is good for, by its id (its file name in
## res://sprites/painting layers/). A sticker can have several roles.
##   fill:    dense, roughly rectangular; tiles into a solid background
##   texture: sparse pattern; laid over a fill as a second layer
##   band:    long and thin; horizons, stripes, borders, rows
##   line:    thin line or arc; accents
##   frame:   outline; panels and borders
##   motif:   compact shape that reads well repeated
##   subject: interesting enough to be the focal point
## Stickers missing here (custom and bought ones) are guessed from their shape.
const ROLES := {
	"1": ["band"], "2": ["texture", "band"], "3": ["line"], "4": ["band"],
	"5": ["motif", "subject"], "6": ["subject"], "7": ["subject"], "8": ["band", "subject"],
	"9": ["subject"], "10": ["line"], "11": ["fill"], "12": ["texture"],
	"13": ["subject"], "14": ["fill"], "15": ["band", "motif"], "18": ["subject"],
	"19": ["texture"], "20": ["fill"], "21": ["subject"], "22": ["subject"],
	"23": ["subject"], "24": ["fill", "band"], "25": ["fill"], "26": ["subject"],
	"27": ["motif", "subject"], "28": ["subject"], "29": ["subject"], "31": ["band", "fill"],
	"32": ["motif", "subject"], "33": ["subject"], "34": ["frame"], "36": ["subject"],
	"37": ["motif", "subject"], "38": ["motif"], "39": ["subject"], "40": ["motif"],
	"41": ["subject"], "42": ["frame"], "43": ["motif", "subject"], "44": ["subject"],
	"45": ["subject"], "47": ["subject"], "48": ["subject"], "50": ["texture", "band"],
	"51": ["subject"], "52": ["band", "subject"], "54": ["fill", "band"], "55": ["band", "line"],
	"56": ["frame"], "57": ["subject", "fill"], "58": ["subject"], "61": ["band"],
	"63": ["line"], "64": ["band", "subject"], "65": ["motif", "subject"], "66": ["subject"],
	"67": ["line"], "68": ["subject"], "69": ["subject"], "70": ["line"],
	"71": ["line"], "72": ["line"],
}

## How often each structure is picked (relative weights).
const STRUCTURES := {"horizon": 4, "split": 1, "stripes": 2, "border": 2, "panels": 1, "none": 2}
## How often each motif arrangement is picked.
const ARRANGEMENTS := {"row": 3, "grid": 2, "ring": 2, "stack": 1, "mirror": 2, "scatter": 1, "none": 1}

var _plan: Array[Dictionary] = []
var _frame: Dictionary = {}
var _aspect := 1.0   ## canvas height / width, as the viewer sees it
var _min_size := DEFAULT_MIN_SIZE
## Hues for this painting: {key, second, accent} (-1 = neutral), and how
## welcome black/white/grey stickers are.
var _scheme: Dictionary = {}
var _recent_families: Array[String] = []
var last_style := ""   ## what the last plan was, for logs and previews
static var _colors: Dictionary = {}   ## sticker id -> colour summary, see _color()


# --- Interface used by AutoplayBot ---

## Plan a painting for `system`, the canvas the bot is standing in front of.
func begin_painting(system: PaintingSystem2D) -> void:
	_frame = _canvas_frame(system)
	_aspect = _frame.height / _frame.width
	_min_size = system.min_scale * system.sticker_scale * system.plane_width / _frame.width
	# Don't bury a painting someone else started: just add to it
	_plan = plan_painting(_aspect, not system.placed_layers.is_empty())


func stroke_count() -> int:
	return _plan.size()


## The i-th planned stroke, converted to the canvas's UV and rotation.
## Returns {sticker_index, waypoints: Array[Vector2] (UV), rotation_deg, scale,
## settle, pause_after}.
func next_stroke(system: PaintingSystem2D, i: int) -> Dictionary:
	var s: Dictionary = _plan[i]
	var waypoints: Array[Vector2] = []
	var stops := randi_range(CONSIDER_POINTS_MIN, CONSIDER_POINTS_MAX) if s.ponder else 0
	for k in stops:
		var spread := CONSIDER_SPREAD * float(stops - k) / float(stops)
		var p: Vector2 = s.pos + Vector2(randf_range(-spread, spread), randf_range(-spread, spread) / _aspect)
		waypoints.append(_to_uv(p.clamp(Vector2.ZERO, Vector2.ONE)))
	if s.precise:
		# Line it up: tiny corrections, each smaller than the last
		var nudges := randi_range(NUDGES_MIN, NUDGES_MAX)
		for k in nudges:
			var spread := NUDGE_SPREAD * float(nudges - k) / float(nudges)
			waypoints.append(_to_uv(s.pos + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))))
	waypoints.append(_to_uv(s.pos))
	var settle := QUICK_SETTLE
	if s.precise:
		settle = randf_range(PRECISE_SETTLE_MIN, PRECISE_SETTLE_MAX)
	elif s.ponder:
		settle = randf_range(SETTLE_MIN, SETTLE_MAX)
	return {
		"sticker_index": s.sticker,
		"waypoints": waypoints,
		"rotation_deg": _frame.rotation_offset + _frame.rotation_sign * s.rot,
		"scale": clampf(s.size * _frame.width / (system.sticker_scale * system.plane_width), system.min_scale, system.max_scale),
		"settle": settle,
		"pause_after": randf_range(PAUSE_AFTER_MIN, PAUSE_AFTER_MAX) if s.ponder or s.precise else QUICK_PAUSE_AFTER,
	}


## Seconds to drag the ghost between two canvas points.
func drag_time(from_uv: Vector2, to_uv: Vector2) -> float:
	return maxf(from_uv.distance_to(to_uv) / DRAG_SPEED, DRAG_TIME_MIN)


func hover_time() -> float:
	return randf_range(HOVER_MIN, HOVER_MAX)


# --- Planning (viewer space) ---

## The whole painting as a list of stamps, back to front. Each stamp is
## {sticker, pos: Vector2 (0..1 across and down), rot (degrees clockwise,
## 0 = upright), size (longest side, as a fraction of canvas width), ponder,
## precise}.
## `add_on` skips the background and structure, for canvases that already
## have something on them. Doesn't touch the scene, so tools can call it
## directly to preview plans.
func plan_painting(aspect: float, add_on: bool = false) -> Array[Dictionary]:
	_aspect = aspect
	_palette.clear()
	_choose_scheme()
	var plan: Array[Dictionary] = []
	var family: String = _recent_families[-1]
	if not add_on and randf() < METICULOUS_CHANCE:
		last_style = "meticulous " + _weighted(METICULOUS)
		_meticulous(plan, last_style.get_slice(" ", 1))
		last_style += ", " + family
		return plan
	last_style = "layered, " + family
	var horizon := -1.0
	if not add_on:
		var fill := _pick("fill", [], "key")
		var fill_rot := _layer_rotation(false)
		_tile(plan, fill, Rect2(0, 0, 1, 1), randf_range(0.7, 1.1), fill_rot)
		if randf() < 0.3:
			_tile(plan, _pick("texture", [], "second"), Rect2(0, 0, 1, 1), randf_range(0.6, 1.0), _layer_rotation())
		horizon = _structure(plan, _weighted(STRUCTURES), fill)
	_motif(plan, _weighted(ARRANGEMENTS), horizon)
	var focus := _focal(plan, horizon)
	_accents(plan, focus)
	return plan


func _structure(plan: Array[Dictionary], kind: String, base_fill: int) -> float:
	"""Lays down the painting's big shapes. Returns the horizon height
	(0..1 down) when there is one, so later layers can sit on it, else -1."""
	match kind:
		"horizon":
			var h := randf_range(0.55, 0.72)
			_tile(plan, _pick("fill", [base_fill], "second"), Rect2(0, h, 1, 1.0 - h), randf_range(0.5, 0.8), _layer_rotation(false))
			if randf() < 0.6:
				_row(plan, _pick("band", [], "accent"), h, randf_range(0.3, 0.5), 0.0)
			return h
		"split":
			var x := randf_range(0.4, 0.6)
			_tile(plan, _pick("fill", [base_fill], "second"), Rect2(x, 0, 1.0 - x, 1), randf_range(0.5, 0.8), _layer_rotation(false))
		"stripes":
			var band := _pick("band", [], "second")
			var angle: float = [0.0, 90.0, randf_range(25.0, 60.0) * (1 if randf() < 0.5 else -1)].pick_random()
			var count := randi_range(4, 7)
			var dir := Vector2.from_angle(deg_to_rad(angle + 90.0))
			for i in count:
				var offset := (float(i) + 0.5) / count - 0.5
				var c := Vector2(0.5, 0.5) + dir * offset * 1.1
				_stamp(plan, band, Vector2(c.x, c.y), angle, randf_range(1.3, 1.6), false)
		"border":
			var band := _pick("band", [], "accent")
			var size := randf_range(0.35, 0.55)
			var inset := 0.05
			_row(plan, band, inset, size, 0.0)
			_row(plan, band, 1.0 - inset, size, 180.0)
			_column(plan, band, inset, size, -90.0)
			_column(plan, band, 1.0 - inset, size, 90.0)
		"panels":
			var a := _pick("fill", [base_fill], "key")
			var b := _pick("fill", [base_fill, a], "second")
			for q in 4:
				var cell := Rect2((q % 2) * 0.5 + 0.03, (q / 2) * 0.5 + 0.03, 0.44, 0.44)
				_tile(plan, a if (q == 0 or q == 3) else b, cell, 0.35, 0.0, 0.02)
	return -1.0


func _motif(plan: Array[Dictionary], kind: String, horizon: float) -> void:
	"""One sticker repeated: the rhythm in most Hall of Fame paintings."""
	if kind == "none":
		return
	var sticker := _pick("motif", [], ["second", "accent"].pick_random())
	var size := randf_range(0.14, 0.26)
	var rot := _upright_rotation()
	match kind:
		"row":
			var y := horizon - size * 0.4 if horizon > 0 else randf_range(0.2, 0.8)
			var n := randi_range(3, 6)
			for i in n:
				_stamp(plan, sticker, Vector2((i + 0.5) / n, y), rot, size, i == 0)
		"grid":
			var n := randi_range(2, 3)
			var m := 0.22
			for gy in n:
				for gx in n:
					var p := Vector2(m + (1.0 - 2 * m) * gx / (n - 1), m + (1.0 - 2 * m) * gy / (n - 1))
					_stamp(plan, sticker, p, rot, size, gx + gy == 0)
		"ring":
			var n := randi_range(5, 8)
			var radius := randf_range(0.28, 0.36)
			var spin := randf() < 0.5   # turn each one to follow the ring
			for i in n:
				var a := TAU * i / n - PI / 2
				var p := Vector2(0.5, 0.5) + Vector2(cos(a), sin(a) * _aspect_fix()) * radius
				_stamp(plan, sticker, p, rad_to_deg(a) + 90.0 if spin else rot, size, i == 0)
		"stack":
			var n := 3
			for i in n:
				_stamp(plan, sticker, Vector2(0.5, (i + 0.5) / n), rot, randf_range(0.4, 0.6), i == 0)
		"mirror":
			var pairs := randi_range(1, 3)
			for i in pairs:
				var p := Vector2(randf_range(0.12, 0.35), randf_range(0.15, 0.85))
				var r := randf_range(-30.0, 30.0)
				_stamp(plan, sticker, p, r, size, true)
				_stamp(plan, sticker, Vector2(1.0 - p.x, p.y), -r, size, false)
		"scatter":
			for i in randi_range(4, 7):
				_stamp(plan, sticker, Vector2(randf_range(0.1, 0.9), randf_range(0.1, 0.9)), randf_range(0.0, 360.0), size * randf_range(0.7, 1.2), i == 0)


func _focal(plan: Array[Dictionary], horizon: float) -> Vector2:
	"""One big subject on a strong spot. Returns where it went."""
	var x: float = [1.0 / 3.0, 0.5, 0.5, 2.0 / 3.0].pick_random()
	var size := randf_range(0.45, 0.7)
	var y := horizon - size * 0.35 if horizon > 0 else randf_range(0.4, 0.6)
	var p := Vector2(x, y)
	if randf() < 0.3:
		# A "figure": a few subjects stacked into one shape
		var parts := randi_range(2, 3)
		var part_size := size * 0.6
		for i in parts:
			var py := y + (i - (parts - 1) / 2.0) * part_size * 0.6
			_stamp(plan, _pick("subject", [], "accent"), Vector2(x + randf_range(-0.03, 0.03), py), randf_range(-12.0, 12.0), part_size, true)
	else:
		_stamp(plan, _pick("subject", [], "accent"), p, randf_range(-10.0, 10.0), size, true)
	return p


func _accents(plan: Array[Dictionary], focus: Vector2) -> void:
	var line := _pick("line", [], "accent")
	for i in randi_range(1, 4):
		var p := focus + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		_stamp(plan, line, p.clamp(Vector2(0.08, 0.08), Vector2(0.92, 0.92)), randf_range(0.0, 360.0), randf_range(0.15, 0.3), i == 0)


func _meticulous(plan: Array[Dictionary], kind: String) -> void:
	"""An even ground, then stickers set out in exact order: same sizes,
	square rotations, equal spacing, placed one by one in reading order."""
	# A calm ground: only the stickers made to be fills, laid square
	_tile(plan, _pick("ground", [], "key"), Rect2(0, 0, 1, 1), randf_range(0.8, 1.1), [0.0, 90.0].pick_random(), 0.0, 0.0)
	match kind:
		"catalog":
			# A specimen chart: a different sticker in every cell, sorted by colour
			var n := randi_range(4, 6)
			var cell := 0.84 / n
			var chosen: Array[int] = []
			for i in n * n:
				chosen.append(_pick(["motif", "subject"].pick_random(), chosen, ["key", "second", "accent"].pick_random()))
			chosen.sort_custom(func(a, b): return _color(a).hue < _color(b).hue)
			for i in chosen.size():
				var p := Vector2(0.08 + cell * (i % n + 0.5), 0.08 + cell * (i / n + 0.5))
				_stamp(plan, chosen[i], p, 0.0, cell * 0.8, false, true)
		"checker":
			# Two stickers alternating on an exact grid
			var a := _pick("motif", [], "second")
			var b := _pick("motif", [a], "accent")
			var n := randi_range(4, 7)
			var cell := 0.9 / n
			for gy in n:
				for gx in n:
					var p := Vector2(0.05 + cell * (gx + 0.5), 0.05 + cell * (gy + 0.5))
					_stamp(plan, a if (gx + gy) % 2 == 0 else b, p, 0.0, cell * 0.85, false, true)
		"rings":
			# Concentric rings, one sticker per ring, each turned to follow it
			var rings := randi_range(2, 3)
			_stamp(plan, _pick("subject", [], "accent"), Vector2(0.5, 0.5), 0.0, 0.2, false, true)
			for r in rings:
				var radius := 0.15 * (r + 1)
				var sticker := _pick("motif", [], ["second", "accent"][r % 2])
				var count := 6 * (r + 1)
				var size := clampf(TAU * radius / count * 1.1, _min_size, 0.2)
				for i in count:
					var a := TAU * i / count - PI / 2
					_stamp(plan, sticker, Vector2(0.5, 0.5) + Vector2(cos(a), sin(a) * _aspect_fix()) * radius, rad_to_deg(a) + 90.0, size, false, true)
		"mandala":
			# Four-fold symmetry: every piece goes down four times, a quarter turn apart
			for e in randi_range(3, 5):
				var sticker := _pick(["motif", "subject", "line"].pick_random(), [], ["second", "accent"].pick_random())
				var offset := Vector2(randf_range(0.06, 0.34), randf_range(0.06, 0.34))
				var rot: float = [0.0, 45.0, 90.0].pick_random()
				var size := randf_range(0.12, 0.22)
				for k in 4:
					var o := offset.rotated(PI / 2 * k)
					_stamp(plan, sticker, Vector2(0.5 + o.x, 0.5 + o.y * _aspect_fix()), rot + 90.0 * k, size, false, true)
			_stamp(plan, _pick("subject", [], "accent"), Vector2(0.5, 0.5), 0.0, randf_range(0.18, 0.28), false, true)
		"gradient":
			# Rows of one sticker growing steadily in size from left to right
			var rows := randi_range(3, 5)
			for r in rows:
				var sticker := _pick("motif", [], ["second", "accent"][r % 2])
				var y := (r + 0.5) / rows
				var count := randi_range(5, 8)
				for i in count:
					var t := float(i) / (count - 1)
					_stamp(plan, sticker, Vector2(0.08 + 0.84 * t, y), 0.0, lerpf(_min_size, 0.9 / rows, t), false, true)


# --- Layout helpers ---

func _tile(plan: Array[Dictionary], sticker: int, area: Rect2, size: float, rot: float, jitter: float = 0.04, rot_jitter: float = 3.0) -> void:
	"""Cover `area` with overlapping copies of one sticker, brick-style."""
	var extent := _extent(sticker, size, rot)
	var overlap := lerpf(TILE_OVERLAP_SPARSE, TILE_OVERLAP, clampf(_color(sticker).coverage / 0.85, 0.0, 1.0))
	var step := Vector2(extent.x * overlap, extent.y * overlap / _aspect)
	var cols := maxi(1, ceili(area.size.x / step.x))
	var rows := maxi(1, ceili(area.size.y / step.y))
	var used := Vector2(cols * step.x, rows * step.y)
	var origin := area.position + (area.size - used) / 2.0 + step / 2.0
	for r in rows:
		var shift := step.x * 0.5 if r % 2 == 1 and cols > 1 else 0.0
		for c in cols + (1 if shift > 0.0 else 0):
			var p := origin + Vector2(c * step.x - shift, r * step.y)
			p += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
			_stamp(plan, sticker, p, rot + randf_range(-rot_jitter, rot_jitter), size, false)
	# Gappy shapes leave holes between tiles: fill them with a second pass
	# offset by half a tile, turned a half turn so it doesn't just repeat
	if _color(sticker).coverage < SECOND_PASS_BELOW:
		for r in rows:
			for c in cols:
				var p := origin + Vector2((c + 0.5) * step.x, (r + 0.5) * step.y)
				p += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
				_stamp(plan, sticker, p, rot + 180.0 + randf_range(-rot_jitter, rot_jitter), size, false)


func _row(plan: Array[Dictionary], sticker: int, y: float, size: float, rot: float) -> void:
	var extent := _extent(sticker, size, rot)
	var n := maxi(2, ceili(1.0 / (extent.x * 0.85)))
	for i in n:
		_stamp(plan, sticker, Vector2((i + 0.5) / n, y), rot, size, false)


func _column(plan: Array[Dictionary], sticker: int, x: float, size: float, rot: float) -> void:
	var extent := _extent(sticker, size, rot)
	var n := maxi(2, ceili(_aspect / (extent.y * 0.85)))
	for i in n:
		_stamp(plan, sticker, Vector2(x, (i + 0.5) / n), rot, size, false)


func _stamp(plan: Array[Dictionary], sticker: int, pos: Vector2, rot: float, size: float, ponder: bool, precise: bool = false) -> void:
	plan.append({
		"sticker": sticker,
		"pos": pos.clamp(Vector2(-BLEED, -BLEED), Vector2(1.0 + BLEED, 1.0 + BLEED)),
		"rot": rot,
		"size": maxf(size, _min_size),
		"ponder": ponder,
		"precise": precise,
	})


func _extent(sticker: int, size: float, rot: float) -> Vector2:
	"""Width and height a sticker covers at `size` (canvas widths), after a
	right-angle-ish rotation."""
	var tex := _texture_size(sticker)
	var e := tex / maxf(tex.x, tex.y) * size
	return Vector2(e.y, e.x) if absf(fposmod(rot, 180.0) - 90.0) < 45.0 else e


func _aspect_fix() -> float:
	return 1.0 / _aspect


func _layer_rotation(allow_diagonal: bool = true) -> float:
	"""One rotation for a whole layer: mostly square to the canvas. Fills stay
	square, since tilted tiles leave gaps at the edges."""
	if allow_diagonal and randf() < 0.15:
		return randf_range(-45.0, 45.0)
	return [0.0, 90.0, 180.0, 270.0].pick_random()


func _upright_rotation() -> float:
	return 0.0 if randf() < 0.7 else randf_range(-20.0, 20.0)


# --- Sticker picking ---

## Stickers are weighted by how well their colours fit the painting's scheme
## (`slot` is "key", "second", "accent" or "any"). Stickers already used in this
## painting get a boost, so it keeps to a small set like the Hall of Fame ones do.
var _palette: Array[int] = []

func _pick(role: String, avoid: Array = [], slot: String = "any") -> int:
	var library := StickerLibrary.sticker_library
	var candidates: Array[int] = []
	for i in library.size():
		if not i in avoid and _has_role(i, role):
			candidates.append(i)
	if candidates.is_empty():
		for i in library.size():
			if not i in avoid:
				candidates.append(i)
	if candidates.is_empty():
		return 0
	var weights: Array[float] = []
	var total := 0.0
	for i in candidates:
		var w := _color_weight(i, slot) * (2.0 if i in _palette else 1.0)
		weights.append(w)
		total += w
	var r := randf() * total
	var pick := candidates[-1]
	for k in candidates.size():
		r -= weights[k]
		if r <= 0.0:
			pick = candidates[k]
			break
	if not pick in _palette:
		_palette.append(pick)
	return pick


func _has_role(sticker: int, role: String) -> bool:
	var roles := _roles(StickerLibrary.sticker_library[sticker])
	if role in roles:
		return true
	if role == "ground":
		return "fill" in roles or (not ("line" in roles or "frame" in roles) and _color(sticker).coverage >= GROUND_COVERAGE)
	# Any dense enough shape can tile into a colour field
	return role == "fill" and not ("line" in roles or "frame" in roles) and _color(sticker).coverage >= FILL_COVERAGE


func _roles(definition: PaintingLayerDefinition) -> Array:
	if ROLES.has(definition.id):
		return ROLES[definition.id]
	# Custom stickers: guess from shape
	var size := definition.texture.get_size() if definition.texture else Vector2.ONE
	var ratio := maxf(size.x, size.y) / maxf(minf(size.x, size.y), 1.0)
	return ["band", "line"] if ratio >= 2.5 else ["subject", "motif"]


func _texture_size(sticker: int) -> Vector2:
	var library := StickerLibrary.sticker_library
	if sticker < 0 or sticker >= library.size() or not library[sticker].texture:
		return Vector2.ONE
	return library[sticker].texture.get_size()


# --- Colour ---

func _choose_scheme() -> void:
	"""Pick this painting's colours: a key family not used in the last few
	paintings, and a second and accent colour that go with it."""
	var families: Array = FAMILIES.keys().filter(func(f): return not f in _recent_families)
	var family: String = families.pick_random()
	_recent_families.append(family)
	if _recent_families.size() > RECENT_FAMILIES:
		_recent_families.pop_front()
	var key: float = FAMILIES[family]
	var any_hue: float = FAMILIES.values().filter(func(h): return h >= 0.0).pick_random()
	if key < 0.0:
		_scheme = {"key": -1.0, "second": -1.0, "accent": any_hue, "neutral": 1.0}
		return
	var side := 1.0 if randf() < 0.5 else -1.0
	match _weighted(SCHEMES):
		"mono":
			_scheme = {"key": key, "second": key, "accent": key, "neutral": 0.15}
		"analogous":
			_scheme = {"key": key, "second": fposmod(key + 0.08 * side, 1.0), "accent": fposmod(key - 0.08 * side, 1.0), "neutral": 0.15}
		"complement":
			_scheme = {"key": key, "second": -1.0, "accent": fposmod(key + 0.5, 1.0), "neutral": 0.6}
		_:
			_scheme = {"key": key, "second": -1.0, "accent": key, "neutral": 0.8}


func _color_weight(sticker: int, slot: String) -> float:
	if slot == "any" or not _scheme.has(slot):
		return 1.0
	var c := _color(sticker)
	var target: float = _scheme[slot]
	if c.hue < 0.0 or c.colorful < 0.25:
		return 1.0 if target < 0.0 else _scheme.neutral
	if target < 0.0:
		return 0.1
	var d := absf(wrapf(c.hue - target, -0.5, 0.5))
	return 0.02 + exp(-pow(d / HUE_TOLERANCE, 2.0)) * 3.0 * c.colorful


func _color(sticker: int) -> Dictionary:
	"""A sticker's colour summary, worked out once from its pixels:
	{hue (0..1, or -1 if it has no clear colour), colorful (share of
	saturated pixels), light (average luminance), coverage (share of the image
	that isn't transparent)}. Works for custom and bought stickers too."""
	var library := StickerLibrary.sticker_library
	if sticker < 0 or sticker >= library.size() or not library[sticker].texture:
		return {"hue": -1.0, "colorful": 0.0, "light": 0.5, "coverage": 0.5}
	var id := library[sticker].id
	if _colors.has(id):
		return _colors[id]
	var img := library[sticker].texture.get_image()
	var summary := {"hue": -1.0, "colorful": 0.0, "light": 0.5, "coverage": 0.5}
	if img:
		if img.is_compressed():
			img.decompress()
		img.resize(32, 32, Image.INTERPOLATE_BILINEAR)
		var solid := 0
		var saturated := 0
		var light := 0.0
		var hue_vec := Vector2.ZERO
		for y in 32:
			for x in 32:
				var px := img.get_pixel(x, y)
				if px.a < 0.5:
					continue
				solid += 1
				light += px.get_luminance()
				if px.s > 0.3 and px.v > 0.25:
					saturated += 1
					hue_vec += Vector2.from_angle(px.h * TAU)
		if solid > 0:
			summary.coverage = solid / 1024.0
			summary.light = light / solid
			summary.colorful = float(saturated) / solid
			if saturated > 0 and hue_vec.length() / saturated > 0.3:
				summary.hue = fposmod(hue_vec.angle() / TAU, 1.0)
	_colors[id] = summary
	return summary


func _weighted(weights: Dictionary) -> String:
	var total := 0.0
	for w in weights.values():
		total += w
	var r := randf() * total
	for key in weights:
		r -= weights[key]
		if r <= 0.0:
			return key
	return weights.keys()[0]


# --- Canvas geometry ---

func _canvas_frame(system: PaintingSystem2D) -> Dictionary:
	"""How the canvas's UV and sticker rotation line up with what the player
	sees: which way is right and down on the canvas, its size as seen, and the
	rotation that makes a sticker upright. Canvases are mounted at all sorts
	of angles, so this works from the plane's transform and the camera."""
	var plane := system.painting_plane
	var basis := plane.global_basis.orthonormalized()
	var ax := basis.x   # canvas u
	var az := basis.z   # canvas v
	var normal := basis.y
	var up := Vector3.UP
	if absf(up.dot(normal)) > 0.9:
		up = -basis.z   # canvas lying flat: treat its far edge as "up"
	up = (up - normal * up.dot(normal)).normalized()
	var cam := plane.get_viewport().get_camera_3d()
	var side := 1.0
	if cam and (cam.global_position - plane.global_position).dot(normal) < 0.0:
		side = -1.0
	var right := (-normal * side).cross(up)
	var down := -up
	var r := Vector2(right.dot(ax), right.dot(az))
	var d := Vector2(down.dot(ax), down.dot(az))
	var sizes := Vector2(system.plane_width, system.plane_height)
	return {
		"right": r,  # viewer right, in canvas (u, v) axes
		"down": d,
		"width": absf(r.x) * sizes.x + absf(r.y) * sizes.y,
		"height": absf(d.x) * sizes.x + absf(d.y) * sizes.y,
		"rotation_offset": rad_to_deg(atan2(-d.x, d.y)),
		"rotation_sign": 1.0 if r.x * d.y - r.y * d.x > 0.0 else -1.0,
		"sizes": sizes,
	}


func _to_uv(p: Vector2) -> Vector2:
	"""Viewer space (0..1 across, 0..1 down) to canvas UV."""
	var offset: Vector2 = _frame.right * (p.x - 0.5) * _frame.width + _frame.down * (p.y - 0.5) * _frame.height
	return Vector2(0.5, 0.5) + offset / _frame.sizes
