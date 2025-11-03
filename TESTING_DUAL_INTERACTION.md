# Testing the Dual Interaction System

## Quick Test Setup

### Test Object 1: Simple Radio (Interactive Carryable)

**Scene Structure:**
```
TestRadio (RigidBody3D)
├── MeshInstance3D (box or radio model)
├── CollisionShape3D (box shape)
├── AudioStreamPlayer3D
│   └── [Assign your audio file]
└── RadioInteraction (script)
```

**Steps:**
1. Create new scene → Root node: RigidBody3D
2. Name it "TestRadio"
3. Add MeshInstance3D child → Use BoxMesh or import radio model
4. Add CollisionShape3D child → BoxShape3D matching mesh
5. Add AudioStreamPlayer3D child
6. Add script → Select "RadioInteraction.gd"
7. In Inspector:
   - **RigidBody3D:** Set mass to 2.0
   - **AudioStreamPlayer3D:** Assign an audio file
   - **RadioInteraction:** Link AudioStreamPlayer3D
8. Save scene as `test_radio.tscn`

**Expected Behavior:**
- Left click → Pick up radio
- E key → Toggle audio on/off (while carrying or not)
- Left click (while carrying) → Throw radio
- Audio should play from radio's position in 3D space

---

### Test Object 2: Simple Box (Carryable Only)

**Scene Structure:**
```
TestBox (RigidBody3D)
├── MeshInstance3D (box)
├── CollisionShape3D (box shape)
└── CarryableComponent (script)
```

**Steps:**
1. Create new scene → Root node: RigidBody3D
2. Name it "TestBox"
3. Add MeshInstance3D child → Use BoxMesh
4. Add CollisionShape3D child → BoxShape3D
5. Attach script → Select "CarryableComponent.gd"
6. In Inspector:
   - **RigidBody3D:** Set mass to 1.0
7. Save scene as `test_box.tscn`

**Expected Behavior:**
- Left click → Pick up box
- E key (while carrying) → Drop box
- Left click (while carrying) → Throw box
- No E-key interaction when not carrying

---

### Test Object 3: Locked Box (Must Drop to Interact)

**Scene Structure:**
```
TestLockedBox (RigidBody3D)
├── MeshInstance3D (box)
├── CollisionShape3D (box shape)
├── AnimationPlayer (optional)
└── LockedBoxInteraction (new script - see below)
```

**Script (create new):**
```gdscript
extends CarryableInteractableComponent
class_name LockedBoxInteraction

var is_locked: bool = true

func _ready() -> void:
    can_interact_while_carried = false  # Must drop first!
    e_key_interaction_text = "Unlock"
    super._ready()

func _on_e_key_interacted(player: PlayerInteractionComponent) -> void:
    if is_locked:
        is_locked = false
        e_key_interaction_text = "Open"
        print("🔓 Box unlocked!")
    else:
        print("📦 Box opened!")
        # Add open animation here if needed
```

**Expected Behavior:**
- Left click → Pick up box
- E key (while carrying) → Drop box
- E key (while not carrying, first time) → Unlock box
- E key (while not carrying, second time) → Open box

---

## Testing Checklist

### Player Setup
- ✅ Player has `PlayerInteractionComponent`
- ✅ PlayerInteractionComponent has `carry_marker` assigned
- ✅ Camera is properly linked

### Object Setup
- ✅ Object is RigidBody3D (for carryable objects)
- ✅ Object has CollisionShape3D
- ✅ Object has proper mass (1-5kg typically)
- ✅ Script extends correct component type
- ✅ Object is in "interactable" group (auto-added by component)

### Input Testing

| Test | Action | Expected Result |
|------|--------|----------------|
| 1 | Look at object | Prompt appears |
| 2 | Left click | Object is picked up |
| 3 | E key (while carrying) | Object is dropped |
| 4 | Left click (while carrying) | Object is thrown |
| 5 | E key (not carrying, interactive) | Interaction occurs |

### Prompt Testing

**Simple Carryable:**
- Looking at: `[Click] Pick Up`
- While carrying: (no prompt)

**Interactive Carryable:**
- Looking at: `[Click] Pick Up | [E] Toggle Power`
- While carrying (can interact): (no prompt, but E still works)
- While carrying (can't interact): (no prompt, E drops)

**Regular Interaction (no pickup):**
- Looking at: `[E] Interact`

---

## Common Issues & Solutions

### Object doesn't pick up
❌ **Problem:** Parent is not RigidBody3D
✅ **Solution:** Change parent node type to RigidBody3D

❌ **Problem:** Object not in raycast range
✅ **Solution:** Move closer or increase `interaction_distance` in PlayerInteractionComponent

❌ **Problem:** Wrong collision layer
✅ **Solution:** Set object to layer 4 (Interactables)

### E-key doesn't work
❌ **Problem:** Using CarryableComponent instead of CarryableInteractableComponent
✅ **Solution:** Change script to extend CarryableInteractableComponent

❌ **Problem:** Didn't implement `_on_e_key_interacted()`
✅ **Solution:** Add method to your script

### Object falls through floor
❌ **Problem:** No collision shape on floor
✅ **Solution:** Ensure floor has StaticBody3D + CollisionShape3D

❌ **Problem:** Object moving too fast
✅ **Solution:** Enable `continuous_cd` on RigidBody3D

### Prompts not showing
❌ **Problem:** HUD not connected
✅ **Solution:** Connect `interaction_prompt_changed` signal to HUD

---

## Integration with Existing World

To add test objects to your existing world:

1. **Open world.tscn**
2. **Instance test scene:**
   - Right-click world → Add Child Node → Instantiate Child Scene
   - Select `test_radio.tscn` or `test_box.tscn`
3. **Position object** in world
4. **Test interaction** in play mode

---

## Performance Notes

- Each carryable object uses physics simulation
- Audio is 3D positional (not 2D)
- Raycasting updates every frame (lightweight)
- Recommended max carryable objects in scene: 20-30

---

## Next Steps After Testing

Once basic tests work:

1. ✅ Convert existing interactable objects
2. ✅ Adjust physics properties (mass, friction)
3. ✅ Fine-tune carry settings (throw power, distance)
4. ✅ Add custom interaction logic
5. ✅ Implement visual/audio feedback
6. ✅ Connect to game systems (inventory, quests, etc.)

