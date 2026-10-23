extends CSGBox3D
## A slot cut into the gallery floor. A painting let go over it is lined up
## with the slot, drops through the floor, and bursts into flames when it
## reaches the burn zone at the bottom of the pit. The slot is too narrow for
## the player to fall into.
## The root is a CSG subtraction, so instance it as a child of the floor CSG
## (then re-run tools/bake_csg_shells.gd and re-bake the LightmapGI).

const DeathZone = preload("res://scripts/DeathZone.gd")
const DROPPING_META := &"trash_slot_dropping"

@export var align_time: float = 0.2 ## seconds to turn a painting edge-down over the slot
@export var fall_time: float = 0.7 ## seconds to drop from the floor to the burn zone

@onready var _catch: Area3D = $Catch
@onready var _burn_zone: Area3D = $BurnZone

func _physics_process(_delta: float) -> void:
	# Polled rather than body_entered: a painting carried over the slot and
	# then let go never re-enters the area.
	for body in _catch.get_overlapping_bodies():
		if body is CarryablePainting and not body.has_meta(DROPPING_META) and not _is_carried(body):
			_drop(body)
	# Anything that falls in on its own (thrown edge-first) burns here too.
	for body in _burn_zone.get_overlapping_bodies():
		if body is CarryablePainting and not body.has_meta(DROPPING_META):
			_burn(body)

func _is_carried(painting: Node) -> bool:
	for child in painting.get_children():
		if child is CarryableComponent:
			return child.is_being_carried()
	return false

func _drop(painting: CarryablePainting) -> void:
	painting.set_meta(DROPPING_META, true)
	# Out of physics and out of reach of the player's pickup ray while it falls.
	painting.freeze = true
	painting.collision_layer = 0
	painting.collision_mask = 0

	var scale := painting.global_basis.get_scale()
	var extents := _painting_extents(painting) * scale
	# Painting axes by size: longest edge, height, thickness.
	var order := [0, 1, 2]
	order.sort_custom(func(a, b): return extents[a] > extents[b])
	var long_axis: int = order[0]
	var height_axis: int = order[1]
	var thin_axis: int = order[2]
	var half_length := extents[long_axis] * 0.5
	var half_height := extents[height_axis] * 0.5
	# Stand it on edge with its long edge along the slot; turn whichever way is closer.
	var along := global_basis.x.normalized()
	if painting.global_basis[long_axis].dot(along) < 0.0:
		along = -along
	var target_basis := Basis()
	target_basis[long_axis] = along
	target_basis[height_axis] = Vector3.UP
	target_basis[thin_axis] = along.cross(Vector3.UP)
	if target_basis.determinant() < 0.0:
		target_basis[thin_axis] = -target_basis[thin_axis]
	target_basis = target_basis.scaled_local(scale)
	var slack := maxf(size.x * 0.5 - half_length, 0.0)
	var offset := clampf((painting.global_position - global_position).dot(global_basis.x.normalized()), -slack, slack)
	var top := global_position + global_basis.x.normalized() * offset
	top.y = _floor_top() + half_height + 0.05
	var bottom := top
	bottom.y = _burn_zone.global_position.y

	var tween := painting.create_tween()
	tween.set_parallel(true)
	tween.tween_property(painting, "global_basis", target_basis, align_time)
	tween.tween_property(painting, "global_position", top, align_time)
	tween.chain().tween_property(painting, "global_position", bottom, fall_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_burn.bind(painting))

func _burn(painting: CarryablePainting) -> void:
	if not is_instance_valid(painting) or painting.is_queued_for_deletion():
		return
	DeathZone.spawn_fire_effect(get_tree().root, painting.global_position)
	painting.queue_free()
	if SteamManager:
		SteamManager.unlock_achievement("ACH_BURN_PAINTING")

func _floor_top() -> float:
	return global_position.y + size.y * 0.5 - 0.02

## Size of the painting's main collision box along the painting's own axes.
func _painting_extents(painting: Node3D) -> Vector3:
	var biggest := Vector3.ZERO
	for node in painting.find_children("*", "CollisionShape3D", false, false):
		var shape := node as CollisionShape3D
		var box := shape.shape as BoxShape3D
		if box == null:
			continue
		var b := shape.transform.basis
		var e := Vector3(
			absf(b.x.x) * box.size.x + absf(b.y.x) * box.size.y + absf(b.z.x) * box.size.z,
			absf(b.x.y) * box.size.x + absf(b.y.y) * box.size.y + absf(b.z.y) * box.size.z,
			absf(b.x.z) * box.size.x + absf(b.y.z) * box.size.y + absf(b.z.z) * box.size.z)
		if e.length() > biggest.length():
			biggest = e
	return biggest
