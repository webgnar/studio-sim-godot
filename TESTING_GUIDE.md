# Phase 1 Testing Guide

## What We've Built So Far

### ✅ Completed:
1. **PlayerInteractionComponent.gd** - Centralized raycast interaction system
2. **InteractionComponent.gd** - Base class for all interactable objects
3. **HUD.gd + HUD.tscn** - UI system for interaction prompts
4. **SimpleInteraction.gd** - Test interaction component
5. **Updated PlayerController.gd** - Auto-creates PlayerInteractionComponent
6. **Updated project.godot** - Added E key to interact input

---

## How to Test the New System

### Step 1: Add HUD to Player
1. Open `scenes/world.tscn` in Godot
2. Select the Player node (CharacterBody3D)
3. Right-click → "Instantiate Child Scene"
4. Select `scenes/HUD.tscn`
5. The HUD should now be a child of the Player

### Step 2: Create a Test Interactable Object
1. In the scene, create a new Node3D (or use an existing mesh like a cube)
2. Add a child node to it: Node → Node3D
3. Attach the `SimpleInteraction.gd` script to this child node
4. In the inspector, set:
   - **Interaction Text:** "Test Object"
   - **Message:** "You clicked the test object!"

### Step 3: Test the System
1. Run the game (F5)
2. Look at the test object
3. You should see: **[E] Test Object** appear at the top of the screen
4. Press E (or click)
5. Check the console - you should see: **🎯 You clicked the test object!**
6. Look away - the prompt should disappear

---

## Expected Behavior

### When working correctly:
- ✅ Player has "player" group assigned
- ✅ PlayerInteractionComponent is auto-created on player
- ✅ HUD connects to interaction component
- ✅ Looking at interactable shows prompt
- ✅ Looking away hides prompt
- ✅ Pressing E triggers interaction
- ✅ Console shows interaction messages
- ✅ Only ONE raycast per frame (check profiler)

### Console Output Example:
```
Mouse captured, camera found at: CharacterBody3D/Head/Camera3D
PlayerAnimation script found and connected!
Created PlayerInteractionComponent programmatically
✅ PlayerInteractionComponent initialized
   Camera: CharacterBody3D/Head/Camera3D
   Interaction distance: 5
   Raycast created at: CharacterBody3D/Head/Camera3D/InteractionRaycast
✅ Added TestObject to 'interactable' group
✅ HUD connected to PlayerInteractionComponent
👁️ Looking at: TestObject
🎯 You clicked the test object!
   Interacted by: CharacterBody3D
```

---

## Common Issues & Solutions

### Issue: "HUD: No player found as parent!"
**Solution:** Make sure HUD.tscn is a child of the Player node, not World

### Issue: "HUD: Could not find PlayerInteractionComponent on player!"
**Solution:** The PlayerController should auto-create it. Check that PlayerController.gd has the latest changes.

### Issue: Prompt doesn't appear
**Solutions:**
1. Check that object is in "interactable" group (should be automatic)
2. Verify object has an InteractionComponent child
3. Check raycast distance (default is 5 units)
4. Make sure object has collision (StaticBody3D or RigidBody3D with CollisionShape3D)

### Issue: Can't interact (E key doesn't work)
**Solutions:**
1. Check Input Map has "interact" action with E key
2. Verify mouse is captured (press ESC to release, then click to recapture)
3. Make sure InteractionComponent has an `interact()` method

---

## Next Steps After Testing

Once basic testing works:

### Option A: Refactor ClickableBox (Recommended)
- Convert existing ClickableBox to use new component system
- Test all box functionality still works
- Remove old raycast code

### Option B: Create More Test Objects
- Test with multiple interactables
- Test interaction distance
- Test with different object types

---

## Performance Verification

### Before Component System:
- 4+ raycasts per frame (one per clickable object)
- Duplicate camera finding code
- Duplicate audio setup code

### After Component System:
- 1 raycast per frame
- Centralized camera reference
- Shared audio system

**To Verify:**
1. Open Godot Profiler (Debug → Profiler)
2. Look for `_physics_process` or `_process` calls
3. Should see ONE raycast update, not multiple

---

## Debug Tools

### Enable Debug Output:
The system already prints useful info:
- ✅ Component initialization
- 👁️ When looking at objects
- 🎯 When interactions occur

### Visual Debugging:
You can add debug drawing to PlayerInteractionComponent:
```gdscript
func _process(delta):
    _update_interactable()
    
    # Debug: Draw raycast
    if _raycast and _raycast.is_colliding():
        DebugDraw3D.draw_line(
            _raycast.global_position,
            _raycast.get_collision_point(),
            Color.GREEN
        )
```

---

## What to Look For

### Good Signs:
- ✅ Interaction prompt appears/disappears smoothly
- ✅ Console shows interaction messages
- ✅ Only one raycast in profiler
- ✅ No errors in console
- ✅ Crosshair visible in center

### Red Flags:
- ❌ Multiple "Looking at:" messages per frame
- ❌ Errors about missing nodes
- ❌ Prompt doesn't update when looking away
- ❌ E key does nothing

---

## Ready to Move Forward?

Once you confirm the basic system works:

1. ✅ Mark "Test and verify Phase 1" as complete
2. 🎯 Start refactoring ClickableBox to BoxInteraction.gd
3. 📝 Document any issues you found

---

**Created:** November 1, 2025  
**Status:** Testing Phase  
**Next Task:** Refactor ClickableBox (Task 1.3)
