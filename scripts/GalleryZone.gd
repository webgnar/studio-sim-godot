extends Area3D
class_name GalleryZone
## Area3D that defines the gallery floor footprint.
## GalleryVisitor queries this to find objects physically inside the gallery.
## Resize the CollisionShape3D child in the editor to match your gallery layout.

func _ready() -> void:
	add_to_group("gallery_zone")
	monitoring = true
	monitorable = false


## Returns shop_prop bodies currently overlapping this zone.
func get_reactable_bodies() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for body in get_overlapping_bodies():
		if not is_instance_valid(body) or not body.is_visible_in_tree():
			continue
		if body.is_in_group("shop_prop"):
			result.append(body as Node3D)
	return result


## Returns true if node's global_position is inside this zone's AABB.
## Used for StaticBody3D gallery_attraction nodes (sculptures) that don't trigger body_entered.
func contains_node(node: Node3D) -> bool:
	var aabb := _get_world_aabb()
	if aabb.size == Vector3.ZERO:
		return false
	return aabb.has_point(node.global_position)


func _get_world_aabb() -> AABB:
	var shape_node := find_child("CollisionShape3D", true, false) as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return AABB()
	var box := shape_node.shape as BoxShape3D
	if box == null:
		return AABB()
	var half := box.size / 2.0
	var center := shape_node.global_position
	return AABB(center - half, box.size)
