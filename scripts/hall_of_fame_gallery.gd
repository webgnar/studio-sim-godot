extends Node3D
class_name HallOfFameGallery
## Spawns the "Hall of Fame" paintings synced from the studio-sim-gallery website.
##
## Build-time only: no runtime network calls. Run the website's
## `scripts/download-hall-of-fame.mjs`, copy the resulting `hall-of-fame/` folder into this
## project as `res://hall_of_fame/`, reopen/focus the editor so the .glb files import, then
## attach this script to an empty Node3D wherever the gallery should live.
##
## Layout: if any descendant is in `placeholder_group`, its transform is used as a slot (in
## manifest order, sorted by node name) instead of the auto-generated grid — swap this in once
## real frame placeholders exist in the scene. Extra paintings beyond the placeholder count fall
## back to the grid so nothing silently gets dropped.

const HALL_OF_FAME_DIR := "res://hall_of_fame/"
const MANIFEST_PATH := HALL_OF_FAME_DIR + "manifest.json"
const GROUP_SPAWNED := "hall_of_fame_painting"

## Group name for placeholder frame nodes (Node3D/Marker3D) already in the scene. Leave empty to
## always use the grid layout.
@export var placeholder_group: String = "hall_of_fame_slot"

## Grid layout fallback, used for any painting without a placeholder slot.
@export var columns: int = 4
@export var spacing: Vector2 = Vector2(2.5, 2.5) ## x = gap between columns, y = gap between rows
@export var grid_origin: Vector3 = Vector3.ZERO ## local offset of the first grid slot

## Uniform scale applied to each spawned painting on top of whatever the .glb import gives it.
@export var painting_scale: float = 1.0

## Label3D shown under each painting with title / artist / statement.
@export var label_font_size: int = 32
@export var label_offset: Vector3 = Vector3(0, -0.9, 0.05)
@export var label_max_statement_chars: int = 160


func _ready() -> void:
	_clear_previous_spawns()

	var manifest := _load_manifest()
	if manifest.is_empty():
		return

	var slots := _collect_placeholder_slots()
	var grid_index := 0
	for i in manifest.size():
		var entry: Variant = manifest[i]
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("HallOfFameGallery: skipping non-object manifest entry at index %d" % i)
			continue

		if i < slots.size():
			_spawn_painting(entry, slots[i].global_transform, true)
		else:
			_spawn_painting(entry, _grid_local_transform(grid_index), false)
			grid_index += 1

	if not slots.is_empty() and slots.size() < manifest.size():
		push_warning("HallOfFameGallery: only %d '%s' placeholders for %d paintings, overflow used the grid layout" % [slots.size(), placeholder_group, manifest.size()])

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


func _collect_placeholder_slots() -> Array[Node3D]:
	var slots: Array[Node3D] = []
	if placeholder_group.is_empty() or not is_inside_tree():
		return slots

	for node in get_tree().get_nodes_in_group(placeholder_group):
		if node is Node3D and is_ancestor_of(node):
			slots.append(node)

	slots.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	return slots


func _grid_local_transform(index: int) -> Transform3D:
	var row := index / columns
	var col := index % columns
	var pos := grid_origin + Vector3(col * spacing.x, -row * spacing.y, 0)
	return Transform3D(Basis(), pos)


func _spawn_painting(entry: Dictionary, xform: Transform3D, is_global: bool) -> void:
	var glb_file: String = entry.get("glb", "")
	var painting_id: String = entry.get("id", glb_file.get_basename())

	if glb_file.is_empty():
		push_warning("HallOfFameGallery: manifest entry '%s' has no glb file, skipping" % painting_id)
		return

	var glb_path := HALL_OF_FAME_DIR + glb_file
	if not ResourceLoader.exists(glb_path):
		push_warning("HallOfFameGallery: %s not found - copy hall-of-fame/ into res://hall_of_fame/ and reopen the editor so it imports" % glb_path)
		return

	var packed := load(glb_path)
	if not (packed is PackedScene):
		push_warning("HallOfFameGallery: %s did not import as a PackedScene, skipping" % glb_path)
		return

	var instance := (packed as PackedScene).instantiate()
	instance.name = String("HallOfFame_%s" % painting_id).validate_node_name()
	instance.add_to_group(GROUP_SPAWNED)
	add_child(instance)

	if is_global:
		instance.global_transform = xform
	else:
		instance.transform = xform

	if instance is Node3D and painting_scale != 1.0:
		instance.scale *= painting_scale

	var title: String = entry.get("title", "Untitled")
	var artist: String = entry.get("artistName", "Unknown Artist")
	var statement: String = entry.get("artistStatement", "")

	var label := Label3D.new()
	label.name = "InfoLabel"
	label.text = _build_label_text(title, artist, statement)
	label.font_size = label_font_size
	label.outline_size = 12
	label.outline_modulate = Color.BLACK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = label_offset
	instance.add_child(label)


func _build_label_text(title: String, artist: String, statement: String) -> String:
	var text := title
	text += "\nby " + artist

	if not statement.is_empty():
		var trimmed := statement
		if trimmed.length() > label_max_statement_chars:
			trimmed = trimmed.substr(0, label_max_statement_chars) + "…"
		text += "\n\n\"%s\"" % trimmed

	return text


func _clear_previous_spawns() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(GROUP_SPAWNED):
		if is_ancestor_of(node):
			node.queue_free()
