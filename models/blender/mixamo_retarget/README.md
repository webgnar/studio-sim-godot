# Mixamo Dance Retargeting

Turns Mixamo FBX animations into native Blender Actions on the `humanrig`
character, without touching the mesh, weights, rig, or any existing action.

## Use it

1. Download animations from Mixamo as **FBX Binary** (skin doesn't matter,
   only the animation is used) into `animations/source/`.
2. Run:
   ```
   /Applications/Blender.app/Contents/MacOS/Blender -b models/blender/humanrig.blend \
     --python models/blender/mixamo_retarget/batch.py
   ```
3. Open the preview it prints (`~/.cache/studio-sim-dances/humanrig_dances.blend`),
   select `Armature`, and scrub the new `Dance_*` actions.
4. Happy with them? Re-run with `--commit` to write them into
   `models/blender/humanrig.blend`, then let Godot reimport.

`run_single.py` does one file at a time, same arguments, for iterating.
Re-running skips clips already processed (tracked in
`animations/processed/manifest.json`); `--force` redoes them.

Previews are written **outside** the Godot project on purpose — anything
inside gets auto-imported as a second rig resource.

## How it drives the rig (important)

This rig is animated through **IK controls**, not FK. Measured from `walk`:
`upperarm`/`lowerarm`/`upperleg`/`lowerleg` have a rotation spread of exactly
`0.000`, while `hand_IK` moves `1.653` and `foot_IK` moves `3.715`. The limbs
are solved live by the IK constraints.

So retargeting writes only what a hand-authored action writes:

| channel | bones |
|---|---|
| position | `torso`, `hand_IK.L/R`, `foot_IK.L/R`, `ArmTarget.L/R`, `LegTarget.L/R` |
| rotation | `hip`, `spine`, `chest`, `head`, `hand.L/R`, `foot.L/R`, `foot.*.001` |
| never | `Main`, `clav.*`, the four limb bones, `neck`, `chest_breath`, and **any IK constraint influence** |

**Do not "fix" this by writing FK rotations onto the limbs and switching IK
off.** That was the first attempt. IK influence is rig-wide state, so
disabling it leaks into every other action and strips the hands and feet off
`walk`, `idle`, and `sit`.

Scale (~2.4x) and facing (~180°) are measured per file from limb lengths and
the shoulder axis, never hardcoded. IK targets are clamped to the limb's
reach, because some source poses put a hand further out than this rig's arm
can span and the hand would otherwise detach from the wrist.

## Verification

`verify.py` runs after every clip, and the batch refuses to keep a clip that
fails. Each check exists because the first attempt shipped that exact bug:

| check | catches |
|---|---|
| existing actions untouched | the regression that broke `walk`/`idle`/`sit` |
| IK state untouched | influence being changed or keyframed |
| no IK-owned bones written | diverging from the rig's convention |
| limbs connected | hands/feet detaching and stretching the mesh |
| no spinning | wild frame-to-frame rotation on the controls |
| facing matches `walk` | dances coming out backwards |

Measure first. The first attempt lost hours to rendering frames and guessing;
every one of those bugs was a one-command measurement away.

## Known simplifications

- Dances are **in place** — horizontal travel is dropped, vertical bob kept.
- Frames are copied 1:1, so a 30fps Mixamo clip runs ~25% slower at the
  project's 24fps. Fine so far; resample in `retarget.py` if it ever matters.
- `neck` and `clav` stay at rest, matching the existing actions.
