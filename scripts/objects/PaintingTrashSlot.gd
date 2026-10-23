extends CSGBox3D
## A thin slot cut into the gallery floor. Paintings dropped onto or into it
## burn like the ones that used to go off the end of the old stair corridor;
## it's too narrow for the player to fall into.
## The root is a CSG subtraction, so instance it as a child of the floor CSG
## (then re-run tools/bake_csg_shells.gd and re-bake the LightmapGI).

const DeathZone = preload("res://scripts/DeathZone.gd")

@onready var _catch: Area3D = $Catch

func _physics_process(_delta: float) -> void:
	# Polled rather than body_entered: a painting carried into the slot and
	# then let go never re-enters the area.
	for body in _catch.get_overlapping_bodies():
		if body is CarryablePainting and not body.is_queued_for_deletion() and not _is_carried(body):
			_burn(body)

func _is_carried(painting: Node) -> bool:
	for child in painting.get_children():
		if child is CarryableComponent:
			return child.is_being_carried()
	return false

func _burn(painting: CarryablePainting) -> void:
	DeathZone.spawn_fire_effect(get_tree().root, painting.global_position)
	painting.queue_free()
	if SteamManager:
		SteamManager.unlock_achievement("ACH_BURN_PAINTING")
