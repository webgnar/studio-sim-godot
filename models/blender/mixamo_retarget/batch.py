"""
Retarget every FBX in animations/source/ onto the rig.

    /Applications/Blender.app/Contents/MacOS/Blender -b models/blender/humanrig.blend \
      --python models/blender/mixamo_retarget/batch.py

Writes a preview .blend outside the Godot project. humanrig.blend is only
modified if you pass --commit, and even then only after every clip has passed
verification -- see README.md.

A clip that fails is reported and skipped; the rest of the batch continues.
"""

import json
import sys
import time
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))

import retarget          # noqa: E402
import rig_profile as P  # noqa: E402
import verify            # noqa: E402
from run_single import action_name_for, DEFAULT_OUT_DIR  # noqa: E402

PROJECT = Path(__file__).resolve().parents[3]
SOURCE_DIR = PROJECT / "animations" / "source"
MANIFEST = PROJECT / "animations" / "processed" / "manifest.json"


def load_manifest() -> dict:
    if MANIFEST.is_file():
        try:
            return json.loads(MANIFEST.read_text())
        except json.JSONDecodeError:
            print("  (manifest unreadable, treating everything as new)")
    return {}


def save_manifest(data: dict):
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    commit = "--commit" in argv
    force = "--force" in argv
    out_dir = DEFAULT_OUT_DIR
    if "--out" in argv:
        out_dir = Path(argv[argv.index("--out") + 1]).resolve()

    files = sorted(SOURCE_DIR.glob("*.fbx"))
    if not files:
        print(f"No FBX files in {SOURCE_DIR}")
        return

    manifest = load_manifest()
    baseline = verify.snapshot_actions()

    done, skipped, failed = [], [], []
    for path in files:
        name = action_name_for(path)
        stamp = f"{path.stat().st_mtime_ns}:{path.stat().st_size}"

        if not force and manifest.get(path.name, {}).get("stamp") == stamp \
                and name in bpy.data.actions:
            skipped.append(path.name)
            continue
        if name in bpy.data.actions and not force:
            # Same action name from a different file -- don't silently clobber.
            failed.append((path.name, f"action {name!r} already exists (use --force)"))
            continue

        print(f"\n>>> {path.name}")
        started = time.time()
        try:
            action = retarget.retarget_file(str(path), name)
        except Exception as e:   # keep the batch alive
            print(f"FAILED: {path.name}\nReason: {e}")
            failed.append((path.name, str(e)))
            continue

        if not verify.run_all(name, before_snapshot=baseline):
            print(f"FAILED: {path.name}\nReason: verification failed")
            failed.append((path.name, "verification failed"))
            bpy.data.actions.remove(action)
            continue

        manifest[path.name] = {"stamp": stamp, "action": name,
                               "frames": int(action.frame_range[1] - action.frame_range[0] + 1)}
        done.append(name)
        print(f"    ({time.time() - started:.0f}s)")

    print("\n" + "=" * 60)
    print(f"retargeted {len(done)}, skipped {len(skipped)} already done, failed {len(failed)}")
    for name in done:
        print(f"  ok      {name}")
    for name in skipped:
        print(f"  skip    {name}")
    for name, reason in failed:
        print(f"  FAILED  {name}: {reason}")

    if done:
        save_manifest(manifest)

    out_dir.mkdir(parents=True, exist_ok=True)
    preview = out_dir / "humanrig_dances.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(preview), copy=True)
    print(f"\nPreview: {preview}")

    if commit and not failed:
        bpy.ops.wm.save_mainfile()
        print(f"Committed into {bpy.data.filepath}")
    elif commit:
        print("NOT committed -- some clips failed. Fix them or drop them first.")
    else:
        print("humanrig.blend was NOT modified (pass --commit when you're happy).")


if __name__ == "__main__":
    main()
