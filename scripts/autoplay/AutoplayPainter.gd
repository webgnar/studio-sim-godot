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
## Abstractions: often the focal point starts as a quick burst of stickers
## piled into a bunch. Later the bot comes back and carves a form out of that
## texture by carefully painting the background back over everything outside
## the form's edge. The form is usually the silhouette of one of the
## painting's own stickers, traced from its transparency.
## Mistakes: now and then a stroke goes wrong (the hand slips, or the bot
## glances away and the ghost drifts) or an
## impulsive, unplanned sticker goes down. The bot notices, looks at it, and
## then deals with it like a person would: undoes it, paints over it, repeats
## it so it looks deliberate, or builds around it. Some get left alone.
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

## Mistakes, per stroke the bot is paying attention to (not background tiles).
## Meticulous paintings get fewer and fix them more carefully.
const MISTAKE_CHANCE := 0.08
const MISTAKE_CHANCE_METICULOUS := 0.04
const IMPULSE_CHANCE := 0.06         ## per considered stroke: slap down something unplanned
const IMPULSE_CHANCE_METICULOUS := 0.02
const MISTAKES := {"slip": 3, "distracted": 2}
## What to do about a mistake once it's noticed. undo and cover redo the
## intended stroke afterwards; echo and build_around keep the mistake and make
## it part of the painting.
const FIXES := {"undo": 2, "cover": 3, "echo": 2, "build_around": 2, "leave": 1}
const FIXES_METICULOUS := {"undo": 5, "cover": 2, "echo": 2, "build_around": 1}
const STARE_MIN := 0.6               ## seconds looking at a mistake before fixing it
const STARE_MAX := 1.8
const LOOK_AWAY_MIN := 1.0           ## a distraction: seconds looking off the canvas
const LOOK_AWAY_MAX := 2.5

## Abstractions: a burst of stickers carved into a form (layered paintings only).
const ABSTRACTION_CHANCE := 0.5      ## the focal point is an abstraction
const SECOND_ABSTRACTION_CHANCE := 0.3   ## plus a smaller one balancing it
const BURST_MIN := 18
const BURST_MAX := 32
const CARVE_COVERAGE := 0.75        ## a carving sticker must be this solid (holes would show the burst through)
const CARVE_MAX_SIZE := 0.3
const CARVE_MAX_RINGS := 2
const CALM_BUSYNESS := 0.1           ## brightness spread a carving surface can have and still read as calm
const CUTS_MIN := 6                  ## straight cuts a sticker silhouette is simplified to (fewer if it still looks like the sticker)
const CUTS_MAX := 10
## How often the carved form is a sticker's silhouette rather than a plain shape.
const SILHOUETTE_CHANCE := 0.8
const SILHOUETTE_RES := 96.0         ## pixels the silhouette is traced at
const SILHOUETTE_SIMPLIFY := 2.5     ## outline simplification, in those pixels
const SILHOUETTE_SOLIDITY := 0.5     ## outline area / convex hull area, at least
const SILHOUETTE_MAX_POINTS := 60
const SILHOUETTE_COMPACTNESS := 0.25  ## 4*pi*area/perimeter^2: 1 for a circle, low for thin or spiky shapes
const FORMS := {"circle": 3, "square": 2, "triangle": 2, "diamond": 2, "arch": 2}

