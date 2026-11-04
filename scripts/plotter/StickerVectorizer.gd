class_name StickerVectorizer
extends RefCounted

## Turns a sticker PNG into flat colour regions (polygons), so the plotter can
## paint it: each colour becomes one paint layer, and each region is outlined
## and/or filled with hatching at plot time.
##
## Pipeline (every step has a setting below, so it can be tuned):
##   1. shrink the sticker to `detail` pixels across: this is the main detail
##      knob, and also blurs away paper/brush texture
##   2. pick up to `max_colors` paint colours with k-means, then merge ones
##      closer than `merge_tolerance` (brush texture stays one colour)
##   3. give every pixel its nearest colour, then smooth the colour map with
##      `smooth_passes` majority filters so speckle doesn't become regions
##   4. trace each colour's regions along pixel edges (outer outlines and
##      holes as separate rings), drop regions smaller than `min_region`,
##      simplify by `simplify` pixels and round off with `smooth_outline`
##
## Output is in the sticker's original pixel coordinates, so a placed sticker's
## position / rotation / scale applies to it directly.
##
## Pure: uses Image and math only, no nodes or autoloads.

## Pixels across the longest side the sticker is traced at.
var detail: int = 600
## Most paint colours per sticker (k-means clusters before merging).
var max_colors: int = 24
## Clusters closer than this (0..1, weighted RGB distance) are merged into one
## paint colour, so a single-colour sticker with brush texture stays one colour.
var merge_tolerance: float = 0.07
## Colours covering less than this share of the sticker are folded into their
## nearest neighbour.
var min_color_share: float = 0.004
## Majority-filter passes over the colour map (removes speckle).
var smooth_passes: int = 2
## Outline simplification tolerance, in traced pixels.
var simplify: float = 0.8
## Chaikin corner-cutting passes on each outline (rounds off pixel steps).
var smooth_outline: int = 1
## Regions smaller than this share of the sticker's area are absorbed into
## the neighbouring colour they touch most (so no gaps are left).
var min_region: float = 0.002
## Alpha above this counts as sticker.
var alpha_threshold: float = 0.5
## k-means iterations and seed (fixed, so results repeat).
var kmeans_iterations: int = 12
var seed: int = 1


## Returns {
##   size: Vector2 (original pixel size),
##   layers: Array of {color: Color, coverage: float, polygons: Array[PackedVector2Array]},
## }
## Layers are ordered light to dark (paint light first). Polygons include holes
## as separate rings; fill them with the even-odd rule (see hatch()).
func vectorize(img: Image) -> Dictionary:
	var src := img.duplicate() as Image
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var orig := Vector2(src.get_width(), src.get_height())
	var s := float(detail) / maxf(orig.x, orig.y)
	var w := maxi(2, roundi(orig.x * s))
	var h := maxi(2, roundi(orig.y * s))
	# Shrink with premultiplied alpha, so the see-through pixels' hidden colour
	# doesn't bleed a dark or light rim into the sticker's edge
	src.premultiply_alpha()
	src.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var to_orig := Vector2(orig.x / w, orig.y / h)

	# Pixels: RGB + opaque flag
	var n := w * h
	var rgb := PackedFloat32Array()
	rgb.resize(n * 3)
	var opaque := PackedByteArray()
	opaque.resize(n)
	var opaque_count := 0
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			var i := y * w + x
			var inv := 1.0 / c.a if c.a > 0.001 else 0.0
			rgb[i * 3] = clampf(c.r * inv, 0.0, 1.0)
			rgb[i * 3 + 1] = clampf(c.g * inv, 0.0, 1.0)
			rgb[i * 3 + 2] = clampf(c.b * inv, 0.0, 1.0)
			if c.a > alpha_threshold:
				opaque[i] = 1
				opaque_count += 1
	var result := {"size": orig, "layers": []}
	if opaque_count == 0:
		return result

	var centres := _kmeans(rgb, opaque, mini(max_colors, opaque_count))
	centres = _merge_colours(rgb, opaque, centres)
	var k := centres.size() / 3

	# Label map: -1 transparent, else colour index
	var labels := PackedInt32Array()
	labels.resize(n)
	for i in n:
		labels[i] = _nearest(rgb, i, centres, k) if opaque[i] else -1
	for _p in smooth_passes:
		labels = _majority(labels, w, h, k)
	var min_area := min_region * opaque_count
	labels = _absorb_small(labels, w, h, k, maxi(1, roundi(min_area)))
	var layers: Array = []
	for c in k:
		var count := 0
		for i in n:
			if labels[i] == c:
				count += 1
		if count == 0:
			continue
		var polys: Array[PackedVector2Array] = []
		for ring in trace_rings(labels, w, h, c):
			# Isolated specks with no neighbour to join (and tiny holes)
			if absf(_area(ring)) < min_area:
				continue
			var simple := _simplify_closed(ring, simplify)
			if simple.size() < 3:
				continue
			var scaled := PackedVector2Array()
			for p in _chaikin(simple, smooth_outline):
				scaled.append(p * to_orig)
			polys.append(scaled)
		if polys.is_empty():
			continue
		var col := Color(centres[c * 3], centres[c * 3 + 1], centres[c * 3 + 2])
		layers.append({"color": col, "coverage": float(count) / opaque_count, "polygons": polys})
	layers.sort_custom(func(a, b): return a.color.get_luminance() > b.color.get_luminance())
	result.layers = layers
	return result


