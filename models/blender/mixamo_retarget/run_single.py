"""
Phase 3: retarget exactly ONE Mixamo FBX onto the existing character, for
testing the pipeline before trusting it with a whole batch.

Usage:
  /Applications/Blender.app/Contents/MacOS/Blender -b models/blender/humanrig.blend \\
    --python models/blender/mixamo_retarget/run_single.py -- animations/source/disco.fbx

Safety: this NEVER overwrites the working models/blender/humanrig.blend.
It always saves to a sibling file, humanrig_dances_test.blend, so you can
open that in Blender, scrub the new Action, and confirm it looks right
before asking to have it merged into the real rig file.
"""
import re
import sys
from pathlib import Path

import bpy

THIS_DIR = Path(__file__).resolve().parent
if str(THIS_DIR) not in sys.path:
    sys.path.insert(0, str(THIS_DIR))

import retarget_core  # noqa: E402


def action_name_from_filename(fbx_path: str) -> str:
    stem = Path(fbx_path).stem
    words = re.split(r"[\s_\-]+", stem)
    words = [w for w in words if w]
    return "Dance_" + "_".join(w.capitalize() for w in words)


def main():
    argv = sys.argv
    if "--" not in argv:
        print("Usage: blender -b humanrig.blend --python run_single.py -- <path/to/file.fbx>")
        sys.exit(1)
    args = argv[argv.index("--") + 1:]
    if not args:
        print("Missing FBX path after --")
        sys.exit(1)
    fbx_path = str(Path(args[0]).resolve())
    if not Path(fbx_path).is_file():
        print(f"FAILED: {fbx_path}\nReason: file not found")
        sys.exit(1)

    action_name = action_name_from_filename(fbx_path)
    print(f"Retargeting {fbx_path} -> Action {action_name!r} ...")

    existing = bpy.data.actions.get(action_name)
    if existing is not None:
        print(f"FAILED: {fbx_path}\nReason: Action {action_name!r} already exists (duplicate) -- "
              f"delete it in Blender first if you want to redo this one.")
        sys.exit(1)

    try:
        action = retarget_core.retarget_one_file(fbx_path, action_name)
    except retarget_core.RetargetError as e:
        print(f"FAILED: {Path(fbx_path).name}\nReason: {e}")
        sys.exit(1)

    print(f"OK: created Action {action.name!r} "
          f"({int(action.frame_range[0])}-{int(action.frame_range[1])})")

    out_path = THIS_DIR.parent / "humanrig_dances_test.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(out_path), copy=True)
    print(f"Saved test output to {out_path} (models/blender/humanrig.blend was NOT modified).")
    print("Open that file in Blender, select Armature, and scrub the new Action to check it.")


if __name__ == "__main__":
    main()
