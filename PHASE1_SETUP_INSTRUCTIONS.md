# Phase 1 Setup Instructions
**Carry System - Manual Scene Setup Required**

## ✅ Completed:
1. ✅ Created `CarryableComponent.gd` in `scripts/components/`
2. ✅ Extended `PlayerInteractionComponent.gd` with carry methods
3. ✅ Added `action_primary` input action (left mouse button) to `project.godot`
4. ✅ Updated `PlayerController.gd` to **automatically create CarryMarker** - no manual setup needed!

---

## 🔧 Manual Setup Required (Do This in Godot Editor):

### ~~Step 1: Add Carry Marker to Player~~ ✅ AUTOMATIC
**This is now done automatically by PlayerController!**

The PlayerController script now creates the CarryMarker and assigns it when the game runs.
You can skip to Step 2.5 below.

### ~~Step 2: Assign Carry Marker to PlayerInteractionComponent~~ ✅ AUTOMATIC
**This is now done automatically by PlayerController!**

### Step 2.5: Add Carry Hint to HUD
**Open:** `scenes/HUD.tscn`

1. **Add child to root CanvasLayer:** Label node
2. **Name it:** `CarryHint`
3. **Configure in Inspector:**
   - Text: "[E] Drop  |  [Left Click] Throw"
   - Horizontal Alignment: Center
   - Vertical Alignment: Bottom
4. **Position it:**
   - Layout → Anchors Preset → Bottom Wide
   - Or manually set:
     - Anchor Left: 0, Anchor Right: 1
     - Anchor Top: 1, Anchor Bottom: 1
     - Offset Top: -50
5. **Optional styling:**
   - Add Theme Override → Font Size: 16
   - Add Theme Override → Font Color: Yellow or Cyan
6. **Save the scene**

### Step 1: Create Test Carryable Object
**File → New Scene**

1. **Root node:** RigidBody3D
   - Name: `TestBox`
   - Mass: `1.0`
   - Add to group: "interactable" (optional, component does this automatically)

2. **Add child:** CollisionShape3D
   - Shape: New BoxShape3D
   - Size: (1, 1, 1)

3. **Add child:** MeshInstance3D
   - Mesh: New BoxMesh
   - Size: (1, 1, 1)
   - Material: (add a material for visibility)

4. **Add child:** CarryableComponent (script)
   - Navigate to: `res://scripts/components/CarryableComponent.gd`
   - Or type "CarryableComponent" in the script search

5. **Save as:** `scenes/test_box.tscn`

### Step 2: Add Test Box to World
1. **Open:** `scenes/world.tscn`
2. **Instance:** Drag `test_box.tscn` into the scene
3. **Position it** in front of the player
4. **Save the scene**

### Step 3: Test Basic Carrying
**Run the game (F5)**

**Test Checklist:**
- [ ] Look at the box - should see "Pick Up" prompt
- [ ] Press E - should pick up the box
- [ ] Box should float in front of you
- [ ] Box should follow your view smoothly
- [ ] Press E again - should drop gently
- [ ] Press Left Click while carrying - should throw

**If it works:** ✅ Phase 1 core functionality complete!

---

## 🐛 Troubleshooting:

### "No carry marker set" warning:
- Make sure you assigned CarryMarker to PlayerInteractionComponent
- Check Inspector → Carry Settings → Carry Marker is not `<empty>`

### Box doesn't pick up:
- Check box is RigidBody3D (not StaticBody3D)
- Check CarryableComponent is child of the box
- Check console for error messages

### Box flies away when picked up:
- This is expected if throw_power is too high
- Adjust in CarryableComponent → Throw Settings → Throw Power

### Box is jittery:
- Adjust `carry_smoothness` (higher = snappier, lower = smoother)
- Default is 10.0

### Box clips through walls:
- Collision detection in `get_carry_position()` should prevent this
- Check that walls have collision shapes

---

## 🎮 Next Steps After Testing:

Once basic carrying works:
1. Create more test objects (different masses, shapes)
2. Update HUD to show carry controls
3. Add pickup/drop sounds
4. Test edge cases (narrow spaces, rapid pickup/drop, etc.)

---

## 📝 Controls:
- **E** - Pick up / Drop
- **Left Click** - Throw (while carrying)
- **Mouse** - Look around (box follows view)

---

**Created:** November 1, 2025  
**Status:** Ready for manual scene setup
