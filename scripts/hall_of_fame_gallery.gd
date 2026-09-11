extends Node3D
class_name HallOfFameGallery
## Spawns the "Hall of Fame" paintings synced from the studio-sim-gallery website.
##
## Build-time only: no runtime network calls. Run the website's
## `scripts/download-hall-of-fame.mjs`, copy the resulting `hall-of-fame/` folder into this
## project as `res://hall_of_fame/`, reopen/focus the editor so the .glb files import, then
## attach this script to an empty Node3D wherever the gallery should live.
##
## LAYOUT: paintings are auto-flowed along "rails" instead of one marker per painting (the
## manifest can have dozens of mixed square/landscape paintings and keeps growing every re-sync,
## so a 1:1 marker count would mean constant manual upkeep). A rail is a pair of Node3D markers
## in `rail_group`, named "<name>_Start" and "<name>_End", both placed along one wall at hanging
## height. The Start marker's rotation defines which way paintings on that rail face: its local Z
## axis (blue arrow in the editor gizmo) should point away from the wall, into the room — only
## rotate it around the vertical axis, don't tilt it. Rails are visited in name order (natural
## sort, so "Wall2" comes before "Wall10"); each painting's real width (read from its own mesh, so
## square and landscape both just work) is packed along the current rail with `rail_margin`
## between paintings, wrapping to a higher row (up to `max_rows_per_rail`) when a rail fills, then
## moving to the next rail. Anything left over after every rail/row combo is full falls back to a
## flat grid so nothing is silently dropped.

const HALL_OF_FAME_DIR := "res://hall_of_fame/"
const MANIFEST_PATH := HALL_OF_FAME_DIR + "manifest.json"
const GROUP_SPAWNED := "hall_of_fame_painting"

## Group shared by every rail's Start/End marker pair.
@export var rail_group: String = "hall_of_fame_rail"

## Gap left between adjacent paintings along a rail, in meters.
@export var rail_margin: float = 0.25
## How many rows a single rail can stack before overflow moves on to the next rail.
@export var max_rows_per_rail: int = 1
## Vertical center-to-center gap between stacked rows on the same rail.
@export var row_spacing: float = 1.3

## Fallback grid, used only for paintings that don't fit any rail (or when no rails exist yet).
@export var grid_columns: int = 6
@export var grid_spacing: Vector2 = Vector2(2.0, 1.6)
@export var grid_origin: Vector3 = Vector3.ZERO
@export var grid_facing_dir: Vector3 = Vector3.BACK

## Uniform scale applied to each spawned painting on top of whatever the .glb import gives it.
@export var painting_scale: float = 1.0
## Used only if a painting's canvas mesh can't be found/measured.
@export var default_canvas_size: Vector2 = Vector2(3, 3)

## Label3D shown under each painting with title / artist / statement.
@export var show_labels: bool = true ## off = no label at all
@export var label_font_size: int = 32
@export var label_forward_offset: float = 0.05 ## how far off the wall, along the painting's normal
@export var label_drop: float = 0.3 ## extra gap below the painting's own bottom edge
@export var show_artist_info: bool = false ## off = title only; on = title + artist + statement
@export var label_max_statement_chars: int = 160

var _current_rail: int = 0


func _ready() -> void:
	_clear_previous_spawns()

	var manifest := _load_manifest()
	if manifest.is_empty():
		return

	var rails := _collect_rails()
	var cursors: Array = []
	for r in rails:
		cursors.append({"used": 0.0, "row": 0})
	if rails.is_empty():
		push_warning("HallOfFameGallery: no '%s' Start/End marker pairs found - using the fallback grid for all %d painting(s)" % [rail_group, manifest.size()])

	_current_rail = 0
	var grid_index := 0
	var overflow_count := 0

	for i in manifest.size():
		var entry: Variant = manifest[i]
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("HallOfFameGallery: skipping non-object manifest entry at index %d" % i)
			continue

		var instance := _load_painting_instance(entry)
		if instance == null:
			continue

		var size := _measure_canvas_size(instance)
		var width := size.x * painting_scale
		var height := size.y * painting_scale

		var placement := {}
		if not rails.is_empty():
			placement = _try_place_on_rail(rails, cursors, width)
			if placement.is_empty():
				overflow_count += 1

		if placement.is_empty():
			placement = {
				"position": _grid_position(grid_index),
				"wall_dir": global_transform.basis * Vector3.RIGHT,
				"facing": global_transform.basis * grid_facing_dir,
			}
			grid_index += 1

		_finalize_painting(instance, entry, placement, height)

	if overflow_count > 0:
		push_warning("HallOfFameGallery: %d painting(s) didn't fit any rail row, placed on the fallback grid instead" % overflow_count)

	print("HallOfFameGallery: spawned %d painting(s) from %s" % [manifest.size(), MANIFEST_PATH])


func _load_manifest() -> Array:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("HallOfFameGallery: no manifest at %s - sync and copy hall-of-fame/ into the project first (see the Hall of Fame notes)" % MANIFEST_PATH)
		return []

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		push_error("HallOfFameGallery: failed to open manifest: %s" % MANIFEST_PATH)
		return []

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("HallOfFameGallery: failed to parse manifest JSON (%s)" % json.get_error_message())
		return []

	if typeof(json.data) != TYPE_ARRAY:
		push_error("HallOfFameGallery: manifest.json should be a top-level array of paintings")
		return []

	return json.data


