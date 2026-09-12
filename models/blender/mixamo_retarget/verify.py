"""
Scripted checks on a retargeted result.

Every check here exists because the first attempt shipped a bug that this
would have caught in one run. Run these before trusting a clip, and before
batching -- rendering frames and squinting at them is the slowest possible
way to find a rigging bug.

Usage (inside Blender, after a retarget):
    import verify
    ok = verify.run_all(action_name="Dance_Twist_Dance")
"""

import math

import bpy
from mathutils import Quaternion

import rig_profile as P

# Baseline actions that must not change. `sit` is included because the Studio
# Assistant depends on it.
PROTECTED_ACTIONS = ["walk", "idle", "sit", "run", "jump", "meditate"]


def _curves(action):
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for cbag in strip.channelbags:
                out.extend(cbag.fcurves)
    return out


def snapshot_actions(names=None):
    """Fingerprint actions so we can prove we didn't touch them."""
    names = names or PROTECTED_ACTIONS
    snap = {}
    for name in names:
        action = bpy.data.actions.get(name)
        if action is None:
            continue
        f0, f1 = (int(round(v)) for v in action.frame_range)
        data = {}
        for fc in _curves(action):
            key = (fc.data_path, fc.array_index)
            data[key] = tuple(round(fc.evaluate(f), 6) for f in range(f0, f1 + 1))
        snap[name] = data
    return snap


def check_existing_untouched(before, after) -> list[str]:
    """The regression that actually bit v1: retargeting changed IK state and
    every hand-authored animation lost its hands and feet."""
    problems = []
    for name, before_curves in before.items():
        after_curves = after.get(name)
        if after_curves is None:
            problems.append(f"action {name!r} disappeared")
            continue
        if set(before_curves) != set(after_curves):
            problems.append(f"action {name!r} gained/lost channels")
            continue
        for key, vals in before_curves.items():
            if after_curves[key] != vals:
                problems.append(f"action {name!r} channel {key[0]}[{key[1]}] changed")
                break
    return problems


def check_ik_untouched(target_obj) -> list[str]:
    """IK influence is rig-wide state. It must stay at 1.0 and must never be
    keyframed by us -- keying it in one action leaks into all the others."""
    problems = []
    for pb in target_obj.pose.bones:
        for c in pb.constraints:
            if c.type == 'IK' and abs(c.influence - 1.0) > 1e-6:
                problems.append(f"{pb.name}: IK influence is {c.influence}, expected 1.0")
    for action in bpy.data.actions:
        for fc in _curves(action):
            if "influence" in fc.data_path:
                problems.append(f"action {action.name!r} keyframes constraint influence")
                break
    return problems


def check_untouched_bones(action) -> list[str]:
    """Limbs are solved by IK; keying them diverges from the rig's convention."""
    problems = []
    for fc in _curves(action):
        if 'pose.bones' not in fc.data_path:
            continue
        bone = fc.data_path.split('"')[1]
        if bone in P.DO_NOT_TOUCH:
            problems.append(f"{action.name!r} writes to {bone!r}, which IK owns")
            break
    return problems


def _sample_frames(action, count=12):
    f0, f1 = (int(round(v)) for v in action.frame_range)
    step = max(1, (f1 - f0) // count)
    return list(range(f0, f1 + 1, step))


def check_limbs_connected(target_obj, action, tolerance=0.05) -> list[str]:
    """v1 left hands floating 2.9-4.0 units off a 1.33-unit forearm, which
    stretched the mesh into flat 'blade' shapes."""
    problems = []
    pairs = [("lowerarm.L", "hand.L"), ("lowerarm.R", "hand.R"),
             ("lowerleg.L", "foot.L"), ("lowerleg.R", "foot.R")]
    target_obj.animation_data.action = action
    worst = 0.0
    for frame in _sample_frames(action):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        for limb, end in pairs:
            gap = (target_obj.pose.bones[limb].tail - target_obj.pose.bones[end].head).length
            worst = max(worst, gap)
            if gap > tolerance:
                problems.append(f"frame {frame}: {end} is {gap:.2f} from {limb} tail")
    if not problems:
        print(f"    (largest limb gap {worst:.4f})")
    return problems


def check_no_spinning(target_obj, action, max_deg_per_frame=90.0) -> list[str]:
    """Directly targets the 'feet rotating like spinning around super fast'
    symptom: large frame-to-frame orientation jumps on the controls."""
    problems = []
    bones = ["foot_IK.L", "foot_IK.R", "hand_IK.L", "hand_IK.R", "foot.L", "foot.R"]
    target_obj.animation_data.action = action
    f0, f1 = (int(round(v)) for v in action.frame_range)
    previous = {}
    worst = (0.0, None, None)
    for frame in range(f0, f1 + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        for name in bones:
            pb = target_obj.pose.bones.get(name)
            if pb is None:
                continue
            q = pb.matrix.to_quaternion().normalized()
            if name in previous:
                delta = math.degrees(q.rotation_difference(previous[name]).angle)
                if delta > worst[0]:
                    worst = (delta, name, frame)
                if delta > max_deg_per_frame:
                    problems.append(f"{name} jumps {delta:.0f}deg at frame {frame}")
            previous[name] = q
    print(f"    (largest single-frame rotation {worst[0]:.1f}deg on {worst[1]} at frame {worst[2]})")
    return problems[:5]


def check_facing(target_obj, action, reference="walk", tolerance_deg=45.0) -> list[str]:
    """The dance should face the same way the character faces in walk/idle,
    not the way the Mixamo source happened to."""
    def forward(act):
        target_obj.animation_data.action = act
        bpy.context.scene.frame_set(int(round(act.frame_range[0])))
        bpy.context.view_layer.update()
        side = (target_obj.pose.bones["clav.L"].head - target_obj.pose.bones["clav.R"].head)
        side.z = 0.0
        if side.length < 1e-6:
            return None
        side.normalize()
        return side.cross((0.0, 0.0, 1.0))

    ref_action = bpy.data.actions.get(reference)
    if ref_action is None:
        return []
    a, b = forward(ref_action), forward(action)
    if a is None or b is None:
        return []
    diff = math.degrees(a.angle(b))
    print(f"    (facing differs from {reference!r} by {diff:.1f}deg)")
    return [] if diff <= tolerance_deg else [f"faces {diff:.0f}deg away from {reference!r}"]


def run_all(action_name: str, before_snapshot=None) -> bool:
    target = bpy.data.objects[P.TARGET_ARMATURE]
    action = bpy.data.actions[action_name]
    previous = target.animation_data.action if target.animation_data else None

    checks = [
        ("IK state untouched", lambda: check_ik_untouched(target)),
        ("no IK-owned bones written", lambda: check_untouched_bones(action)),
        ("limbs connected", lambda: check_limbs_connected(target, action)),
        ("no spinning", lambda: check_no_spinning(target, action)),
        ("facing matches walk", lambda: check_facing(target, action)),
    ]
    if before_snapshot is not None:
        checks.insert(0, ("existing actions untouched",
                          lambda: check_existing_untouched(before_snapshot, snapshot_actions())))

    failed = 0
    for label, fn in checks:
        problems = fn()
        if problems:
            failed += 1
            print(f"  FAIL  {label}")
            for p in problems[:4]:
                print(f"          {p}")
        else:
            print(f"  ok    {label}")

    if target.animation_data:
        target.animation_data.action = previous
    return failed == 0
