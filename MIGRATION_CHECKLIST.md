# Migration Checklist - Converting Existing Objects to Dual Interaction

## Overview
This checklist helps you convert existing `InteractionComponent` objects to the new `CarryableInteractableComponent` system.

---

## Pre-Migration Assessment

### Which objects should be converted?

| Object Type | Should Convert? | Use Component |
|-------------|----------------|---------------|
| Static (switches, buttons) | ❌ No | Keep `InteractionComponent` |
| Props you want to carry | ✅ Yes | `CarryableComponent` |
| Interactive + Carryable | ✅ Yes | `CarryableInteractableComponent` |

**Examples:**
- Light switch → ❌ Keep as is (static)
- Empty box → ✅ Convert to `CarryableComponent`
- **Boombox → ✅ Convert to `CarryableInteractableComponent`**
- **Fan → ✅ Convert to `CarryableInteractableComponent`**
- Door → ❌ Keep as is (static)

---

## Your Current Interactive Objects

Based on your workspace, these objects likely need conversion:

### Confirmed Interactive Objects:
1. ✅ **Boombox** - `scripts/BoomboxInteraction.gd`
   - Should be carryable + toggle-able
   - Use `CarryableInteractableComponent`
   
2. ✅ **Artbox** - `scripts/ArtboxInteraction.gd`
   - Should be carryable + open-able
   - Use `CarryableInteractableComponent`

3. ✅ **Box** - `scripts/BoxInteraction.gd`
   - Should be carryable + open-able
   - Use `CarryableInteractableComponent`

4. ❌ **Light Switch** - `scripts/LightSwitchInteraction.gd`
   - Keep as is (wall-mounted, static)
   - Keep `InteractionComponent`

5. ❌ **Mirror** - `scenes/mirror_2.gd`
   - Keep as is (static)
   - Keep current implementation

---

## Step-by-Step Migration

### STEP 1: Backup Current Setup
```bash
# In your terminal:
cd /Users/zackgg/Godot/studio-sim-godot
git add .
git commit -m "Backup before dual interaction migration"
```

### STEP 2: Choose Object to Convert

Pick ONE object to start with (recommended: Boombox)

### STEP 3: Modify Scene Structure

**Current Structure (InteractionComponent):**
```
BoomBox (Node3D or StaticBody3D)
├── MeshInstance3D
├── CollisionShape3D (if StaticBody3D)
└── BoomboxInteraction (script)
```

**New Structure (CarryableInteractableComponent):**
```
BoomBox (RigidBody3D)  ← MUST CHANGE TO RigidBody3D
├── MeshInstance3D
├── CollisionShape3D
├── AudioStreamPlayer3D
└── BoomboxInteractionDual (new script)
```

**How to change:**
1. Open scene in Godot
2. Right-click root node → "Change Type"
3. Search for "RigidBody3D"
4. Select and confirm
5. **IMPORTANT:** Re-add children if they were removed

### STEP 4: Configure RigidBody3D Properties

In Inspector, set:
```
RigidBody3D:
├── Mass: 2.0 - 5.0 (for boombox)
├── Gravity Scale: 1.0
├── Lock Rotation: false (let it tumble naturally)
├── Continuous CD: false (enable for fast objects)
└── Collision Layer: 4 (Interactables)
    Collision Mask: 2 (Static World)
```

### STEP 5: Update Script

**Option A: Use Pre-Made Script**
- Swap to `BoomboxInteractionDual.gd` (already created in `scripts/examples/`)

**Option B: Convert Your Current Script**

```gdscript
# BEFORE
extends InteractionComponent
class_name BoomboxInteraction

func _on_ready() -> void:
    interaction_text = "Turn On Radio"
    # ... setup code

func _on_interacted(player: PlayerInteractionComponent) -> void:
    _toggle_radio()

# AFTER
extends CarryableInteractableComponent
class_name BoomboxInteraction

func _ready() -> void:  # Note: _on_ready becomes _ready
    can_interact_while_carried = true  # NEW!
    e_key_interaction_text = "Turn On Radio"  # NEW!
    super._ready()  # NEW! Must call parent
    
    # ... same setup code

func _on_e_key_interacted(player: PlayerInteractionComponent) -> void:  # RENAMED!
    _toggle_radio()
    # Update e_key_interaction_text when state changes
    e_key_interaction_text = "Turn Off Radio"  # Example
    _update_interaction_text()  # NEW! Updates prompt
```

