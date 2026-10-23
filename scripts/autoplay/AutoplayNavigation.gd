extends Node

## Navigation for the idle autoplay bot.
## Bakes a navmesh for the whole level at runtime from its static collision
## (walls, floors, CSG with collision) onto a private navigation map, so the
## bot can path anywhere a player can walk without touching the gallery
## visitors' navmesh or needing a navmesh baked in the editor.
## Moving props (RigidBodies) aren't in the bake; the bot handles bumping
## into them by re-planning.

signal baked

const CELL_SIZE := 0.15
const CELL_HEIGHT := 0.1
const AGENT_RADIUS := 0.45   ## player capsule is 0.4, plus a little clearance
const AGENT_HEIGHT := 1.9
const AGENT_MAX_CLIMB := 0.35
const AGENT_MAX_SLOPE := 45.0

var _map: RID
var _region: RID
var _baked_for: Node = null   ## the scene the current bake belongs to
var _baking: bool = false


func _ready() -> void:
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_map, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(_map, CELL_HEIGHT)
	NavigationServer3D.map_set_active(_map, true)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_region, _map)


func _exit_tree() -> void:
	NavigationServer3D.free_rid(_region)
	NavigationServer3D.free_rid(_map)


func is_ready_for(scene: Node) -> bool:
	return _baked_for == scene and is_instance_valid(scene) and not _baking


## Bake for this scene if we haven't yet. Awaitable; returns true once a bake
## for `scene` is in place.
func ensure_baked(scene: Node) -> bool:
	if is_ready_for(scene):
		return true
	if _baking:
		await baked
		return is_ready_for(scene)
	_baking = true

	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_size = CELL_SIZE
	nav_mesh.cell_height = CELL_HEIGHT
	nav_mesh.agent_radius = AGENT_RADIUS
	nav_mesh.agent_height = AGENT_HEIGHT
	nav_mesh.agent_max_climb = AGENT_MAX_CLIMB
	nav_mesh.agent_max_slope = AGENT_MAX_SLOPE
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN

	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, scene)
	var started := Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data_async(nav_mesh, source, func() -> void:
		_on_bake_finished.call_deferred(nav_mesh, scene, started))
	await baked
	return is_ready_for(scene)


func _on_bake_finished(nav_mesh: NavigationMesh, scene: Node, started: int) -> void:
	NavigationServer3D.region_set_navigation_mesh(_region, nav_mesh)
	_baked_for = scene
	# The map picks up the region on its next sync
	var iteration := NavigationServer3D.map_get_iteration_id(_map)
	for i in 30:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_map) != iteration:
			break
	_baking = false
	print("AutoplayNavigation: baked %d polygons in %d ms" % [nav_mesh.get_polygon_count(), Time.get_ticks_msec() - started])
	baked.emit()


func closest_point(pos: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(_map, pos)


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(_map, closest_point(from), closest_point(to), true)


## True when a path from `from` actually reaches `to`, not just the nearest
## point to it on a disconnected island.
func can_reach(from: Vector3, to: Vector3, tolerance: float = 0.6) -> bool:
	var path := find_path(from, to)
	return not path.is_empty() and path[path.size() - 1].distance_to(closest_point(to)) <= tolerance


## A random walkable spot the player can reach on foot from `from`.
func random_reachable_point(from: Vector3, tries: int = 12) -> Variant:
	for i in tries:
		var p := NavigationServer3D.map_get_random_point(_map, 1, true)
		if p.distance_to(from) > 2.0 and can_reach(from, p):
			return p
	return null
