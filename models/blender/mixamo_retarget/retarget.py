"""
Mixamo -> humanrig.blend retargeting, driving the rig's IK controls.

Read rig_profile.py first -- it documents the measured convention this
follows. Nothing here touches IK constraint influence, the limb bones, the
mesh, weights, or any existing action.

Pipeline per clip: import -> fit the source onto the rig (uniform scale,
facing, hip anchor) -> per frame, write rotations onto the rotation-driven
bones and world positions onto the IK controls and poles -> clean up.
"""

import math

import bpy
from mathutils import Matrix, Quaternion, Vector

import rig_profile as P


class RetargetError(Exception):
    """Aborts one clip. The batch logs it and carries on."""


# ---------------------------------------------------------------------------
# import / naming
# ---------------------------------------------------------------------------

def import_fbx(filepath: str):
    """Import a Mixamo FBX; returns (armature_obj, all_imported_objects)."""
    before = set(bpy.data.objects.keys())

    # The importer overwrites scene fps with the source's (Mixamo is 30, this
    # project is 24). That setting would persist into any saved file and make
    # every EXISTING action play ~25% fast after reimport, so restore it.
    scene = bpy.context.scene
    fps, fps_base = scene.render.fps, scene.render.fps_base
    try:
        bpy.ops.import_scene.fbx(filepath=filepath, automatic_bone_orientation=False)
    finally:
        scene.render.fps, scene.render.fps_base = fps, fps_base

    imported = [bpy.data.objects[n] for n in set(bpy.data.objects.keys()) - before]
    armatures = [o for o in imported if o.type == 'ARMATURE']
    if not armatures:
        raise RetargetError(f"no armature in {filepath}")
    return armatures[0], imported


def source_bone(source_obj, base_name: str):
    """Find a Mixamo bone, tolerating the prefix being present or not."""
    bones = source_obj.pose.bones
    for candidate in (P.MIXAMO_PREFIX + base_name, base_name):
        if candidate in bones:
            return bones[candidate]
    lowered = base_name.lower()
    for pb in bones:
        name = pb.name[len(P.MIXAMO_PREFIX):] if pb.name.startswith(P.MIXAMO_PREFIX) else pb.name
        if name.lower() == lowered:
            return pb
    return None


# ---------------------------------------------------------------------------
# geometry helpers (all world space, convention-free)
# ---------------------------------------------------------------------------

def _head(obj, pb) -> Vector:
    return obj.matrix_world @ pb.head


def _tail(obj, pb) -> Vector:
    return obj.matrix_world @ pb.tail


def _bone_length(obj, pb) -> float:
    return (_tail(obj, pb) - _head(obj, pb)).length


def _rest_world_quat(obj, pb) -> Quaternion:
    return (obj.matrix_world @ pb.bone.matrix_local).to_quaternion().normalized()


def _clear_pose(obj):
    for pb in obj.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)


# ---------------------------------------------------------------------------
# fitting the source onto the rig
# ---------------------------------------------------------------------------

def fit_source(source_obj, target_obj):
    """Scale, yaw and position the imported rig so its bones land where the
    equivalent bones of ours do. Returns a dict of what it did, for logging.

    All three corrections are measured from the two rigs, never hardcoded:
    a Mixamo rig is ~2.4x smaller than this one and faces the opposite way,
    and the first attempt's hardcoded guesses were wrong (~4.9x).
    """
    _clear_pose(source_obj)
    _clear_pose(target_obj)
    bpy.context.view_layer.update()

    # --- uniform scale from limb lengths ---
    ratios = []
    for target_names, source_names in P.SCALE_LIMBS:
        t_len = sum(_bone_length(target_obj, target_obj.pose.bones[n]) for n in target_names)
        s_bones = [source_bone(source_obj, n) for n in source_names]
        if any(b is None for b in s_bones):
            continue
        s_len = sum(_bone_length(source_obj, b) for b in s_bones)
        if s_len > 1e-6:
            ratios.append(t_len / s_len)
    if not ratios:
        raise RetargetError("could not measure limb lengths to derive scale")
    scale = sum(ratios) / len(ratios)
    source_obj.scale = source_obj.scale * scale

    # --- facing, from the shoulder axis (a horizontal axis, so yaw shows up
    # clearly in it; spine/leg bones are near-vertical and barely move) ---
    (t_l, t_r), (s_l, s_r) = P.SHOULDER_PAIR
    bpy.context.view_layer.update()
    t_side = (_head(target_obj, target_obj.pose.bones[t_l])
              - _head(target_obj, target_obj.pose.bones[t_r]))
    s_side = (_head(source_obj, source_bone(source_obj, s_l))
              - _head(source_obj, source_bone(source_obj, s_r)))
    t_side.z = s_side.z = 0.0
    yaw = 0.0
    if t_side.length > 1e-6 and s_side.length > 1e-6:
        t_side.normalize()
        s_side.normalize()
        yaw = math.atan2(
            s_side.x * t_side.y - s_side.y * t_side.x,   # cross z
            s_side.x * t_side.x + s_side.y * t_side.y,   # dot
        )
        source_obj.rotation_euler.z += yaw
    bpy.context.view_layer.update()

    # --- anchor the hips together so world positions are directly usable ---
    t_hip, s_hip = P.HIP_ANCHOR
    offset = (_head(target_obj, target_obj.pose.bones[t_hip])
              - _head(source_obj, source_bone(source_obj, s_hip)))
    source_obj.location = source_obj.location + offset
    bpy.context.view_layer.update()

    return {"scale": scale, "yaw_deg": math.degrees(yaw)}


