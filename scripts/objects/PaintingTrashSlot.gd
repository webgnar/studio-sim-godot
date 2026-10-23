extends CSGBox3D
## A slot cut into the gallery floor. It's just a hole: a painting only gets
## in if the player stands it on edge and lines it up with the slot, so
## nobody trashes a painting by accident. Paintings that make it down burst
## into flames at the burn zone near the bottom of the pit. The slot is too
## narrow for the player to fall into.
## The root is a CSG subtraction, so instance it as a child of the floor CSG
## (then re-run tools/bake_csg_shells.gd and re-bake the LightmapGI).

const DeathZone = preload("res://scripts/DeathZone.gd")

@onready var _burn_zone: Area3D = $BurnZone

func _physics_process(_delta: float) -> void:
	# Polled rather than body_entered, so a painting already inside the zone
	# when it's let go still burns.
	for body in _burn_zone.get_overlapping_bodies():
		if body is CarryablePainting and not body.is_queued_for_deletion():
			_burn(body)

func _burn(painting: CarryablePainting) -> void:
	DeathZone.spawn_fire_effect(get_tree().root, painting.global_position)
	painting.queue_free()
	if SteamManager:
		SteamManager.unlock_achievement("ACH_BURN_PAINTING")
