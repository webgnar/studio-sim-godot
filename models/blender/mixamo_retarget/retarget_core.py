"""
Core Mixamo -> humanrig.blend retargeting logic.

Shared by run_single.py (Phase 3, one file at a time, for testing) and
batch_import.py (Phase 4). Deliberately has no side effects at import time
-- callers explicitly invoke import_fbx / retarget_one_file / etc.

Retarget method (see the plan doc's Phase 2 for the reasoning): direct FK
copy-rotation with a rest-pose delta, IK constraints disabled during the
bake, root motion stripped (rotation-only on the root bone, no translation
keys anywhere -- so every clip loops in place).

Implementation note that refines Phase 2 slightly: the plan's Phase 3
described a separate "snap IK targets to match deform bones" pass for
hand_IK/foot_IK/pole bones. Turns out that's unnecessary *and, if done
after the fact, actually wrong*: hand.L/foot.L are parented directly to
hand_IK.L/foot_IK.L, so Blender's `pose_bone.matrix` setter already bakes
in the parent's (rest, unanimated) transform when it computes hand.L's
matrix_basis. As long as hand_IK.L/foot_IK.L/the pole bones are simply
never touched (left fully unanimated), hand.L/foot.L land in exactly the
right place -- moving the IK target bones afterward would instead *shift
hand.L/foot.L away* from the pose we just computed. So: leave IK_TARGET_FOLLOWS
and POLE_TARGETS bones alone entirely. They're kept in bone_mapping.py as
documentation of the rig's control scheme, not because this module uses them.
"""

import bpy
from mathutils import Matrix

from bone_mapping import (
    BONE_MAP,
    ROOT_BONE,
    ROOT_SOURCE,
    REQUIRED_SOURCE_BONES,
)

TARGET_ARMATURE_NAME = "Armature"
MIXAMO_PREFIX = "mixamorig:"

# Bones whose IK constraint must be disabled during the bake so our direct
# pose_bone.matrix assignment on the FK chain isn't fought by the solver.
IK_CONSTRAINED_BONES = ["lowerarm.L", "lowerarm.R", "lowerleg.L", "lowerleg.R"]


class RetargetError(Exception):
    """Raised for problems that should abort a single file (batch continues)."""


# ---------------------------------------------------------------------------
# Import / discovery
# ---------------------------------------------------------------------------

def import_fbx(filepath: str):
    """Import a Mixamo FBX and return (armature_obj, all_imported_objects)."""
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.fbx(filepath=filepath, automatic_bone_orientation=False)
    after = set(bpy.data.objects.keys())
    new_names = after - before
    imported = [bpy.data.objects[n] for n in new_names]
    if not imported:
        raise RetargetError(f"FBX import produced no new objects: {filepath}")

    armatures = [o for o in imported if o.type == 'ARMATURE']
    if not armatures:
        raise RetargetError(f"No armature found in imported FBX: {filepath}")
    if len(armatures) > 1:
        # Not fatal -- just take the first and warn via the return value's
        # caller, since some FBX exports include stray extra empties.
        print(f"  (note) multiple armatures found in {filepath}, using {armatures[0].name!r}")

    return armatures[0], imported


def resolve_source_bone_name(source_armature, base_name: str):
    """Match a bone_mapping.py base name against the imported armature's
    actual pose bones, trying the mixamorig: prefix, the bare name, and a
    case-insensitive scan, in that order. Returns None if not found."""
    pose_bones = source_armature.pose.bones
    for candidate in (MIXAMO_PREFIX + base_name, base_name):
        if candidate in pose_bones:
            return candidate
    lowered = base_name.lower()
    for name in pose_bones.keys():
        stripped = name[len(MIXAMO_PREFIX):] if name.startswith(MIXAMO_PREFIX) else name
        if stripped.lower() == lowered:
            return name
    return None


def build_bone_map(source_armature):
    """Resolve BONE_MAP + ROOT_BONE against the actual imported armature.

    Returns (resolved: dict[target_name -> list[source_name]], warnings: list[str]).
    Raises RetargetError if a REQUIRED_SOURCE_BONES entry can't be found at all.
    """
    warnings = []

    missing_required = [
        b for b in REQUIRED_SOURCE_BONES
        if resolve_source_bone_name(source_armature, b) is None
    ]
    if missing_required:
        raise RetargetError(
            f"Missing required source bone(s): {', '.join(missing_required)} "
            f"(source armature has: {sorted(source_armature.pose.bones.keys())[:10]}...)"
        )

    resolved = {}
    for target_bone, source_bases in BONE_MAP.items():
        found = []
        for base in source_bases:
            match = resolve_source_bone_name(source_armature, base)
            if match:
                found.append(match)
            else:
                warnings.append(
                    f"target bone {target_bone!r}: source bone {base!r} not found, "
                    f"skipping that contribution (bone stays partially/fully at rest)"
                )
        if found:
            resolved[target_bone] = found

    root_match = resolve_source_bone_name(source_armature, ROOT_SOURCE)
    if root_match:
        resolved[ROOT_BONE] = [root_match]
    else:
        warnings.append(f"root bone {ROOT_SOURCE!r} not found, {ROOT_BONE!r} stays at rest")

    return resolved, warnings


