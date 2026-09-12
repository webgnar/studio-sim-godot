"""
How humanrig.blend is animated, and how Mixamo maps onto it.

Everything here was measured from the rig's own existing actions rather than
assumed -- see the plan doc. The short version: this rig is animated almost
entirely through IK control bones. In `walk`, upperarm/lowerarm/upperleg/
lowerleg have a rotation spread of exactly 0.000 while hand_IK moves 1.653
and foot_IK moves 3.715. The limbs are solved live by IK constraints.

So retargeting must drive the CONTROLS and leave the limbs (and every IK
constraint's influence) completely alone. Writing FK rotations onto the limbs
and switching IK off -- the first attempt -- fights the rig and, because
influence is rig-wide state, silently breaks every other action.

Channel convention, also measured (`walk` and `sit` agree):

    POSITION only : torso, hand_IK.L/R, foot_IK.L/R, ArmTarget.L/R, LegTarget.L/R
    ROTATION only : hip, spine, chest, head, hand.L/R, foot.L/R, foot.L.001/R.001
    NEVER KEYED   : Main, clav.L/R, upperarm.*, lowerarm.*, upperleg.*,
                    lowerleg.*, neck, chest_breath

We follow that convention exactly, so a retargeted dance is structurally
indistinguishable from a hand-authored action and imports into Godot the
same way.
"""

TARGET_ARMATURE = "Armature"
MIXAMO_PREFIX = "mixamorig:"

# --- rotation-driven targets: target bone <- one or more Mixamo bones -------
# Multiple sources are composed, used where this rig has fewer segments than
# Mixamo (Mixamo Spine/Spine1/Spine2 vs this rig's spine/chest, and Neck+Head
# vs this rig's head -- `neck` is never keyed in the existing actions).
ROTATION_MAP: dict[str, list[str]] = {
    "hip": ["Hips"],
    "spine": ["Spine"],
    "chest": ["Spine1", "Spine2"],
    "head": ["Neck", "Head"],
    "hand.L": ["LeftHand"],
    "hand.R": ["RightHand"],
    "foot.L": ["LeftFoot"],
    "foot.R": ["RightFoot"],
    "foot.L.001": ["LeftToeBase"],
    "foot.R.001": ["RightToeBase"],
}

# --- position-driven targets: target bone <- head position of a Mixamo bone -
# The IK controls. hand.L/foot.L are CHILDREN of these, so placing the control
# carries the hand/foot with it; their rotation comes from ROTATION_MAP above.
POSITION_MAP: dict[str, str] = {
    "hand_IK.L": "LeftHand",
    "hand_IK.R": "RightHand",
    "foot_IK.L": "LeftFoot",
    "foot_IK.R": "RightFoot",
}

# How far each IK control can physically be placed from the limb's root, so we
# never ask for a pose the chain can't span. Proportions differ slightly
# between the rigs (measured arm ratio 2.456 vs leg 2.403), so some source
# poses put a hand fractionally beyond our arm's reach -- the IK then stops
# short and the hand detaches from the wrist, stretching the mesh. Measured on
# Twist Dance: left hand overshot on 18 of 284 frames, up to 0.616 on a
# 2.65-long arm, while the right arm and both legs never did.
# (ik control) -> (chain root bone, bones whose lengths make up the chain)
REACH_LIMITS: dict[str, tuple[str, tuple[str, ...]]] = {
    "hand_IK.L": ("upperarm.L", ("upperarm.L", "lowerarm.L")),
    "hand_IK.R": ("upperarm.R", ("upperarm.R", "lowerarm.R")),
    "foot_IK.L": ("upperleg.L", ("upperleg.L", "lowerleg.L")),
    "foot_IK.R": ("upperleg.R", ("upperleg.R", "lowerleg.R")),
}
# Stay just inside full extension; a fully locked-out chain is numerically
# unstable for the solver.
REACH_MARGIN = 0.995

# --- pole targets: steer which way elbows and knees bend -------------------
# (pole bone, chain root, joint, chain tip). The pole is placed out along the
# joint's bend direction; putting it at the joint itself would sit exactly on
# the root->tip line whenever the limb straightens, which is degenerate and
# makes the solve flip.
POLE_MAP: dict[str, tuple[str, str, str]] = {
    "ArmTarget.L": ("LeftArm", "LeftForeArm", "LeftHand"),
    "ArmTarget.R": ("RightArm", "RightForeArm", "RightHand"),
    "LegTarget.L": ("LeftUpLeg", "LeftLeg", "LeftFoot"),
    "LegTarget.R": ("RightUpLeg", "RightLeg", "RightFoot"),
}
# How far past the joint to push the pole, as a multiple of the limb's length.
POLE_DISTANCE = 1.0

# --- body translation ------------------------------------------------------
# `torso` carries the body's translation in this rig (hip rotation lives on
# `hip`). Horizontal travel is dropped so every clip loops in place; vertical
# bob is kept because that's what makes a dance read as weighted.
TRANSLATION_BONE = "torso"
TRANSLATION_SOURCE = "Hips"
KEEP_VERTICAL_TRANSLATION = True

# Bones we must never write to -- the IK solver owns the limbs, and touching
# the rest would diverge from the rig's convention.
DO_NOT_TOUCH = {
    "Main", "clav.L", "clav.R", "neck", "chest_breath",
    "upperarm.L", "upperarm.R", "lowerarm.L", "lowerarm.R",
    "upperleg.L", "upperleg.R", "lowerleg.L", "lowerleg.R",
}

# Used to measure scale and facing between the two rigs.
SCALE_LIMBS = [
    (("upperleg.L", "lowerleg.L"), ("LeftUpLeg", "LeftLeg")),
    (("upperarm.L", "lowerarm.L"), ("LeftArm", "LeftForeArm")),
]
SHOULDER_PAIR = (("clav.L", "clav.R"), ("LeftShoulder", "RightShoulder"))
HIP_ANCHOR = ("hip", "Hips")

# A clip missing any of these can't be retargeted at all; anything else that's
# absent just leaves its target bone at rest, which is a warning, not a failure.
REQUIRED_SOURCE_BONES = ["Hips", "Spine", "LeftArm", "RightArm", "LeftUpLeg", "RightUpLeg"]