# --- RAILS ---

func _collect_rails() -> Array[Dictionary]:
	var rails: Array[Dictionary] = []
	if rail_group.is_empty() or not is_inside_tree():
		return rails

	var starts := {}
	var ends := {}
	for node in get_tree().get_nodes_in_group(rail_group):
		if not (node is Node3D):
			continue
		var n: String = node.name
		if n.ends_with("_Start"):
			starts[n.trim_suffix("_Start")] = node
		elif n.ends_with("_End"):
			ends[n.trim_suffix("_End")] = node
		else:
			push_warning("HallOfFameGallery: rail marker '%s' doesn't end in _Start/_End, ignoring" % n)

	var keys := starts.keys()
	keys.sort_custom(func(a, b): return String(a).naturalnocasecmp_to(String(b)) < 0)

	for key in keys:
		if not ends.has(key):
			push_warning("HallOfFameGallery: rail '%s' has a Start marker but no matching End marker, skipping" % key)
			continue
		var start_node: Node3D = starts[key]
		var end_node: Node3D = ends[key]
		var start_pos := start_node.global_position
		var end_pos := end_node.global_position
		var length := start_pos.distance_to(end_pos)
		if length < 0.01:
			push_warning("HallOfFameGallery: rail '%s' has zero length, skipping" % key)
			continue

		var wall_dir := (end_pos - start_pos) / length
		var facing := start_node.global_transform.basis.z.normalized()

		# If the Start marker's blue (Z) axis points along the wall instead of away from it, the
		# standing-transform math below degenerates to an all-zero basis - no crash, no warning,
		# the painting just silently collapses to a point. Catch it here instead so it's obvious.
		if absf(facing.dot(wall_dir)) > 0.95:
			push_warning("HallOfFameGallery: rail '%s' Start marker's blue (Z) axis points along the wall instead of away from it - rotate it ~90° around the vertical axis so it faces into the room. Using a guessed facing direction for now so paintings stay visible." % key)
			facing = Vector3.UP.cross(wall_dir).normalized()

		rails.append({
			"start": start_pos,
			"wall_dir": wall_dir,
			"length": length,
			"facing": facing,
		})

	return rails


## Tries to fit `width` on the current rail/row, advancing rows then rails as each fills up.
## Returns {} if it doesn't fit anywhere across every rail's every row.
func _try_place_on_rail(rails: Array[Dictionary], cursors: Array, width: float) -> Dictionary:
	var max_attempts: int = rails.size() * max(max_rows_per_rail, 1)
	for _attempt in max_attempts:
		var rail: Dictionary = rails[_current_rail]
		var cur: Dictionary = cursors[_current_rail]
		if cur["used"] + width <= rail["length"]:
			var center_d: float = cur["used"] + width / 2.0
			var pos: Vector3 = rail["start"] + rail["wall_dir"] * center_d + Vector3.UP * (cur["row"] * row_spacing)
			cursors[_current_rail]["used"] = cur["used"] + width + rail_margin
			return {"position": pos, "wall_dir": rail["wall_dir"], "facing": rail["facing"]}

		if cur["row"] + 1 < max_rows_per_rail:
			cursors[_current_rail] = {"used": 0.0, "row": cur["row"] + 1}
		else:
			_current_rail = (_current_rail + 1) % rails.size()

	return {}


## `grid_origin`/`grid_spacing` are authored in local space (relative to this node, wherever it
## sits in the room) - has to go through this node's own global_transform before use, otherwise
## it lands at raw world-space coordinates instead of relative to the room.
func _grid_position(index: int) -> Vector3:
	var columns: int = maxi(grid_columns, 1)
	@warning_ignore("integer_division")
	var row := index / columns
	var col := index % columns
	var local_pos := grid_origin + Vector3(col * grid_spacing.x, -row * grid_spacing.y, 0)
	return global_transform * local_pos


# --- PAINTING INSTANCING ---

func _load_painting_instance(entry: Dictionary) -> Node:
	var glb_file := _string_or(entry, "glb", "")
	var painting_id := _string_or(entry, "id", glb_file.get_basename())

	if glb_file.is_empty():
		push_warning("HallOfFameGallery: manifest entry '%s' has no glb file, skipping" % painting_id)
		return null

	var glb_path := HALL_OF_FAME_DIR + glb_file
	if not ResourceLoader.exists(glb_path):
		push_warning("HallOfFameGallery: %s not found - copy hall-of-fame/ into res://hall_of_fame/ and reopen the editor so it imports" % glb_path)
		return null

	var packed := load(glb_path)
	if not (packed is PackedScene):
		push_warning("HallOfFameGallery: %s did not import as a PackedScene, skipping" % glb_path)
		return null

	return (packed as PackedScene).instantiate()