## The bot's "brain": a mood that wanders stroke by stroke, so its hand and
## its decisions aren't mechanical. focus (0..1) steadies the hand, slows it
## down and makes mistakes rarer; energy (0..1) makes it quicker and more
## impulsive. Both drift a little every stroke and get pulled back toward
## this painting's own baseline, so one painting can be calm and the next
## restless, and the mood shifts within a painting too.
const MOOD_DRIFT := 0.08             ## how far focus and energy can move per stroke
const MOOD_PULL := 0.1               ## how strongly they return to the painting's baseline
const HAND_WOBBLE := 0.025           ## position error at zero focus (canvas widths, gaussian)
const HAND_WOBBLE_PRECISE := 0.35    ## meticulous strokes wobble this fraction as much
const ROT_WOBBLE := 6.0              ## degrees at zero focus
const SIZE_WOBBLE := 0.07            ## size error at zero focus (fraction)
## Nobody paints a row strictly left to right: runs of the same sticker are
## put down in a loosely shuffled order. Higher = more jumbled.
const ORDER_JUMBLE := 2.5
const ORDER_JUMBLE_METICULOUS := 0.8

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
var _meticulous_style := false
var focus := 0.6
var energy := 0.5
var _focus_base := 0.6
var _energy_base := 0.5
var _ground := -1          ## the background sticker, for painting over mistakes
var _ground_rot := 0.0
var last_carve_source := ""   ## id of the sticker whose silhouette was last carved, for previews
static var _colors: Dictionary = {}
static var _silhouettes: Dictionary = {}   ## sticker id -> traced outline, see _silhouette()   ## sticker id -> colour summary, see _color()


# --- Interface used by AutoplayBot ---

## Plan a painting for `system`, the canvas the bot is standing in front of.
func begin_painting(system: PaintingSystem2D) -> void:
	_frame = _canvas_frame(system)
	_aspect = _frame.height / _frame.width
	_min_size = system.min_scale * system.sticker_scale * system.plane_width / _frame.width
	# Don't bury a painting someone else started: just add to it
	plan_painting(_aspect, not system.placed_layers.is_empty())


func stroke_count() -> int:
	return _plan.size()


## The i-th planned stroke, converted to the canvas's UV and rotation.
## Returns {sticker_index, waypoints: Array[Vector2] (UV), rotation_deg, scale,
## settle, pause_after}.
func next_stroke(system: PaintingSystem2D, i: int) -> Dictionary:
	var s := issue(i)
	if s.has("action"):
		return {"undo": true, "stare_uv": _to_uv(s.stare_pos), "stare": s.stare, "pause_after": randf_range(PAUSE_AFTER_MIN, PAUSE_AFTER_MAX)}
	var waypoints: Array[Vector2] = []
	var look_away_at := -1
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
	if s.has("look_away"):
		# Got it lined up, glanced away, and it drifted
		waypoints.append(_to_uv(s.intended_pos))
		look_away_at = waypoints.size() - 1
	waypoints.append(_to_uv(s.pos))
	var settle := QUICK_SETTLE
	if s.precise:
		settle = randf_range(PRECISE_SETTLE_MIN, PRECISE_SETTLE_MAX)
	elif s.ponder:
		settle = randf_range(SETTLE_MIN, SETTLE_MAX)
	var stroke := {
		"sticker_index": s.sticker,
		"waypoints": waypoints,
		"rotation_deg": _frame.rotation_offset + _frame.rotation_sign * s.rot,
		"scale": clampf(s.size * _frame.width / (system.sticker_scale * system.plane_width), system.min_scale, system.max_scale),
		"settle": settle * (0.6 + focus * 0.8) * (1.3 - energy * 0.6),
		"pause_after": (randf_range(PAUSE_AFTER_MIN, PAUSE_AFTER_MAX) if s.ponder or s.precise else QUICK_PAUSE_AFTER) * (1.3 - energy * 0.6),
	}
	if look_away_at >= 0:
		stroke.look_away = s.look_away
		stroke.look_away_at = look_away_at
	if s.has("stare"):
		stroke.stare = s.stare
		stroke.stare_uv = _to_uv(s.stare_pos)
	return stroke


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
	_ground = -1
	last_carve_source = ""
	_focus_base = randf_range(0.35, 0.85)
	_energy_base = randf_range(0.25, 0.8)
	focus = _focus_base
	energy = _energy_base
	var plan: Array[Dictionary] = []
	_plan = plan
	var family: String = _recent_families[-1]
	_meticulous_style = not add_on and randf() < METICULOUS_CHANCE
	if _meticulous_style:
		last_style = "meticulous " + _weighted(METICULOUS)
		_meticulous(plan, last_style.get_slice(" ", 1))
		last_style += ", " + family
		_jumble_order(plan, ORDER_JUMBLE_METICULOUS)
		return plan
	last_style = "layered, " + family
	var horizon := -1.0
	if not add_on:
		var fill := _pick("fill", [], "key")
		var fill_rot := _layer_rotation(false)
		_tile(plan, fill, Rect2(0, 0, 1, 1), randf_range(0.7, 1.1), fill_rot)
		_ground = fill
		_ground_rot = fill_rot
		if randf() < 0.3:
			_tile(plan, _pick("texture", [], "second"), Rect2(0, 0, 1, 1), randf_range(0.6, 1.0), _layer_rotation())
		horizon = _structure(plan, _weighted(STRUCTURES), fill)
	if add_on or randf() >= ABSTRACTION_CHANCE:
		_motif(plan, _weighted(ARRANGEMENTS), horizon)
		_accents(plan, _focal(plan, horizon))
		_jumble_order(plan, ORDER_JUMBLE)
		return plan
	# Abstraction as the focal point: burst now, do other things, come back and carve
	last_style += ", abstraction"
	var spot := _focal_spot(horizon, 0.2)
	var bursts: Array[Dictionary] = [_burst(plan, spot, randf_range(0.24, 0.32))]
	if randf() < SECOND_ABSTRACTION_CHANCE:
		var balance := Vector2(1.0 - spot.x, clampf(1.0 - spot.y + randf_range(-0.1, 0.1), 0.2, 0.8))
		bursts.append(_burst(plan, balance, randf_range(0.14, 0.18)))
	_motif(plan, _weighted(ARRANGEMENTS), horizon)
	for b in bursts:
		_carve(plan, b)
	_accents(plan, spot)
	_jumble_order(plan, ORDER_JUMBLE)
	return plan


