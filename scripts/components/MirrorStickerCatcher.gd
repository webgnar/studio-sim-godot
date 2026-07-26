extends StaticBody3D
class_name MirrorStickerCatcher
## Invisible collision plane placed just in front of a mirror's reflective
## surface, purely so PaintingSystem3D will accept sticker placement there.
## Must NOT be a descendant of the mirror's own node — the mirror is in the
## "interactable" group (for its skin-cycle prompt), and
## PaintingModeManager._is_raycast_hitting_interactable() blocks sticker
## placement on anything with an "interactable" ancestor. This is wired as an
## independent sibling instead.
##
## Positioning: for a static mirror like this, just hand-place this node's
## transform and resize its CollisionShape3D directly in the editor — leave
## mirror_node unassigned. Only assign mirror_node if the mirror it's paired
## with can move/be repositioned at runtime and this should track it.

@export var mirror_node: Node3D  ## Optional. If assigned, re-aligns to this mirror's transform at _ready(); leave empty to use this node's own hand-placed transform as-is.
@export var front_offset: float = 0.03  ## Only used when mirror_node is assigned: distance in front of the mirror surface, along its local +Y (PlaneMesh normal)

func _ready() -> void:
	if not mirror_node:
		return
	global_transform = mirror_node.global_transform
	position += global_transform.basis.y.normalized() * front_offset