## Reads the painting's real on-canvas size from its own mesh (the "Canvas" child that
## PaintingExporter.gd bakes into every exported .glb) so square vs. landscape just works without
## the manifest needing to say which is which.
func _measure_canvas_size(instance: Node) -> Vector2:
	var canvas := instance.get_node_or_null("Canvas") as MeshInstance3D
	if canvas == null:
		canvas = _find_first_plane_mesh(instance)
	if canvas == null or canvas.mesh == null:
		return default_canvas_size

	var aabb := canvas.mesh.get_aabb()
	return Vector2(aabb.size.x * canvas.scale.x, aabb.size.z * canvas.scale.z)


func _find_first_plane_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh is PlaneMesh:
			return child
		var found := _find_first_plane_mesh(child)
		if found:
			return found
	return null


## Canvas meshes import flat (PlaneMesh default: normal +Y, "size.y" along local Z) since that's
## how PaintingExporter.gd bakes them. Rather than trust whatever rotation the .glb's root
## happened to have, build the standing orientation from scratch: local X = along the wall,
## local Y = outward normal (facing), local Z = down (see note below - not up). Re-orthogonalized
## and handedness-corrected so imprecise marker rotation in the editor can't produce a mirror.
## NOTE: empirically the visible/painted side ends up on local -Y, not +Y as the PlaneMesh normal
## alone would suggest - confirmed in-game (paintings showed their stretcher-bar backs facing the
## room until this flip was added). Rigidly rotates the whole frame+canvas assembly together, so
## it doesn't affect the frame/canvas relative alignment, only which way the pair faces overall.
## Also confirmed via the canvas mesh's own UV data that the image's top edge sits on local -Z, not
## +Z - so local Z has to point DOWN in world space (not up) for the image to read right-side-up.
func _build_standing_transform(world_position: Vector3, wall_tangent: Vector3, facing_dir: Vector3) -> Transform3D:
	var y := -facing_dir.normalized()
	var x := (wall_tangent - y * wall_tangent.dot(y)).normalized()
	var z := x.cross(y).normalized()
	if z.dot(Vector3.UP) > 0.0:
		x = -x
		z = -z

	var standing_basis := Basis(x, y, z)
	if painting_scale != 1.0:
		standing_basis = standing_basis.scaled(Vector3.ONE * painting_scale)

	return Transform3D(standing_basis, world_position)


func _finalize_painting(instance: Node, entry: Dictionary, placement: Dictionary, height: float) -> void:
	var painting_id := _string_or(entry, "id", "")
	instance.name = String("HallOfFame_%s" % painting_id).validate_node_name()
	instance.add_to_group(GROUP_SPAWNED)
	add_child(instance)
	instance.global_transform = _build_standing_transform(placement["position"], placement["wall_dir"], placement["facing"])
	_disable_backface_culling(instance)

	if not show_labels:
		return

	var title := _string_or(entry, "title", "Untitled")
	var artist := _string_or(entry, "artistName", "Unknown Artist")
	var statement := _string_or(entry, "artistStatement", "")

	var label := Label3D.new()
	label.name = "InfoLabel"
	label.text = _build_label_text(title, artist, statement)
	label.font_size = label_font_size
	label.outline_size = 12
	label.outline_modulate = Color.BLACK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Local axes here match _build_standing_transform: Y = outward normal, Z = down (not up - see
	# that function's note on the canvas's UV data), so "below the painting" is positive Z.
	label.position = Vector3(0, label_forward_offset, height / 2.0 + label_drop)
	instance.add_child(label)


## Getting a rail's Start marker rotated exactly right (blue axis pointing away from the wall) by
## eye, with no live preview, is an easy thing to get backwards. Rather than let a flipped
## painting render as a fully invisible blank wall (Godot backface-culls by default), make every
## spawned surface double-sided so a wrong-way marker shows a visibly mirrored painting instead -
## obviously wrong, but visible and easy to fix by rotating the marker 180°.
func _disable_backface_culling(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface_i in node.mesh.get_surface_count():
			var mat: Material = node.get_surface_override_material(surface_i)
			if mat == null:
				mat = node.mesh.surface_get_material(surface_i)
			if mat is StandardMaterial3D:
				var unique_mat := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				unique_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				node.set_surface_override_material(surface_i, unique_mat)

	for child in node.get_children():
		_disable_backface_culling(child)


func _build_label_text(title: String, artist: String, statement: String) -> String:
	var text := title
	if not show_artist_info:
		return text

	text += "\nby " + artist

	if not statement.is_empty():
		var trimmed := statement
		if trimmed.length() > label_max_statement_chars:
			trimmed = trimmed.substr(0, label_max_statement_chars) + "…"
		text += "\n\n\"%s\"" % trimmed

	return text


## Dictionary.get(key, default) only falls back to `default` when the key is missing entirely -
## if the key is present but explicitly `null` (which the sync script writes for paintings with
## no artist name/statement), it returns null itself, which can't be assigned to a String var.
func _string_or(entry: Dictionary, key: String, default: String) -> String:
	var value = entry.get(key, default)
	return default if value == null else String(value)


func _clear_previous_spawns() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(GROUP_SPAWNED):
		if is_ancestor_of(node):
			node.queue_free()
