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

## Where sticker centres may go, in viewer space. A little past the edges is
## fine (and needed to tile to the edge); the canvas's hitbox reaches further.
const BLEED := 0.08
## Tiles are spaced at this fraction of their size, so they overlap and leave no gaps.
const TILE_OVERLAP := 0.7

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


# --- Interface used by AutoplayBot ---

## Plan a painting for `system`, the canvas the bot is standing in front of.
func begin_painting(system: PaintingSystem2D) -> void:
	_frame = _canvas_frame(system)
	_aspect = _frame.height / _frame.width
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
	waypoints.append(_to_uv(s.pos))
	return {
		"sticker_index": s.sticker,
		"waypoints": waypoints,
		"rotation_deg": _frame.rotation_offset + _frame.rotation_sign * s.rot,
		"scale": clampf(s.size * _frame.width / (system.sticker_scale * system.plane_width), system.min_scale, system.max_scale),
		"settle": randf_range(SETTLE_MIN, SETTLE_MAX) if s.ponder else QUICK_SETTLE,
		"pause_after": randf_range(PAUSE_AFTER_MIN, PAUSE_AFTER_MAX) if s.ponder else QUICK_PAUSE_AFTER,
	}


## Seconds to drag the ghost between two canvas points.
func drag_time(from_uv: Vector2, to_uv: Vector2) -> float:
	return maxf(from_uv.distance_to(to_uv) / DRAG_SPEED, DRAG_TIME_MIN)


func hover_time() -> float:
	return randf_range(HOVER_MIN, HOVER_MAX)


# --- Planning (viewer space) ---

## The whole painting as a list of stamps, back to front. Each stamp is
## {sticker, pos: Vector2 (0..1 across and down), rot (degrees clockwise,
## 0 = upright), size (longest side, as a fraction of canvas width), ponder}.
## `add_on` skips the background and structure, for canvases that already
## have something on them. Doesn't touch the scene, so tools can call it
## directly to preview plans.
func plan_painting(aspect: float, add_on: bool = false) -> Array[Dictionary]:
	_aspect = aspect
	_palette.clear()
	var plan: Array[Dictionary] = []
	var horizon := -1.0
	if not add_on:
		var fill := _pick("fill")
		var fill_rot := _layer_rotation()
		_tile(plan, fill, Rect2(0, 0, 1, 1), randf_range(0.7, 1.1), fill_rot)
		if randf() < 0.3:
			_tile(plan, _pick("texture"), Rect2(0, 0, 1, 1), randf_range(0.6, 1.0), _layer_rotation())
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
			_tile(plan, _pick("fill", [base_fill]), Rect2(0, h, 1, 1.0 - h), randf_range(0.5, 0.8), _layer_rotation())
			if randf() < 0.6:
				_row(plan, _pick("band"), h, randf_range(0.3, 0.5), 0.0)
			return h
		"split":
			var x := randf_range(0.4, 0.6)
			_tile(plan, _pick("fill", [base_fill]), Rect2(x, 0, 1.0 - x, 1), randf_range(0.5, 0.8), _layer_rotation())
		"stripes":
			var band := _pick("band")
			var angle: float = [0.0, 90.0, randf_range(25.0, 60.0) * (1 if randf() < 0.5 else -1)].pick_random()
			var count := randi_range(4, 7)
			var dir := Vector2.from_angle(deg_to_rad(angle + 90.0))
			for i in count:
				var offset := (float(i) + 0.5) / count - 0.5
				var c := Vector2(0.5, 0.5) + dir * offset * 1.1
				_stamp(plan, band, Vector2(c.x, c.y), angle, randf_range(1.3, 1.6), false)
		"border":
			var band := _pick("band")
			var size := randf_range(0.35, 0.55)
			var inset := 0.05
			_row(plan, band, inset, size, 0.0)
			_row(plan, band, 1.0 - inset, size, 180.0)
			_column(plan, band, inset, size, -90.0)
			_column(plan, band, 1.0 - inset, size, 90.0)
		"panels":
			var a := _pick("fill", [base_fill])
			var b := _pick("fill", [base_fill, a])
			for q in 4:
				var cell := Rect2((q % 2) * 0.5 + 0.03, (q / 2) * 0.5 + 0.03, 0.44, 0.44)
				_tile(plan, a if (q == 0 or q == 3) else b, cell, 0.35, 0.0, 0.02)
	return -1.0