func _structure(plan: Array[Dictionary], kind: String, base_fill: int) -> float:
	"""Lays down the painting's big shapes. Returns the horizon height
	(0..1 down) when there is one, so later layers can sit on it, else -1."""
	match kind:
		"horizon":
			var h := randf_range(0.55, 0.72)
			var ground := _pick("fill", [base_fill], "second")
			var ground_rot := _layer_rotation(false)
			_tile(plan, ground, Rect2(0, h, 1, 1.0 - h), randf_range(0.5, 0.8), ground_rot)
			if randf() < 0.6:
				_row(plan, _pick("band", [], "accent"), h, randf_range(0.3, 0.5), 0.0)
			return h
		"split":
			var x := randf_range(0.4, 0.6)
			var side := _pick("fill", [base_fill], "second")
			var side_rot := _layer_rotation(false)
			_tile(plan, side, Rect2(x, 0, 1.0 - x, 1), randf_range(0.5, 0.8), side_rot)
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


func _focal_spot(horizon: float, half_height: float) -> Vector2:
	"""A strong spot for the focal point: the centre or a thirds line,
	sitting on the horizon when there is one."""
	var x: float = [1.0 / 3.0, 0.5, 0.5, 2.0 / 3.0].pick_random()
	var y := horizon - half_height if horizon > 0 else randf_range(0.4, 0.6)
	return Vector2(x, y)


func _focal(plan: Array[Dictionary], horizon: float) -> Vector2:
	"""One big subject on a strong spot. Returns where it went."""
	var size := randf_range(0.45, 0.7)
	var p := _focal_spot(horizon, size * 0.35)
	var x := p.x
	var y := p.y
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
	_ground = _pick("ground", [], "key")
	_ground_rot = [0.0, 90.0].pick_random()
	_tile(plan, _ground, Rect2(0, 0, 1, 1), randf_range(0.8, 1.1), _ground_rot, 0.0, 0.0)
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


# --- The brain: mood, hand and order ---

