"""
Retarget ONE Mixamo FBX and verify it. Does not modify humanrig.blend.

    /Applications/Blender.app/Contents/MacOS/Blender -b models/blender/humanrig.blend \
      --python models/blender/mixamo_retarget/run_single.py -- "animations/source/Twist Dance.fbx"

Writes a preview .blend OUTSIDE the Godot project (Godot auto-imports
anything inside it, and the first attempt left a stray imported rig behind).
Pass --out to choose the location.
"""

import re
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))

import retarget          # noqa: E402
import rig_profile as P  # noqa: E402
import verify            # noqa: E402

DEFAULT_OUT_DIR = Path.home() / ".cache" / "studio-sim-dances"


def action_name_for(fbx_path) -> str:
    words = [w for w in re.split(r"[\s_\-]+", Path(fbx_path).stem) if w]
    return "Dance_" + "_".join(w.capitalize() for w in words)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        print("usage: ... --python run_single.py -- <file.fbx> [--out DIR]")
        sys.exit(1)

    fbx = Path(argv[0]).resolve()
    out_dir = DEFAULT_OUT_DIR
    if "--out" in argv:
        out_dir = Path(argv[argv.index("--out") + 1]).resolve()
    if not fbx.is_file():
        print(f"FAILED: {fbx}\nReason: file not found")
        sys.exit(1)

    name = action_name_for(fbx)
    print(f"Retargeting {fbx.name} -> {name}")

    # Fingerprint the hand-authored actions so we can prove we didn't touch them.
    before = verify.snapshot_actions()

    try:
        action = retarget.retarget_file(str(fbx), name)
    except retarget.RetargetError as e:
        print(f"FAILED: {fbx.name}\nReason: {e}")
        sys.exit(1)

    fps = bpy.context.scene.render.fps
    frames = action.frame_range[1] - action.frame_range[0] + 1
    print(f"OK: {name} ({int(action.frame_range[0])}-{int(action.frame_range[1])}, "
          f"{frames / fps:.2f}s at {fps}fps)")

    print("Verifying:")
    passed = verify.run_all(name, before_snapshot=before)

    # Preview convenience: make the new action active and widen the playback
    # range, so opening the file shows the whole dance instead of looping early
    # on whatever range the rig file happened to carry.
    target = bpy.data.objects[P.TARGET_ARMATURE]
    if target.animation_data is None:
        target.animation_data_create()
    target.animation_data.action = action
    scene = bpy.context.scene
    scene.frame_start = int(action.frame_range[0])
    scene.frame_end = int(action.frame_range[1])

    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "humanrig_dance_preview.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(out_path), copy=True)
    print(f"\nPreview: {out_path}")
    print("humanrig.blend was NOT modified.")
    if not passed:
        print("\nVERIFICATION FAILED -- do not merge this into humanrig.blend.")
        sys.exit(2)


if __name__ == "__main__":
    main()
