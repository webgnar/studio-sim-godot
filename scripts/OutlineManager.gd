extends Node
class_name OutlineManager

## Manages hover outline effects for interactable objects
## Automatically creates duplicate meshes with outline shader

@export var outline_material: ShaderMaterial
@export var outline_thickness: float = 0.03
@export var excluded_objects: Array[Node3D] = []  ## Objects that should not show outlines

var current_outlined_object: Node3D = null
var outline_duplicates: Array[MeshInstance3D] = []

func _ready() -> void:
	# Load default outline material if not set
	if not outline_material:
		outline_material = load("res://materials/hover_outline_material.tres")

## Show outline on the given object
func show_outline(object: Node3D) -> void:
	if current_outlined_object == object:
		return  # Already outlined

	# Check if this object should be excluded from outlines
	if _is_excluded(object):
		return

	# Clear previous outline
	hide_outline()

	current_outlined_object = object

	# Find all MeshInstance3D children and create outline duplicates
	_create_outline_for_node(object)

## Hide the current outline
func hide_outline() -> void:
	# Remove all outline duplicates
	for outline_dup in outline_duplicates:
		if is_instance_valid(outline_dup):
			outline_dup.queue_free()

	outline_duplicates.clear()
	current_outlined_object = null

## Check if an object should be excluded from outlines
func _is_excluded(object: Node3D) -> bool:
	# Check if object is in "no_outline" group
	if object.is_in_group("no_outline"):
		return true

	# Check if object is in the excluded_objects array
	if object in excluded_objects:
		return true

	return false

## Recursively find MeshInstance3D nodes and create outline duplicates
func _create_outline_for_node(node: Node) -> void:
	if node is MeshInstance3D:
		_create_outline_duplicate(node)

	# Recursively check children
	for child in node.get_children():
		_create_outline_for_node(child)

## Create an outline duplicate for a single MeshInstance3D
func _create_outline_duplicate(mesh_instance: MeshInstance3D) -> void:
	# Create duplicate mesh
	var outline = MeshInstance3D.new()
	outline.name = mesh_instance.name + "_Outline"
	outline.mesh = mesh_instance.mesh
	outline.skeleton = mesh_instance.skeleton

	# Apply outline material to all surfaces
	if outline_material:
		for i in range(outline.mesh.get_surface_count()):
			outline.set_surface_override_material(i, outline_material)

	# Match transform
	outline.transform = mesh_instance.transform

	# Add as sibling to original mesh (so they share the same parent)
	mesh_instance.get_parent().add_child(outline)

	# Store reference for cleanup
	outline_duplicates.append(outline)