func _drift_mood() -> void:
	focus = clampf(focus + randf_range(-MOOD_DRIFT, MOOD_DRIFT) + (_focus_base - focus) * MOOD_PULL, 0.0, 1.0)
	energy = clampf(energy + randf_range(-MOOD_DRIFT, MOOD_DRIFT) + (_energy_base - energy) * MOOD_PULL, 0.0, 1.0)


func _wobble(s: Dictionary) -> void:
	"""An imperfect hand: every placement lands a little off what was meant,
	more so when focus is low. Careful strokes wobble less, never zero."""
	var unsteady := (1.15 - focus) * (HAND_WOBBLE_PRECISE if s.get("precise", false) else 1.0)
	s.pos += Vector2(randfn(0.0, 1.0), randfn(0.0, 1.0) * _aspect_fix()) * HAND_WOBBLE * unsteady
	s.rot += randfn(0.0, 1.0) * ROT_WOBBLE * unsteady
	s.size = maxf(s.size * (1.0 + randfn(0.0, 1.0) * SIZE_WOBBLE * unsteady), _min_size)


func _jumble_order(plan: Array[Dictionary], amount: float) -> void:
	"""Loosely shuffle runs of the same sticker (a row, a grid, a tiled
	layer, a burst) so they go down roughly, not strictly, in order."""
	var start := 0
	while start < plan.size():
		var end := start + 1
		while end < plan.size() and plan[end].sticker == plan[start].sticker:
			end += 1
		if end - start >= 3:
			var run := plan.slice(start, end)
			var keyed := []
			for k in run.size():
				keyed.append([k + randfn(0.0, amount), run[k]])
			keyed.sort_custom(func(a, b): return a[0] < b[0])
			for k in keyed.size():
				plan[start + k] = keyed[k][1]
		start = end


# --- Abstractions ---

func _burst(plan: Array[Dictionary], center: Vector2, radius: float) -> Dictionary:
	"""Pile a bunch of stickers into a rough patch, fast and loose, from two
	or three stickers that suit the scheme. Returns what _carve() needs."""
	var stickers: Array[int] = []
	for k in randi_range(2, 3):
		stickers.append(_pick(["texture", "motif", "subject", "line"].pick_random(), stickers, ["second", "accent", "key"][k]))
	var largest := 0.0
	# Enough stickers to pack the patch, whatever its size
	var count := int(randi_range(BURST_MIN, BURST_MAX) * clampf(radius / 0.2, 0.7, 1.6))
	for k in count:
		# Small pieces, so the patch is a texture rather than a few big shapes
		var size := randf_range(_min_size, maxf(_min_size, radius * 0.6))
		largest = maxf(largest, size)
		var offset := Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
		_stamp(plan, stickers.pick_random(), center + Vector2(offset.x, offset.y * _aspect_fix()), randf_range(0.0, 360.0), size, false)
		plan[-1].phase = "burst"
	return {"center": center, "radius": radius, "reach": radius + largest * 0.5}