# ---------------------------------------------------------------------------
# rotation transfer
# ---------------------------------------------------------------------------

def _local_rotation(pb) -> Quaternion:
    """A bone's own rotation relative to its rest, independent of its parent
    and of rotation_mode. Do NOT derive this from armature-space matrices:
    for a bone whose parent is also animated that folds in every ancestor's
    rotation and compounds down the chain."""
    return pb.matrix_basis.to_quaternion().normalized()


def _basis_correction(source_obj, source_pb, target_obj, target_pb) -> Quaternion:
    """Maps a rotation expressed in the source bone's local frame into the
    target bone's. The two rigs disagree about both rest orientation and axis
    convention, so a local rotation copied across verbatim turns about the
    wrong axes. Only meaningful once fit_source() has aligned the rigs."""
    s = _rest_world_quat(source_obj, source_pb)
    t = _rest_world_quat(target_obj, target_pb)
    return (t.inverted() @ s).normalized()


def _convert(local_rot: Quaternion, correction: Quaternion) -> Quaternion:
    return (correction @ local_rot @ correction.inverted()).normalized()


# ---------------------------------------------------------------------------
# pole placement
# ---------------------------------------------------------------------------

def _pole_position(source_obj, root_pb, joint_pb, tip_pb) -> Vector:
    """Where to put an elbow/knee pole: out along the direction the joint
    actually bends, measured from the straight root->tip line. Pushing it out
    (rather than sitting it on the joint) keeps the solve stable when the limb
    straightens and the joint sits nearly on that line."""
    root = _head(source_obj, root_pb)
    joint = _head(source_obj, joint_pb)
    tip = _head(source_obj, tip_pb)

    axis = tip - root
    length = axis.length
    if length < 1e-6:
        return joint
    axis = axis / length

    # component of root->joint perpendicular to the root->tip line
    bend = (joint - root) - axis * (joint - root).dot(axis)
    if bend.length < 1e-5:
        # Limb is straight: no reliable bend direction this frame. Fall back to
        # the joint itself; the caller's continuity check will catch it if this
        # ever produces a visible flip.
        return joint
    return joint + bend.normalized() * length * P.POLE_DISTANCE


# ---------------------------------------------------------------------------
# the bake
# ---------------------------------------------------------------------------

def _clamp_to_reach(target_obj, control_name: str, world_pos: Vector) -> Vector:
    """Pull an IK target in if it's placed further from the limb's root than
    the limb can span. Without this the solver stops short and the hand or
    foot -- which is parented to the control, not the limb -- detaches from
    the wrist/ankle and the skinned mesh stretches between the two."""
    limit = P.REACH_LIMITS.get(control_name)
    if limit is None:
        return world_pos
    root_name, chain = limit
    root_pb = target_obj.pose.bones.get(root_name)
    if root_pb is None:
        return world_pos
    reach = sum(target_obj.pose.bones[n].length for n in chain
                if n in target_obj.pose.bones) * P.REACH_MARGIN
    root = _head(target_obj, root_pb)
    offset = world_pos - root
    if offset.length <= reach or offset.length < 1e-9:
        return world_pos
    return root + offset.normalized() * reach


def _set_world_head(target_obj, pb, world_pos: Vector):
    """Move a bone so its head sits at a world position, leaving orientation."""
    m = pb.matrix.copy()
    m.translation = target_obj.matrix_world.inverted() @ world_pos
    pb.matrix = m