# ---------------------------------------------------------------------------
# Retargeting math
# ---------------------------------------------------------------------------

def _rest_matrix(pose_bone) -> Matrix:
    """Armature-space rest matrix for a pose bone's underlying Bone."""
    return pose_bone.bone.matrix_local.copy()


def _rotation_delta(pose_bone) -> Matrix:
    """How far a pose bone has rotated from its own rest orientation, expressed
    in its own rest-local frame: rest^-1 @ posed. Translation/scale dropped --
    we only ever transplant rotation."""
    rest = _rest_matrix(pose_bone)
    posed = pose_bone.matrix.copy()
    delta = rest.inverted() @ posed
    # Strip translation/scale, keep rotation only, to avoid dragging along
    # any source-rig scale/offset quirks onto the target's rest translation.
    return delta.to_quaternion().to_matrix().to_4x4()


def _target_bone_depth(target_armature, bone_name: str) -> int:
    depth = 0
    b = target_armature.data.bones[bone_name]
    while b.parent is not None:
        depth += 1
        b = b.parent
    return depth


def _set_ik_influence(target_armature, value: float):
    for bone_name in IK_CONSTRAINED_BONES:
        pb = target_armature.pose.bones.get(bone_name)
        if not pb:
            continue
        for c in pb.constraints:
            if c.type == 'IK':
                c.influence = value


# ---------------------------------------------------------------------------
# Main retarget + bake
# ---------------------------------------------------------------------------

def retarget_action(source_armature, action_name: str, target_armature=None):
    """Retarget the action currently assigned to source_armature onto a new
    Action on target_armature (defaults to the 'Armature' object), baked
    frame-by-frame. Returns the new bpy.types.Action.
    """
    if target_armature is None:
        target_armature = bpy.data.objects[TARGET_ARMATURE_NAME]

    if not source_armature.animation_data or not source_armature.animation_data.action:
        raise RetargetError("Imported armature has no Action to retarget")
    source_action = source_armature.animation_data.action

    resolved_map, warnings = build_bone_map(source_armature)
    for w in warnings:
        print(f"  warning: {w}")

    frame_start = int(round(source_action.frame_range[0]))
    frame_end = int(round(source_action.frame_range[1]))
    if frame_end <= frame_start:
        raise RetargetError(f"Degenerate frame range {source_action.frame_range}")

    # New Action + assign it to the target so keyframe_insert() lands here.
    new_action = bpy.data.actions.new(name=action_name)
    if target_armature.animation_data is None:
        target_armature.animation_data_create()
    previous_action = target_armature.animation_data.action
    target_armature.animation_data.action = new_action

    _set_ik_influence(target_armature, 0.0)

    # Parent-before-child so each bone's parent (if also mapped) already has
    # this frame's pose set before we compute the child's basis.
    ordered_targets = sorted(resolved_map.keys(), key=lambda n: _target_bone_depth(target_armature, n))

    scene = bpy.context.scene
    try:
        for frame in range(frame_start, frame_end + 1):
            scene.frame_set(frame)
            for target_name in ordered_targets:
                source_names = resolved_map[target_name]
                target_pb = target_armature.pose.bones.get(target_name)
                if target_pb is None:
                    continue

                composed_delta = Matrix.Identity(4)
                for source_name in source_names:
                    source_pb = source_armature.pose.bones[source_name]
                    composed_delta = composed_delta @ _rotation_delta(source_pb)

                target_pb.matrix = _rest_matrix(target_pb) @ composed_delta
                target_pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)
    finally:
        _set_ik_influence(target_armature, 1.0)
        target_armature.animation_data.action = previous_action

    return new_action


def cleanup_import(imported_objects):
    """Remove the temporary Mixamo mesh/armature/action data after a
    successful (or failed) retarget, so nothing from the source file
    lingers in the .blend."""
    actions_to_check = set()
    for obj in imported_objects:
        if obj.animation_data and obj.animation_data.action:
            actions_to_check.add(obj.animation_data.action)
        try:
            bpy.data.objects.remove(obj, do_unlink=True)
        except ReferenceError:
            pass  # already removed as another object's child data
    for action in actions_to_check:
        if action.users == 0:
            bpy.data.actions.remove(action)
    # Orphaned meshes/armature data-blocks left behind by object removal.
    for mesh in [m for m in bpy.data.meshes if m.users == 0]:
        bpy.data.meshes.remove(mesh)
    for arm_data in [a for a in bpy.data.armatures if a.users == 0]:
        bpy.data.armatures.remove(arm_data)


def retarget_one_file(filepath: str, action_name: str, target_armature=None):
    """Full pipeline for one FBX: import, retarget, bake, cleanup.
    Raises RetargetError (or lets FBX-import exceptions surface) on failure --
    callers (run_single.py / batch_import.py) decide whether that aborts or
    just logs and continues."""
    armature_obj, imported_objects = import_fbx(filepath)
    try:
        action = retarget_action(armature_obj, action_name, target_armature=target_armature)
    finally:
        cleanup_import(imported_objects)
    return action