func _carve(plan: Array[Dictionary], burst: Dictionary) -> void:
	"""Come back to a burst and cut a form out of it: paint the background
	back over everything outside the form's edge, one careful sticker at a
	time, each laid with its straight side along the edge. The form is usually
	the silhouette of a sticker already in the painting, simplified to a
	handful of straight cuts like a paper cut-out, so the carved shapes echo
	the stickers themselves."""
	var center: Vector2 = burst.center
	# Carve with a calm, solid sticker in one of the scheme's colours: the
	# block it leaves round the form is what makes the cut edge read
	var cover := _pick("carve", [], ["key", "second"].pick_random())
	var r: float = burst.radius * randf_range(0.95, 1.1)
	var outline := PackedVector2Array()
	var source := _carve_source(cover) if randf() < SILHOUETTE_CHANCE else -1
	if source >= 0:
		var rot := deg_to_rad(randf_range(-20.0, 20.0)) if randf() < 0.5 else 0.0
		for pt in _facets(_silhouette(source), randi_range(CUTS_MIN, CUTS_MAX)):
			outline.append(pt.rotated(rot) * r)
		if last_carve_source == "":
			last_carve_source = StickerLibrary.sticker_library[source].id
	else:
		outline = _form_outline(_weighted(FORMS), r)
	# Covers in rings: the first, careful ring makes the cut, the outer ones
	# paint over the rest of the burst. Kept small next to the form, so a
	# cover on one side can't reach across and bury the other.
	var tex := _texture_size(cover)
	var size := clampf(r * 0.5, _min_size, CARVE_MAX_SIZE)
	var extent := tex / maxf(tex.x, tex.y) * size
	var along := maxf(extent.x, extent.y)    # long side runs along the edge
	var across := minf(extent.x, extent.y)
	var spin := 90.0 if extent.y > extent.x else 0.0
	var rings := clampi(ceili((burst.reach - r * 0.7) / (across * 0.9)), 1, CARVE_MAX_RINGS)
	# Evenly spaced around the edge, however detailed the outline is
	var edge_points := _resample(outline, along * 0.7)
	var n := edge_points.size()
	for ring in rings:
		for k in n:
			var p: Vector2 = edge_points[k]
			var tangent := (edge_points[(k + 1) % n] - edge_points[(k - 1 + n) % n]).normalized()
			var normal := Vector2(tangent.y, -tangent.x)   # outline runs clockwise on screen
			var c := p + normal * across * (0.5 + 0.9 * ring)
			_stamp(plan, cover, center + Vector2(c.x, c.y * _aspect_fix()), rad_to_deg(tangent.angle()) + spin, size, false, ring == 0)
			plan[-1].phase = "carve"


func _resample(outline: PackedVector2Array, spacing: float) -> PackedVector2Array:
	"""Evenly spaced points around a closed outline."""
	var perimeter := 0.0
	for k in outline.size():
		perimeter += outline[k].distance_to(outline[(k + 1) % outline.size()])
	var count := maxi(3, ceili(perimeter / maxf(spacing, 0.001)))
	var step := perimeter / count
	var out := PackedVector2Array()
	var k := 0
	var walked := 0.0      # distance along the outline at the start of edge k
	for j in count:
		var target := j * step
		while k < outline.size() - 1 and walked + outline[k].distance_to(outline[k + 1]) < target:
			walked += outline[k].distance_to(outline[k + 1])
			k += 1
		var a := outline[k]
		var b := outline[(k + 1) % outline.size()]
		var len := a.distance_to(b)
		out.append(a.lerp(b, clampf((target - walked) / len, 0.0, 1.0)) if len > 0.0 else a)
	return out


func _facets(outline: PackedVector2Array, cuts: int) -> PackedVector2Array:
	"""Simplify an outline to about `cuts` straight edges, keeping its
	character: the points that stray furthest from a simpler outline stay."""
	if outline.size() <= cuts:
		return outline
	var area := _signed_area(outline)
	var eps := 0.02
	var best := outline
	while eps < 1.0:
		var simple := _simplify_closed(outline, eps)
		# Too simple stops looking like the sticker (or folds over itself)
		if simple.size() < 3 or _signed_area(simple) < area * 0.6 or Geometry2D.triangulate_polygon(simple).is_empty():
			break
		best = simple
		if simple.size() <= cuts:
			break
		eps *= 1.3
	return best


func _simplify_closed(outline: PackedVector2Array, eps: float) -> PackedVector2Array:
	# Split at the two points furthest apart and simplify each half
	var far := 0
	for k in outline.size():
		if outline[k].distance_squared_to(outline[0]) > outline[far].distance_squared_to(outline[0]):
			far = k
	var first := outline.slice(0, far + 1)
	var second := outline.slice(far)
	second.append(outline[0])
	var a := _simplify(first, eps)
	var b := _simplify(second, eps)
	a.resize(a.size() - 1)
	b.resize(b.size() - 1)
	a.append_array(b)
	return a


