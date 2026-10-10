extends Node3D
class_name NavCarve
## Cuts its parent's footprint out of the navigation mesh while the parent is visible, so
## NavigationAgents (gallery visitors) path around it instead of walking into it.
##
## Shop props can't be part of the baked navmesh (they're hidden until bought), so whenever
## a carver appears or disappears the NavigationRegion3D under it is rebaked at runtime from
## the region's own geometry plus every visible carver (~30 ms, baked on a thread). With no
## visible carvers left, the region gets its scene-baked navmesh back.
##
## Footprint: the XZ bounds of the parent's CollisionShape3D boxes/capsules (+ `padding`).
## The bake also keeps agents `agent_radius` away from it, like any wall.

const GROUP := "nav_carve"

## Extra margin around the collision footprint, in metres.
@export var padding: float = 0.0

static var _rebake_queued: bool = false
static var _original_meshes: Dictionary = {} # region instance id -> NavigationMesh from the scene
static var _bake_generation: Dictionary = {} # region instance id -> latest bake request
static var _source_cache: Dictionary = {} # region instance id -> parsed region geometry


func _ready() -> void:
	add_to_group(GROUP)
	visibility_changed.connect(_queue_rebake)
	_queue_rebake()


func _queue_rebake() -> void:
	if _rebake_queued or not is_inside_tree():
		return
	_rebake_queued = true
	var tree := get_tree()
	# Two frames: lets WorldSetup hide unbought props and CSG floors build their meshes first.
	await tree.process_frame
	await tree.process_frame
	_rebake_queued = false
	_rebake_all(tree)


## Footprint corners (global space) and vertical extent [bottom_y, top_y].
func get_footprint() -> Dictionary:
	var body := get_parent() as Node3D
	if body == null:
		return {}
	var to_local := body.global_transform.affine_inverse()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for shape_node: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
		var half := _shape_half_extents(shape_node.shape)
		if half == Vector3.ZERO:
			continue
		var xf := to_local * shape_node.global_transform
		for i in 8:
			var corner := Vector3(half.x * (1 if i & 1 else -1), half.y * (1 if i & 2 else -1), half.z * (1 if i & 4 else -1))
			var p := xf * corner
			lo = lo.min(p)
			hi = hi.max(p)
	if lo.x == INF:
		return {}
	lo -= Vector3(padding, 0, padding)
	hi += Vector3(padding, 0, padding)
	var bx := body.global_transform
	var corners := PackedVector3Array([
		bx * Vector3(lo.x, lo.y, lo.z), bx * Vector3(hi.x, lo.y, lo.z),
		bx * Vector3(hi.x, lo.y, hi.z), bx * Vector3(lo.x, lo.y, hi.z),
	])
	return {"corners": corners, "bottom": (bx * lo).y, "top": (bx * hi).y}


static func _shape_half_extents(shape: Shape3D) -> Vector3:
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size / 2.0
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return Vector3(capsule.radius, capsule.height / 2.0, capsule.radius)
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return Vector3(cylinder.radius, cylinder.height / 2.0, cylinder.radius)
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return Vector3(r, r, r)
	return Vector3.ZERO


static func _rebake_all(tree: SceneTree) -> void:
	var footprints: Array[Dictionary] = []
	for node in tree.get_nodes_in_group(GROUP):
		var carver := node as NavCarve
		if carver and carver.is_visible_in_tree():
			var fp := carver.get_footprint()
			if not fp.is_empty():
				footprints.append(fp)

	for region: NavigationRegion3D in tree.root.find_children("*", "NavigationRegion3D", true, false):
		var id := region.get_instance_id()
		if not _original_meshes.has(id):
			if region.navigation_mesh == null:
				continue
			_original_meshes[id] = region.navigation_mesh
		var original: NavigationMesh = _original_meshes[id]
		var to_region := region.global_transform.affine_inverse()
		var bounds := _mesh_bounds(original)

		var mine: Array[Dictionary] = []
		for fp in footprints:
			var local_corners := PackedVector3Array()
			for c: Vector3 in fp["corners"]:
				local_corners.append(to_region * c)
			var bottom: float = local_corners[0].y # corners sit at the footprint's bottom
			var fp_box := AABB(local_corners[0], Vector3.ZERO)
			for c in local_corners:
				fp_box = fp_box.expand(c)
			fp_box.size.y = fp["top"] - fp["bottom"]
			if bounds.grow(0.5).intersects(fp_box):
				mine.append({"corners": local_corners, "bottom": bottom, "height": fp["top"] - fp["bottom"]})

		var generation: int = _bake_generation.get(id, 0) + 1
		_bake_generation[id] = generation
		if mine.is_empty():
			if region.navigation_mesh != original:
				region.navigation_mesh = original
			continue

		# Parsing reads the visual meshes back from the GPU, so do it once per region (the
		# gallery is static) and reuse it; the first rebake happens during the loading fade.
		if not _source_cache.has(id):
			var parsed := NavigationMeshSourceGeometryData3D.new()
			NavigationServer3D.parse_source_geometry_data(original, parsed, region)
			_source_cache[id] = parsed
		var source := NavigationMeshSourceGeometryData3D.new()
		source.merge(_source_cache[id])
		for fp in mine:
			# carve = false: the bake also keeps agent_radius of clearance around it.
			source.add_projected_obstruction(fp["corners"], fp["bottom"], fp["height"], false)
		var baked: NavigationMesh = original.duplicate()
		NavigationServer3D.bake_from_source_geometry_data_async(baked, source, func() -> void:
			# Only the latest request for this region wins if bakes overlap.
			if is_instance_valid(region) and _bake_generation.get(id, 0) == generation:
				region.navigation_mesh = baked)


static func _mesh_bounds(mesh: NavigationMesh) -> AABB:
	var vertices := mesh.get_vertices()
	if vertices.is_empty():
		return AABB()
	var box := AABB(vertices[0], Vector3.ZERO)
	for v in vertices:
		box = box.expand(v)
	return box