# --- Hatching (used at plot time, in mm) ----------------------------------------

## Fills polygons (even-odd, so hole rings cut holes) with parallel lines.
## spacing and the result are in the polygons' units; angle in degrees.
static func hatch(polygons: Array, spacing: float, angle_deg: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if polygons.is_empty() or spacing <= 0.0:
		return out
	var rot := -deg_to_rad(angle_deg)
	# Rotate everything so hatch lines are horizontal
	var rings: Array[PackedVector2Array] = []
	var lo := INF
	var hi := -INF
	for poly in polygons:
		var r := PackedVector2Array()
		for p in poly:
			var q: Vector2 = p.rotated(rot)
			r.append(q)
			lo = minf(lo, q.y)
			hi = maxf(hi, q.y)
		rings.append(r)
	var flip := false
	var y := lo + spacing * 0.5
	while y < hi:
		var xs := PackedFloat32Array()
		for r in rings:
			var m := r.size()
			for i in m:
				var a := r[i]
				var b := r[(i + 1) % m]
				if (a.y <= y) != (b.y <= y):
					xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		# Alternate direction row to row, so consecutive strokes start near
		# where the last one ended
		var segs: Array[PackedVector2Array] = []
		var j := 0
		while j + 1 < xs.size():
			if xs[j + 1] - xs[j] > 1e-6:
				segs.append(PackedVector2Array([Vector2(xs[j], y).rotated(-rot), Vector2(xs[j + 1], y).rotated(-rot)]))
			j += 2
		if flip:
			segs.reverse()
			for k in segs.size():
				segs[k].reverse()
		out.append_array(segs)
		flip = not flip
		y += spacing
	return out


## The strokes that paint one colour layer with a round tool `tool_width`
## wide (all in the polygons' units, normally canvas mm after
## transform_polylines).
##   - Each region is shrunk by half the tool width, so paint lands inside the
##     traced edge, then outlined and filled with hatching `spacing_ratio` ×
##     tool width apart.
##   - Parts too thin for the tool (narrow necks, thin bands, whole thin
##     regions) vanish when shrunk. Those leftovers are found and painted with
##     strokes along their own long direction, so thin parts still get paint
##     (slightly over the edge rather than not at all).
static func paint_strokes(polygons: Array, tool_width: float, hatch_angle: float = 0.0, spacing_ratio: float = 0.8, draw_outlines: bool = true) -> Array[PackedVector2Array]:
	var d := tool_width * 0.5
	var inset: Array[PackedVector2Array] = []
	var outers: Array[PackedVector2Array] = []
	var holes: Array[PackedVector2Array] = []
	for ring in polygons:
		var hole := _area(ring) < 0.0
		if hole:
			holes.append(ring)
		else:
			outers.append(ring)
		for r in Geometry2D.offset_polygon(ring, d if hole else -d):
			inset.append(r)
	var out: Array[PackedVector2Array] = []
	if draw_outlines:
		out.append_array(outlines(inset))
	out.append_array(hatch(inset, tool_width * spacing_ratio, hatch_angle))

	# What the shrunk-then-painted area misses: region - holes - (inset grown back)
	var covered: Array[PackedVector2Array] = []
	for r in inset:
		if not Geometry2D.is_polygon_clockwise(r):
			for g in Geometry2D.offset_polygon(r, d * 1.02):
				covered.append(g)
	var min_area := tool_width * tool_width * 0.25
	for ring in outers:
		var left: Array[PackedVector2Array] = [ring]
		for cut in covered + holes:
			var next: Array[PackedVector2Array] = []
			for piece in left:
				for res in Geometry2D.clip_polygons(piece, cut):
					next.append(res)
			left = next
		for piece in left:
			if Geometry2D.is_polygon_clockwise(piece) or absf(_area(piece)) < min_area:
				continue
			# Holes the clip produced inside this piece belong with it
			var group: Array = [piece]
			for other in left:
				if other != piece and Geometry2D.is_polygon_clockwise(other) and Geometry2D.is_point_in_polygon(other[0], piece):
					group.append(other)
			out.append_array(hatch(group, tool_width * spacing_ratio, _long_axis_deg(piece)))
	return out


## Direction of a shape's longest extent, degrees (principal axis).
static func _long_axis_deg(poly: PackedVector2Array) -> float:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= maxf(1.0, poly.size())
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	for p in poly:
		var q := p - c
		sxx += q.x * q.x
		syy += q.y * q.y
		sxy += q.x * q.y
	return rad_to_deg(0.5 * atan2(2.0 * sxy, sxx - syy))


## Closed outlines as polylines (first point repeated at the end).
static func outlines(polygons: Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for poly in polygons:
		if poly.size() < 2:
			continue
		var line: PackedVector2Array = poly.duplicate()
		line.append(poly[0])
		out.append(line)
	return out


## Maps sticker-pixel polylines onto the canvas: centred on the sticker, then
## scaled, rotated and moved. scale is mm per sticker pixel.
static func transform_polylines(lines: Array, sticker_size: Vector2, position_mm: Vector2, rotation_deg: float, scale: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var rot := deg_to_rad(rotation_deg)
	var half := sticker_size * 0.5
	for line in lines:
		var t := PackedVector2Array()
		for p in line:
			t.append(((p - half) * scale).rotated(rot) + position_mm)
		out.append(t)
	return out


# --- Tracing --------------------------------------------------------------------

## Traces the boundaries of every pixel labelled `label` into closed rings,
## following pixel edges. Outer boundaries come out with positive area
## (_area), holes negative, so even-odd filling and insetting both work.
## Pixels touching only at a corner are kept apart.
static func trace_rings(labels: PackedInt32Array, w: int, h: int, label: int) -> Array[PackedVector2Array]:
	var stride := w + 1
	var nexts := {}  # start vertex -> PackedInt32Array of end vertices
	var inside := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and labels[y * w + x] == label
	for y in h:
		for x in w:
			if labels[y * w + x] != label:
				continue
			# Directed edges with the region on the right (y down)
			if not inside.call(x, y - 1):
				_add_edge(nexts, y * stride + x, y * stride + x + 1)
			if not inside.call(x + 1, y):
				_add_edge(nexts, y * stride + x + 1, (y + 1) * stride + x + 1)
			if not inside.call(x, y + 1):
				_add_edge(nexts, (y + 1) * stride + x + 1, (y + 1) * stride + x)
			if not inside.call(x - 1, y):
				_add_edge(nexts, (y + 1) * stride + x, y * stride + x)
	var rings: Array[PackedVector2Array] = []
	while not nexts.is_empty():
		var start: int = nexts.keys()[0]
		var ring := PackedVector2Array()
		var prev := start
		var cur := _take_edge(nexts, start, -1, stride)
		ring.append(Vector2(start % stride, start / stride))
		var guard := 0
		while cur != start and cur >= 0 and guard < 10000000:
			ring.append(Vector2(cur % stride, cur / stride))
			var nxt := _take_edge(nexts, cur, prev, stride)
			prev = cur
			cur = nxt
			guard += 1
		rings.append(_drop_collinear(ring))
	return rings


static func _add_edge(nexts: Dictionary, a: int, b: int) -> void:
	if not nexts.has(a):
		nexts[a] = PackedInt32Array()
	var arr: PackedInt32Array = nexts[a]
	arr.append(b)
	nexts[a] = arr


## Removes and returns an edge leaving `v`. At a corner where two leave, it
## takes the right turn, so diagonal neighbours stay separate rings.
static func _take_edge(nexts: Dictionary, v: int, from: int, stride: int) -> int:
	if not nexts.has(v):
		return -1
	var arr: PackedInt32Array = nexts[v]
	var pick := 0
	if arr.size() > 1 and from >= 0:
		var din := Vector2(v % stride - from % stride, v / stride - from / stride)
		var best := -INF
		for i in arr.size():
			var dout := Vector2(arr[i] % stride - v % stride, arr[i] / stride - v / stride)
			var turn := din.cross(dout)  # > 0: right turn on screen (y down)
			if turn > best:
				best = turn
				pick = i
	var to := arr[pick]
	arr.remove_at(pick)
	if arr.is_empty():
		nexts.erase(v)
	else:
		nexts[v] = arr
	return to


static func _drop_collinear(ring: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := ring.size()
	for i in m:
		var a := ring[(i - 1 + m) % m]
		var b := ring[i]
		var c := ring[(i + 1) % m]
		if absf((b - a).cross(c - b)) > 1e-9:
			out.append(b)
	return out


## Ramer-Douglas-Peucker on a closed ring (split at the two furthest points).
static func _simplify_closed(ring: PackedVector2Array, eps: float) -> PackedVector2Array:
	if ring.size() < 4 or eps <= 0.0:
		return ring
	var far := 0
	for k in ring.size():
		if ring[k].distance_squared_to(ring[0]) > ring[far].distance_squared_to(ring[0]):
			far = k
	var first := ring.slice(0, far + 1)
	var second := ring.slice(far)
	second.append(ring[0])
	var a := _rdp(first, eps)
	var b := _rdp(second, eps)
	a.resize(a.size() - 1)
	b.resize(b.size() - 1)
	a.append_array(b)
	return a


static func _rdp(line: PackedVector2Array, eps: float) -> PackedVector2Array:
	if line.size() < 3:
		return line
	var worst := 0
	var worst_d := 0.0
	var a := line[0]
	var b := line[line.size() - 1]
	var ab := b - a
	var len_ab := ab.length()
	for k in range(1, line.size() - 1):
		var d := absf(ab.cross(line[k] - a)) / len_ab if len_ab > 1e-9 else line[k].distance_to(a)
		if d > worst_d:
			worst_d = d
			worst = k
	if worst_d <= eps:
		return PackedVector2Array([a, b])
	var left := _rdp(line.slice(0, worst + 1), eps)
	var right := _rdp(line.slice(worst), eps)
	left.resize(left.size() - 1)
	left.append_array(right)
	return left


# --- Internals ------------------------------------------------------------------

func _kmeans(rgb: PackedFloat32Array, opaque: PackedByteArray, k: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var idx := PackedInt32Array()
	for i in opaque.size():
		if opaque[i]:
			idx.append(i)
	# Sample for speed
	var sample := idx
	if idx.size() > 6000:
		sample = PackedInt32Array()
		for _s in 6000:
			sample.append(idx[rng.randi_range(0, idx.size() - 1)])
	# k-means++ init
	var centres := PackedFloat32Array()
	var first := sample[rng.randi_range(0, sample.size() - 1)]
	centres.append_array([rgb[first * 3], rgb[first * 3 + 1], rgb[first * 3 + 2]])
	var d2 := PackedFloat32Array()
	d2.resize(sample.size())
	while centres.size() / 3 < k:
		var total := 0.0
		var cur := centres.size() / 3
		for s in sample.size():
			var best := INF
			for c in cur:
				best = minf(best, _dist2(rgb, sample[s], centres, c))
			d2[s] = best
			total += best
		if total <= 0.0:
			break  # fewer distinct colours than k
		var pick := rng.randf() * total
		var chosen := sample[sample.size() - 1]
		for s in sample.size():
			pick -= d2[s]
			if pick <= 0.0:
				chosen = sample[s]
				break
		centres.append_array([rgb[chosen * 3], rgb[chosen * 3 + 1], rgb[chosen * 3 + 2]])
	var kk := centres.size() / 3
	for _it in kmeans_iterations:
		var sums := PackedFloat32Array()
		sums.resize(kk * 4)
		for s in sample:
			var c := _nearest(rgb, s, centres, kk)
			sums[c * 4] += rgb[s * 3]
			sums[c * 4 + 1] += rgb[s * 3 + 1]
			sums[c * 4 + 2] += rgb[s * 3 + 2]
			sums[c * 4 + 3] += 1.0
		for c in kk:
			if sums[c * 4 + 3] > 0.0:
				centres[c * 3] = sums[c * 4] / sums[c * 4 + 3]
				centres[c * 3 + 1] = sums[c * 4 + 1] / sums[c * 4 + 3]
				centres[c * 3 + 2] = sums[c * 4 + 2] / sums[c * 4 + 3]
	return centres


## Merges near-identical clusters and folds tiny ones into their neighbours.
func _merge_colours(rgb: PackedFloat32Array, opaque: PackedByteArray, centres: PackedFloat32Array) -> PackedFloat32Array:
	var k := centres.size() / 3
	# Pixel counts per cluster (weights for merging)
	var counts := PackedFloat32Array()
	counts.resize(k)
	for i in opaque.size():
		if opaque[i]:
			counts[_nearest(rgb, i, centres, k)] += 1.0
	var total := 0.0
	for c in counts:
		total += c
	var cols: Array = []  # [r, g, b, weight]
	for c in k:
		if counts[c] > 0.0:
			cols.append([centres[c * 3], centres[c * 3 + 1], centres[c * 3 + 2], counts[c]])
	var tol2 := merge_tolerance * merge_tolerance
	while cols.size() > 1:
		# Closest pair, or a tiny cluster and its nearest neighbour
		var best_a := -1
		var best_b := -1
		var best_d := INF
		var tiny := -1
		for a in cols.size():
			if cols[a][3] < min_color_share * total and (tiny < 0 or cols[a][3] < cols[tiny][3]):
				tiny = a
		for a in cols.size():
			for b in range(a + 1, cols.size()):
				if tiny >= 0 and a != tiny and b != tiny:
					continue
				var d := _col_dist2(cols[a], cols[b])
				if d < best_d:
					best_d = d
					best_a = a
					best_b = b
		if tiny < 0 and best_d > tol2:
			break
		var A: Array = cols[best_a]
		var B: Array = cols[best_b]
		var wsum: float = A[3] + B[3]
		cols[best_a] = [(A[0] * A[3] + B[0] * B[3]) / wsum, (A[1] * A[3] + B[1] * B[3]) / wsum, (A[2] * A[3] + B[2] * B[3]) / wsum, wsum]
		cols.remove_at(best_b)
	var out := PackedFloat32Array()
	for c in cols:
		out.append_array([c[0], c[1], c[2]])
	return out


static func _col_dist2(a: Array, b: Array) -> float:
	var dr: float = a[0] - b[0]
	var dg: float = a[1] - b[1]
	var db: float = a[2] - b[2]
	return 0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db


## Chaikin corner cutting on a closed ring.
static func _chaikin(poly: PackedVector2Array, passes: int) -> PackedVector2Array:
	var cur := poly
	for _p in passes:
		var m := cur.size()
		if m < 3:
			break
		var nxt := PackedVector2Array()
		for i in m:
			var a := cur[i]
			var b := cur[(i + 1) % m]
			nxt.append(a.lerp(b, 0.25))
			nxt.append(a.lerp(b, 0.75))
		cur = nxt
	return cur


static func _dist2(rgb: PackedFloat32Array, i: int, centres: PackedFloat32Array, c: int) -> float:
	var dr := rgb[i * 3] - centres[c * 3]
	var dg := rgb[i * 3 + 1] - centres[c * 3 + 1]
	var db := rgb[i * 3 + 2] - centres[c * 3 + 2]
	# Rough perceptual weighting
	return 0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db


static func _nearest(rgb: PackedFloat32Array, i: int, centres: PackedFloat32Array, k: int) -> int:
	var best := 0
	var best_d := INF
	for c in k:
		var d := _dist2(rgb, i, centres, c)
		if d < best_d:
			best_d = d
			best = c
	return best


## Patches smaller than min_px pixels take the colour they share the longest
## border with, so tiny specks never become their own region (or a gap).
static func _absorb_small(labels: PackedInt32Array, w: int, h: int, k: int, min_px: int) -> PackedInt32Array:
	var out := labels.duplicate()
	for _round in 3:
		var comp := PackedInt32Array()
		comp.resize(w * h)
		comp.fill(-1)
		var changed := false
		var stack := PackedInt32Array()
		var border := PackedInt32Array()
		border.resize(k)
		for start in w * h:
			if out[start] < 0 or comp[start] >= 0:
				continue
			var lab := out[start]
			var members := PackedInt32Array([start])
			comp[start] = start
			stack.append(start)
			border.fill(0)
			while not stack.is_empty():
				var i := stack[stack.size() - 1]
				stack.resize(stack.size() - 1)
				var x := i % w
				var y := i / w
				for dir in 4:
					var nx := x + (1 if dir == 0 else -1 if dir == 1 else 0)
					var ny := y + (1 if dir == 2 else -1 if dir == 3 else 0)
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var j := ny * w + nx
					var lj := out[j]
					if lj == lab:
						if comp[j] < 0:
							comp[j] = start
							stack.append(j)
							members.append(j)
					elif lj >= 0:
						border[lj] += 1
			if members.size() >= min_px:
				continue
			var best := -1
			for c in k:
				if border[c] > 0 and (best < 0 or border[c] > border[best]):
					best = c
			if best >= 0:
				for i in members:
					out[i] = best
				changed = true
		if not changed:
			break
	return out


static func _majority(labels: PackedInt32Array, w: int, h: int, k: int) -> PackedInt32Array:
	var out := labels.duplicate()
	var counts := PackedInt32Array()
	counts.resize(k)
	for y in h:
		for x in w:
			var here := labels[y * w + x]
			if here < 0:
				continue
			counts.fill(0)
			for dy in range(-1, 2):
				var yy := y + dy
				if yy < 0 or yy >= h:
					continue
				for dx in range(-1, 2):
					var xx := x + dx
					if xx < 0 or xx >= w:
						continue
					var l := labels[yy * w + xx]
					if l >= 0:
						counts[l] += 1
			var best := here
			for c in k:
				if counts[c] > counts[best]:
					best = c
			if counts[best] >= 5 or best == here:
				out[y * w + x] = best
	return out


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	var m := poly.size()
	for i in m:
		a += poly[i].cross(poly[(i + 1) % m])
	return a * 0.5