func _simplify(line: PackedVector2Array, eps: float) -> PackedVector2Array:
	"""Ramer-Douglas-Peucker on an open polyline."""
	if line.size() < 3:
		return line
	var worst := 0
	var worst_d := 0.0
	for k in range(1, line.size() - 1):
		var d := absf((line[-1] - line[0]).normalized().cross(line[k] - line[0])) if line[-1] != line[0] else line[k].distance_to(line[0])
		if d > worst_d:
			worst_d = d
			worst = k
	if worst_d <= eps:
		return PackedVector2Array([line[0], line[-1]])
	var left := _simplify(line.slice(0, worst + 1), eps)
	var right := _simplify(line.slice(worst), eps)
	left.resize(left.size() - 1)
	left.append_array(right)
	return left


func _carve_source(cover: int) -> int:
	"""A sticker whose silhouette makes a good form to carve: one already used
	in this painting if possible, a solid single shape, not a line or frame."""
	var candidates: Array[int] = []
	for i in _palette:
		if i != cover and not _silhouette(i).is_empty():
			candidates.append(i)
	if candidates.is_empty():
		for i in StickerLibrary.sticker_library.size():
			if i != cover and _has_role(i, "subject") and not _silhouette(i).is_empty():
				candidates.append(i)
	return candidates.pick_random() if not candidates.is_empty() else -1


