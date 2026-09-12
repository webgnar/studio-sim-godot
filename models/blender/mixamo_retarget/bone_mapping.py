"""
Mixamo -> humanrig.blend bone mapping.

Reusable across the Phase 3 single-file test (run_single.py) and the
Phase 4 batch processor (batch_import.py). Edit this file if you add
bones to the target rig or need to support a Mixamo skeleton variant
that uses different names.

Target rig reference (from the Phase 1 rig inspection, see the plan doc):
  Main (root, non-deform) -> foot_IK.L/R -> foot.L/R -> foot.L.001/R.001
                              foot_IK.L/R -> LegTarget.L/R (pole)
  torso (root, non-deform) -> hip -> upperleg.L/R -> lowerleg.L/R
                            -> spine -> chest -> neck -> head
                                     -> clav.L/R -> upperarm.L/R -> lowerarm.L/R
                                     -> hand_IK.L/R -> hand.L/R (child)
  ArmTarget.L/R (pole, parent=None, zero mesh weight)

Only FK deform bones receive Mixamo rotation directly. hand_IK.*, foot_IK.*,
and the pole targets are handled separately in retarget_core.py (snapped to
match the resulting deform-bone transforms after the fact) rather than
mapped here.
"""

# Mixamo bone base names, WITHOUT the "mixamorig:" prefix -- resolve_source_bone()
# in retarget_core.py tries both "mixamorig:<name>" and bare "<name>" against
# whatever armature actually got imported, since exporters vary.
#
# Value is a list because some target bones (spine/chest) absorb rotation
# from more than one Mixamo bone -- see combine handling in retarget_core.py.
BONE_MAP: dict[str, list[str]] = {
    # Spine chain. Mixamo has Hips/Spine/Spine1/Spine2; target has one fewer
    # segment (spine, chest), so Spine1+Spine2 are combined onto "chest".
    "spine": ["Spine"],
    "chest": ["Spine1", "Spine2"],
    "neck": ["Neck"],
    "head": ["Head"],

    # Left arm
    "clav.L": ["LeftShoulder"],
    "upperarm.L": ["LeftArm"],
    "lowerarm.L": ["LeftForeArm"],
    "hand.L": ["LeftHand"],

    # Right arm
    "clav.R": ["RightShoulder"],
    "upperarm.R": ["RightArm"],
    "lowerarm.R": ["RightForeArm"],
    "hand.R": ["RightHand"],

    # Left leg
    "upperleg.L": ["LeftUpLeg"],
    "lowerleg.L": ["LeftLeg"],
    "foot.L": ["LeftFoot"],
    "foot.L.001": ["LeftToeBase"],

    # Right leg
    "upperleg.R": ["RightUpLeg"],
    "lowerleg.R": ["RightLeg"],
    "foot.R": ["RightFoot"],
    "foot.R.001": ["RightToeBase"],
}

# The target bone that receives the Mixamo root's (Hips) ROTATION only.
# Root motion is stripped per the in-place decision -- see the plan doc --
# so Hips' translation is never applied to this bone, just its rotation.
ROOT_BONE = "torso"
ROOT_SOURCE = "Hips"

# Target bones deliberately left at rest / not driven by Mixamo data.
# "hip" is a secondary pelvis-tilt bone under torso in this rig; folding
# Hips' full rotation into torso alone is simpler and robust, so hip stays
# at its rest pose. foot.L.001/R.001 fall back to rest automatically via
# build_bone_map() if the source clip has no toe bone (common -- many
# Mixamo exports omit toes), which is not an error.
INTENTIONALLY_UNMAPPED = {"hip"}

# IK control / pole bones that are snapped (not directly retargeted) after
# the FK deform chain above is posed -- see retarget_core.snap_ik_targets().
IK_TARGET_FOLLOWS = {
    "hand_IK.L": "hand.L",
    "hand_IK.R": "hand.R",
    "foot_IK.L": "foot.L",
    "foot_IK.R": "foot.R",
}
# Pole targets don't have a single deform-bone equivalent to snap to; they're
# positioned from the elbow/knee bend plane -- see retarget_core.snap_ik_targets().
POLE_TARGETS = {
    "ArmTarget.L": ("clav.L", "upperarm.L", "lowerarm.L"),
    "ArmTarget.R": ("clav.R", "upperarm.R", "lowerarm.R"),
    "LegTarget.L": ("hip", "upperleg.L", "lowerleg.L"),
    "LegTarget.R": ("hip", "upperleg.R", "lowerleg.R"),
}

# Bones whose presence in the source clip is required for a clip to be
# considered retargetable at all -- anything else missing is a per-bone
# warning (falls back to rest), not a hard failure. Kept deliberately small:
# a usable retarget just needs a spine and both arms; legs/toes are common
# omissions in some Mixamo "upper body only" exports and shouldn't hard-fail
# the whole batch.
REQUIRED_SOURCE_BONES = ["Hips", "Spine", "LeftArm", "RightArm"]