func _motif(plan: Array[Dictionary], kind: String, horizon: float) -> void:
	"""One sticker repeated: the rhythm in most Hall of Fame paintings."""
	if kind == "none":
		return
	var sticker := _pick("motif")
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
			_stamp(plan, _pick("subject"), Vector2(x + randf_range(-0.03, 0.03), py), randf_range(-12.0, 12.0), part_size, true)
	else:
		_stamp(plan, _pick("subject"), p, randf_range(-10.0, 10.0), size, true)
	return p


func _accents(plan: Array[Dictionary], focus: Vector2) -> void:
	var line := _pick("line")
	for i in randi_range(1, 4):
		var p := focus + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		_stamp(plan, line, p.clamp(Vector2(0.08, 0.08), Vector2(0.92, 0.92)), randf_range(0.0, 360.0), randf_range(0.15, 0.3), i == 0)


# --- Layout helpers ---

func _tile(plan: Array[Dictionary], sticker: int, area: Rect2, size: float, rot: float, jitter: float = 0.04) -> void:
	"""Cover `area` with overlapping copies of one sticker, brick-style."""
	var extent := _extent(sticker, size, rot)
	var step := Vector2(extent.x * TILE_OVERLAP, extent.y * TILE_OVERLAP / _aspect)
	var cols := maxi(1, ceili(area.size.x / step.x))
	var rows := maxi(1, ceili(area.size.y / step.y))
	var used := Vector2(cols * step.x, rows * step.y)
	var origin := area.position + (area.size - used) / 2.0 + step / 2.0
	for r in rows:
		var shift := step.x * 0.5 if r % 2 == 1 and cols > 1 else 0.0
		for c in cols + (1 if shift > 0.0 else 0):
			var p := origin + Vector2(c * step.x - shift, r * step.y)
			p += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
			_stamp(plan, sticker, p, rot + randf_range(-3.0, 3.0), size, false)


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


func _stamp(plan: Array[Dictionary], sticker: int, pos: Vector2, rot: float, size: float, ponder: bool) -> void:
	plan.append({
		"sticker": sticker,
		"pos": pos.clamp(Vector2(-BLEED, -BLEED), Vector2(1.0 + BLEED, 1.0 + BLEED)),
		"rot": rot,
		"size": size,
		"ponder": ponder,
	})


func _extent(sticker: int, size: float, rot: float) -> Vector2:
	"""Width and height a sticker covers at `size` (canvas widths), after a
	right-angle-ish rotation."""
	var tex := _texture_size(sticker)
	var e := tex / maxf(tex.x, tex.y) * size
	return Vector2(e.y, e.x) if absf(fposmod(rot, 180.0) - 90.0) < 45.0 else e


func _aspect_fix() -> float:
	return 1.0 / _aspect


func _layer_rotation() -> float:
	"""One rotation for a whole layer: mostly square to the canvas."""
	if randf() < 0.15:
		return randf_range(-45.0, 45.0)
	return [0.0, 90.0, 180.0, 270.0].pick_random()


func _upright_rotation() -> float:
	return 0.0 if randf() < 0.7 else randf_range(-20.0, 20.0)


# --- Sticker picking ---

## Stickers already used in this painting are preferred, so it keeps to a
## small set of stickers like the Hall of Fame paintings do.
var _palette: Array[int] = []

func _pick(role: String, avoid: Array = []) -> int:
	var library := StickerLibrary.sticker_library
	var candidates: Array[int] = []
	for i in library.size():
		if not i in avoid and role in _roles(library[i]):
			candidates.append(i)
	if candidates.is_empty():
		for i in library.size():
			if not i in avoid:
				candidates.append(i)
	if candidates.is_empty():
		return 0
	var reuse := candidates.filter(func(i): return i in _palette)
	var pick: int = reuse.pick_random() if not reuse.is_empty() and randf() < 0.25 else candidates.pick_random()
	if not pick in _palette:
		_palette.append(pick)
	return pick


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