func _silhouette(sticker: int) -> PackedVector2Array:
	"""A sticker's outline traced from its transparency, centred, scaled so its
	longest side spans -1..1, clockwise on screen. Empty when the sticker
	isn't one solid shape (scattered pieces, thin lines, outlines), since those
	don't make a readable form. Traced once per sticker."""
	var library := StickerLibrary.sticker_library
	if sticker < 0 or sticker >= library.size() or not library[sticker].texture:
		return PackedVector2Array()
	var id := library[sticker].id
	if _silhouettes.has(id):
		return _silhouettes[id]
	var result := PackedVector2Array()
	var roles := _roles(library[sticker])
	var img := library[sticker].texture.get_image()
	if img and not ("line" in roles or "frame" in roles):
		if img.is_compressed():
			img.decompress()
		var scale := SILHOUETTE_RES / float(maxi(img.get_width(), img.get_height()))
		img.resize(maxi(1, int(img.get_width() * scale)), maxi(1, int(img.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
		var bits := BitMap.new()
		bits.create_from_image_alpha(img, 0.5)
		var polygons := bits.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), SILHOUETTE_SIMPLIFY)
		var best := PackedVector2Array()
		var best_area := 0.0
		var total_area := 0.0
		for poly in polygons:
			var area := absf(_signed_area(poly))
			total_area += area
			if area > best_area:
				best_area = area
				best = poly
		# One dominant piece that fills a fair part of its box
		if best.size() >= 6 and best_area >= total_area * 0.6:
			var box := Rect2(best[0], Vector2.ZERO)
			for pt in best:
				box = box.expand(pt)
			# Mazes and tangles don't read as a form: skip outlines that are mostly
			# notches (area well short of their convex hull) or very busy
			var hull_area := absf(_signed_area(Geometry2D.convex_hull(best)))
			var long_side := maxf(box.size.x, box.size.y)
			var short_side := maxf(minf(box.size.x, box.size.y), 1.0)
			if best_area >= box.get_area() * 0.3 and best_area >= hull_area * SILHOUETTE_SOLIDITY and best.size() <= SILHOUETTE_MAX_POINTS and long_side / short_side <= 2.2:
				var half := maxf(box.size.x, box.size.y) / 2.0
				for pt in best:
					result.append((pt - box.get_center()) / half)
				if _signed_area(result) < 0.0:
					result.reverse()
				# Thin, leggy shapes get buried by carving from both sides
				var perimeter := 0.0
				for k in result.size():
					perimeter += result[k].distance_to(result[(k + 1) % result.size()])
				if 4.0 * PI * absf(_signed_area(result)) / (perimeter * perimeter) < SILHOUETTE_COMPACTNESS:
					result = PackedVector2Array()
	_silhouettes[id] = result
	return result


func _signed_area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


func _form_outline(form: String, r: float) -> PackedVector2Array:
	"""A form's outline around (0, 0), clockwise on screen (y down)."""
	var pts := PackedVector2Array()
	match form:
		"circle":
			for k in 16:
				pts.append(Vector2.from_angle(TAU * k / 16) * r)
		"square":
			pts = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
		"triangle":
			pts = PackedVector2Array([Vector2(0, -r * 1.1), Vector2(r, r * 0.8), Vector2(-r, r * 0.8)])
		"diamond":
			pts = PackedVector2Array([Vector2(0, -r * 1.2), Vector2(r * 0.8, 0), Vector2(0, r * 1.2), Vector2(-r * 0.8, 0)])
		"arch":
			for k in 9:
				pts.append(Vector2.from_angle(PI + PI * k / 8) * r)
			pts.append(Vector2(r, r))
			pts.append(Vector2(-r, r))
	return pts


func issue(i: int) -> Dictionary:
	var s: Dictionary = _plan[i]
	if s.has("action") or s.has("issued"):
		return s
	s.issued = true
	_drift_mood()
	_wobble(s)
	var chance := MISTAKE_CHANCE_METICULOUS if _meticulous_style else MISTAKE_CHANCE
	chance *= 1.6 - focus
	if not (s.ponder or s.precise) or s.get("fix", false) or s.has("mistake") or randf() >= chance:
		return s
	var intended := s.duplicate()
	intended.erase("issued")
	var kind := _weighted(MISTAKES)
	s.mistake = kind
	s.intended = intended
	match kind:
		"slip":
			s.pos += Vector2.from_angle(randf() * TAU) * randf_range(0.05, 0.12)
			if randf() < 0.6:
				s.rot += randf_range(12.0, 40.0) * (1 if randf() < 0.5 else -1)
			if randf() < 0.4:
				s.size *= [0.65, 1.5].pick_random()
		"distracted":
			s.intended_pos = s.pos
			s.pos += Vector2.from_angle(randf() * TAU) * randf_range(0.08, 0.2)
			s.look_away = randf_range(LOOK_AWAY_MIN, LOOK_AWAY_MAX)
	s.pos = s.pos.clamp(Vector2(-BLEED, -BLEED), Vector2(1.0 + BLEED, 1.0 + BLEED))
	return s


## Call after the i-th stroke is done. Reacts to a mistake by queueing its fix
## right after it, and now and then queues an impulsive sticker.
func after_stroke(i: int) -> void:
	var s: Dictionary = _plan[i]
	if s.has("mistake"):
		_plan_fix(i, s)
	elif (s.get("ponder", false) or s.get("precise", false)) and not s.get("fix", false):
		if randf() < (IMPULSE_CHANCE_METICULOUS if _meticulous_style else IMPULSE_CHANCE) * (0.4 + energy * 1.6):
			var impulse := _impulse()
			_plan.insert(i + 1, impulse)


func _impulse() -> Dictionary:
	"""Something unplanned, slapped down without much thought: any sticker,
	any colour, a bold size."""
	var library_size := StickerLibrary.sticker_library.size()
	var stamp := {
		"sticker": randi() % maxi(library_size, 1),
		"pos": Vector2(randf_range(0.1, 0.9), randf_range(0.1, 0.9)),
		"rot": randf_range(0.0, 360.0),
		"size": maxf(randf_range(0.2, 0.5), _min_size),
		"ponder": false, "precise": false, "issued": true,
		"mistake": "impulse",
	}
	return stamp


func _plan_fix(i: int, s: Dictionary) -> void:
	var fix := _weighted(FIXES_METICULOUS if _meticulous_style else FIXES)
	s.fix_kind = fix
	var steps: Array[Dictionary] = []
	match fix:
		"undo":
			steps.append({"action": "undo", "fix": true})
		"cover":
			# Paint over it with the background, sized to hide it
			if _ground >= 0:
				var cover_extent := _extent(_ground, 1.0, _ground_rot)
				var size := clampf(s.size * 1.3 / minf(cover_extent.x, cover_extent.y), s.size, 1.2)
				_stamp(steps, _ground, s.pos, _ground_rot + randf_range(-3.0, 3.0), size, false)
			else:
				steps.append({"action": "undo", "fix": true})
		"echo":
			# Do it again, on purpose, so it reads as a decision
			var copies := randi_range(1, 3)
			if randf() < 0.5 or copies == 1:
				_stamp(steps, s.sticker, Vector2(1.0 - s.pos.x, s.pos.y), -s.rot, s.size, true)
			var step := Vector2.from_angle(randf() * TAU) * maxf(s.size * 0.9, 0.12)
			for k in copies - 1:
				_stamp(steps, s.sticker, s.pos + step * (k + 1), s.rot, s.size, k == 0)
		"build_around":
			# Make it the centre of something: frame it with a few small pieces
			var accent := _pick(["line", "motif", "motif"].pick_random(), [], "accent")
			var n := randi_range(2, 4)
			var radius := maxf(s.size * 0.6, 0.1)
			var start := randf() * TAU
			for k in n:
				var a := start + TAU * k / n
				_stamp(steps, accent, s.pos + Vector2(cos(a), sin(a) * _aspect_fix()) * radius, rad_to_deg(a) + 90.0, maxf(s.size * 0.6, 0.15), k == 0)
	# undo and cover put the intended stroke back where it belonged
	if fix in ["undo", "cover"] and s.has("intended"):
		var redo: Dictionary = s.intended.duplicate()
		redo.erase("look_away")
		redo.erase("intended_pos")
		steps.append(redo)
	for step in steps:
		step.fix = true
		step.issued = true
	if not steps.is_empty():
		# Notice it first: look at the mistake for a moment
		steps[0].stare = randf_range(STARE_MIN, STARE_MAX)
		steps[0].stare_pos = s.pos
	for k in steps.size():
		_plan.insert(i + 1 + k, steps[k])


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
	if role == "carve":
		return not ("line" in roles or "frame" in roles) and _color(sticker).coverage >= CARVE_COVERAGE and _color(sticker).busy <= CALM_BUSYNESS
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
	that isn't transparent), busy (spread of brightness: high for stripes and
	patterns, low for flat colour)}. Works for custom and bought stickers too."""
	var library := StickerLibrary.sticker_library
	if sticker < 0 or sticker >= library.size() or not library[sticker].texture:
		return {"hue": -1.0, "colorful": 0.0, "light": 0.5, "coverage": 0.5, "busy": 0.2}
	var id := library[sticker].id
	if _colors.has(id):
		return _colors[id]
	var img := library[sticker].texture.get_image()
	var summary := {"hue": -1.0, "colorful": 0.0, "light": 0.5, "coverage": 0.5, "busy": 0.2}
	if img:
		if img.is_compressed():
			img.decompress()
		img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
		var solid := 0
		var saturated := 0
		var light := 0.0
		var light_sq := 0.0
		var hue_vec := Vector2.ZERO
		for y in 64:
			for x in 64:
				var px := img.get_pixel(x, y)
				if px.a < 0.5:
					continue
				solid += 1
				light += px.get_luminance()
				light_sq += px.get_luminance() * px.get_luminance()
				if px.s > 0.3 and px.v > 0.25:
					saturated += 1
					hue_vec += Vector2.from_angle(px.h * TAU)
		if solid > 0:
			summary.coverage = solid / 4096.0
			summary.light = light / solid
			summary.busy = sqrt(maxf(light_sq / solid - summary.light * summary.light, 0.0))
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