**Key Changes:**
1. Extend `CarryableInteractableComponent` instead of `InteractionComponent`
2. Add `can_interact_while_carried = true/false` in `_ready()`
3. Set `e_key_interaction_text` instead of `interaction_text`
4. Call `super._ready()` in `_ready()`
5. Rename `_on_interacted()` → `_on_e_key_interacted()`
6. Call `_update_interaction_text()` when state changes

### STEP 6: Test Migration

**Test Plan:**
1. ✅ Load scene in editor - no errors
2. ✅ Run game and approach object
3. ✅ Verify prompt shows: `[Click] Pick Up | [E] Turn On Radio`
4. ✅ Left-click → Object is picked up
5. ✅ E-key (while carrying) → Radio toggles
6. ✅ Left-click (while carrying) → Object is thrown
7. ✅ E-key (not carrying) → Radio toggles

**If any fail, see Troubleshooting below**

### STEP 7: Fine-Tune Settings

Adjust in Inspector:
```
CarryableInteractableComponent:
├── Carry Distance Offset: 0.0 (adjust if too close/far)
├── Carry Smoothness: 10.0 (higher = snappier)
├── Lock Rotation When Carried: true (prevent tumbling)
├── Throw Power: 15.0 (adjust for desired throw distance)
└── E-Key Interaction Sound: [Optional audio file]
```

### STEP 8: Repeat for Other Objects

Once first object works, repeat for:
- [ ] Artbox
- [ ] Box
- [ ] Any other interactive props

---

## Object-Specific Migration Notes

### Boombox
- **Mass:** 3.0 - 5.0 kg (portable but substantial)
- **Can interact while carried:** `true` (toggle radio anytime)
- **Throw power:** 12.0 (moderate)
- **Special:** Audio should continue playing when carried

### Artbox
- **Mass:** 1.0 - 2.0 kg (lightweight)
- **Can interact while carried:** `false` (must set down to open)
- **Throw power:** 15.0 (light object, throws far)

### Box
- **Mass:** 2.0 - 3.0 kg (standard)
- **Can interact while carried:** `false` (must set down to open)
- **Throw power:** 15.0

---

## Troubleshooting

### Object won't pick up
**Check:**
- [ ] Parent is RigidBody3D (not Node3D or StaticBody3D)
- [ ] Script extends CarryableInteractableComponent
- [ ] Object has collision shape
- [ ] Mass is > 0

### E-key doesn't interact
**Check:**
- [ ] Implemented `_on_e_key_interacted()` method
- [ ] Set `e_key_interaction_text` in `_ready()`
- [ ] Called `super._ready()` before your code

### Object falls through floor
**Check:**
- [ ] Floor has collision (StaticBody3D + CollisionShape3D)
- [ ] Object collision layer is 4
- [ ] Floor collision layer is 2

### Object flies away when dropped
**Check:**
- [ ] Reduce `throw_power` in component
- [ ] Enable `lock_rotation_when_carried`
- [ ] Reduce `carry_smoothness`

### Prompt doesn't update
**Check:**
- [ ] Call `_update_interaction_text()` after changing `e_key_interaction_text`
- [ ] PlayerInteractionComponent `interaction_prompt_changed` signal is connected to HUD

---

## Rollback Plan

If migration fails:

1. **Git restore:**
   ```bash
   git checkout -- scripts/YourScript.gd
   git checkout -- scenes/your_scene.tscn
   ```

2. **Manual restore:**
   - Change RigidBody3D back to original type
   - Swap script back to original
   - Save scene

---

## Success Criteria

Migration is complete when:

- [x] Object has RigidBody3D parent
- [x] Script extends CarryableInteractableComponent
- [x] Left-click picks up object
- [x] E-key triggers interaction
- [x] Left-click (while carrying) throws object
- [x] Prompts display correctly
- [x] No console errors
- [x] Physics behaves naturally

---

## Quick Reference

### Conversion Summary Table

| Before | After |
|--------|-------|
| `extends InteractionComponent` | `extends CarryableInteractableComponent` |
| `func _on_ready()` | `func _ready()` + `super._ready()` |
| `func _on_interacted(player)` | `func _on_e_key_interacted(player)` |
| `interaction_text = "..."` | `e_key_interaction_text = "..."` |
| Node3D/StaticBody3D parent | RigidBody3D parent |
| No physics properties | Configure mass, friction, etc. |

---

## Next Object to Migrate

**Recommended order:**
1. ✅ Boombox (has example script already)
2. → Box (simple open/close)
3. → Artbox (similar to box)
4. → Any custom objects

Start with Boombox since `BoomboxInteractionDual.gd` is already created!