def retarget_action(source_obj, action_name: str, target_obj=None):
    """Build a new Action on the target from the source's current action."""
    if target_obj is None:
        target_obj = bpy.data.objects[P.TARGET_ARMATURE]
    if not (source_obj.animation_data and source_obj.animation_data.action):
        raise RetargetError("imported armature has no action")

    missing = [b for b in P.REQUIRED_SOURCE_BONES if source_bone(source_obj, b) is None]
    if missing:
        raise RetargetError(f"missing required source bone(s): {', '.join(missing)}")

    src_action = source_obj.animation_data.action
    f0, f1 = (int(round(v)) for v in src_action.frame_range)
    if f1 <= f0:
        raise RetargetError(f"degenerate frame range {tuple(src_action.frame_range)}")

    fit = fit_source(source_obj, target_obj)
    print(f"  fit: scale x{fit['scale']:.3f}, yaw {fit['yaw_deg']:+.1f}deg")

    # New action. Without a fake user it has zero users the moment we restore
    # the previous one below, and is silently purged as an orphan on save.
    action = bpy.data.actions.new(name=action_name)
    action.use_fake_user = True
    if target_obj.animation_data is None:
        target_obj.animation_data_create()
    previous = target_obj.animation_data.action
    target_obj.animation_data.action = action

    warnings = []

    # Resolve the plan once; anything unresolvable just stays at rest.
    rotations = []   # (target_pb, [(source_pb, correction)])
    for target_name, source_names in P.ROTATION_MAP.items():
        tpb = target_obj.pose.bones.get(target_name)
        if tpb is None:
            continue
        pairs = []
        for sname in source_names:
            spb = source_bone(source_obj, sname)
            if spb is None:
                warnings.append(f"{target_name}: no source bone {sname!r}, staying at rest")
                continue
            pairs.append((spb, _basis_correction(source_obj, spb, target_obj, tpb)))
        if pairs:
            rotations.append((tpb, pairs))

    positions = []   # (target_pb, source_pb)
    for target_name, sname in P.POSITION_MAP.items():
        tpb = target_obj.pose.bones.get(target_name)
        spb = source_bone(source_obj, sname)
        if tpb is None or spb is None:
            warnings.append(f"{target_name}: no source bone {sname!r}, staying at rest")
            continue
        positions.append((tpb, spb))

    poles = []       # (target_pb, root_pb, joint_pb, tip_pb)
    for target_name, (root, joint, tip) in P.POLE_MAP.items():
        tpb = target_obj.pose.bones.get(target_name)
        bones = [source_bone(source_obj, n) for n in (root, joint, tip)]
        if tpb is None or any(b is None for b in bones):
            warnings.append(f"{target_name}: pole chain incomplete, staying at rest")
            continue
        poles.append((tpb, *bones))

    trans_pb = target_obj.pose.bones.get(P.TRANSLATION_BONE)
    trans_src = source_bone(source_obj, P.TRANSLATION_SOURCE)
    trans_rest = _head(target_obj, trans_pb) if trans_pb else None

    for w in warnings:
        print(f"  warning: {w}")

    # Start from a clean rest pose so bones we never write contribute nothing
    # left over from whatever pose the file was saved in.
    for pb in target_obj.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
        pb.rotation_mode = 'QUATERNION'
    bpy.context.view_layer.update()

    scene = bpy.context.scene
    try:
        for frame in range(f0, f1 + 1):
            scene.frame_set(frame)

            # 1. rotations (pure local values -- no ordering requirement)
            for tpb, pairs in rotations:
                q = Quaternion((1.0, 0.0, 0.0, 0.0))
                for spb, correction in pairs:
                    q = q @ _convert(_local_rotation(spb), correction)
                tpb.rotation_quaternion = q.normalized()
                tpb.keyframe_insert("rotation_quaternion", frame=frame)

            # 2. body translation, horizontal component dropped to stay in place
            if trans_pb and trans_src:
                target_pos = trans_rest.copy()
                if P.KEEP_VERTICAL_TRANSLATION:
                    target_pos.z = _head(source_obj, trans_src).z
                _set_world_head(target_obj, trans_pb, target_pos)
                trans_pb.keyframe_insert("location", frame=frame)

            bpy.context.view_layer.update()

            # 3. IK controls and poles, in world space
            for tpb, spb in positions:
                wanted = _clamp_to_reach(target_obj, tpb.name, _head(source_obj, spb))
                _set_world_head(target_obj, tpb, wanted)
                tpb.keyframe_insert("location", frame=frame)
            for tpb, root_pb, joint_pb, tip_pb in poles:
                _set_world_head(target_obj, tpb,
                                _pole_position(source_obj, root_pb, joint_pb, tip_pb))
                tpb.keyframe_insert("location", frame=frame)
            bpy.context.view_layer.update()
    finally:
        target_obj.animation_data.action = previous

    return action


# ---------------------------------------------------------------------------
# cleanup
# ---------------------------------------------------------------------------

def cleanup(imported_objects):
    """Delete everything the import brought in."""
    actions = set()
    for obj in imported_objects:
        if obj.animation_data and obj.animation_data.action:
            actions.add(obj.animation_data.action)
        try:
            bpy.data.objects.remove(obj, do_unlink=True)
        except ReferenceError:
            pass
    for action in actions:
        # FBX import sets a fake user on the action, which alone keeps users
        # at 1 forever -- clear it or the removal below silently no-ops and
        # the source action lingers in the file.
        action.use_fake_user = False
        if action.users == 0:
            bpy.data.actions.remove(action)
    for mesh in [m for m in bpy.data.meshes if m.users == 0]:
        bpy.data.meshes.remove(mesh)
    for arm in [a for a in bpy.data.armatures if a.users == 0]:
        bpy.data.armatures.remove(arm)


def retarget_file(filepath: str, action_name: str, target_obj=None):
    source_obj, imported = import_fbx(filepath)
    try:
        return retarget_action(source_obj, action_name, target_obj=target_obj)
    finally:
        cleanup(imported)
