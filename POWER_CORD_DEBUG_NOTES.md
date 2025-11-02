# Power Cord System - Debug Notes & Future Improvements

**Date:** November 2, 2025  
**Status:** Work in Progress - Unresolved Issue

---

## 🐛 Current Unresolved Issue

### Problem: Plug Cannot Be Picked Up After Unplugging from Outlet

**Symptom:**
- Player can pick up plug initially ✅
- Player can plug cord into outlet ✅
- Player can unplug by interacting with outlet ✅
- **After unplugging, plug cannot be picked up again ❌**

**What We Observed:**
1. Raycast detects the plug correctly (shows in debug logs)
2. Plug is in "interactable" group ✅
3. Plug RigidBody3D is NOT frozen ✅
4. Plug sleeping state is now `false` (was `true` before fix) ✅
5. Collision layers/masks are correct ✅
6. Interaction prompt doesn't appear after unplugging ❌

**Attempted Fixes:**
1. ✅ Added plug to "interactable" group explicitly
2. ✅ Fixed RigidBody sleeping issue (was going to sleep immediately)
3. ✅ Added small downward velocity to prevent freezing
4. ✅ Disabled `can_sleep` temporarily after unplug
5. ❌ Still not working - interaction system not recognizing unplugged plug

**Theories to Investigate Next Time:**
- [ ] Check if HUD is properly showing interaction prompts
- [ ] Verify `_update_interaction_prompt()` is being called
- [ ] Check if `current_interactable` is being set correctly after unplug
- [ ] Investigate if visual cord pulling affects raycast detection
- [ ] Test with outlet interaction disabled (only plug interaction)
- [ ] Check collision mask changes at runtime (scene showed 7, runtime showed 10)
- [ ] Verify scene hierarchy isn't changing during plug/unplug

---

## 📋 What We Built Today

### 1. Power Cord System Components

#### PowerCordPlugComponent.gd
- Extends `CarryableComponent` for physics-based carrying
- Manages plug/unplug state
- Detects nearby outlets while being carried
- Auto-plug on release feature
- Signal system for powered devices

#### OutletComponent.gd
- Manages electrical outlets
- Accepts/removes plugs
- Power state management
- Audio feedback for plug in/out
- Visual indicators (optional materials)

#### PowerCord.gd
- Visual rope rendering between plug and device
- Dynamic curve generation with sag
- Ribbon mesh generation
- Updates in real-time as plug moves

### 2. Integration with Existing Systems
- Uses `PlayerInteractionComponent` for raycast detection
- Uses `CarryableComponent` for pickup/carry/throw mechanics
- Uses `InteractionComponent` base class architecture
- Integrated with `PoweredDeviceComponent` (fan example)

---

## 🎯 Improvements for Next Session

### High Priority

1. **Fix Plug Pickup Issue**
   - Debug interaction prompt system
   - Verify raycast → interaction flow
   - Test with simplified scene
   - Consider adding visual debug sphere on plug position

2. **Collision Mask Investigation**
   - Scene file shows `collision_mask = 7`
   - Runtime shows `collision_mask = 10`
   - Find where this is being changed
   - Ensure consistency

3. **Interaction Flow Simplification**
   - Current: Outlet interaction unplugs
   - Desired: Only plug interaction should unplug
   - Prevents conflicts with multiple plugs per outlet

### Medium Priority

4. **Multiple Plugs Per Outlet**
   - Outlets currently support 1 plug (`is_occupied` boolean)
   - Change to array of plugs with max capacity
   - Add socket marker array for positioning multiple plugs

5. **Cord Physics**
   - Currently visual-only (ribbon mesh)
   - Consider adding rope physics simulation
   - Or use Godot's built-in SoftBody3D/rope
   - Prevent plug from being pulled too far from anchor

6. **Better Visual Feedback**
   - Glow effect on nearby outlets
   - Snap preview when carrying plug near outlet
   - Cord color change when powered/unpowered
   - Spark effect on plug/unplug

7. **Audio Polish**
   - Add electrical hum when plugged
   - Add plug insertion sound variations
   - Add cord dragging sound effects

### Low Priority

8. **Code Cleanup**
   - Remove commented-out code
   - Consolidate debug prints
   - Add more inline documentation
   - Standardize naming conventions

9. **Performance Optimization**
   - Outlet detection only checks every 0.1s (already optimized)
   - Could use Area3D instead of distance checks
   - Ribbon mesh could be simplified

10. **Edge Cases**
    - What happens if outlet is deleted while plug is in it?
    - What happens if plug is deleted while plugged in?
    - What happens if device is moved while cord is plugged?
    - Cord length limits and tension

---

## 🔧 Code Architecture Notes

### Scene Hierarchy
```
Node3D (PowerCord.gd script)
└── AnchorPoint (Marker3D) - Fixed attachment point
└── plug (RigidBody3D) - Physics object player interacts with
    ├── CollisionShape3D (SphereShape3D)
    ├── MeshInstance3D (visual plug)
    ├── Node3D (PowerCordPlugComponent.gd script)
    └── PlugAttachment (Marker3D) - Cord attachment point
```

### Interaction Flow
1. PlayerInteractionComponent raycast hits plug RigidBody3D
2. `_find_interactable_root()` finds plug (has "interactable" group)
3. `_find_interaction_component()` finds PowerCordPlugComponent (child)
4. Calls `PowerCordPlugComponent.interact(player)`
5. Which calls `_on_interacted(player)` override
6. Executes pickup/drop/plug logic based on state

### State Management
- `is_plugged` - Boolean, is plug in an outlet
- `is_carried` - Boolean from CarryableComponent
- `nearby_outlet` - Reference to nearby outlet or null
- `current_outlet` - Reference to outlet we're plugged into

### Key Design Decisions
- Plug is CarryableComponent (can be carried like any other object)
- Outlet is InteractionComponent (can be interacted with)
- Cord is visual-only (no physics simulation)
- Auto-plug on release near outlet (configurable)
- Unplug + pickup in one action when interacting with plugged plug

---

## 🧹 Cleanup Checklist

- [x] Removed excessive debug output
- [x] Fixed RigidBody sleeping issue
- [ ] Remove redundant `add_to_group("interactable")` call (already done by InteractionComponent)
- [ ] Verify all signals are actually being used
- [ ] Check for unused variables
- [ ] Standardize print statement style
- [ ] Add missing type hints
- [ ] Document magic numbers (0.1, 0.2, 3.0, etc.)

---

## 📝 Questions to Answer

1. Why does collision_mask change from 7 to 10 at runtime?
2. Is the interaction prompt system working correctly?
3. Should outlets handle unplugging or only plugs?
4. How to handle multiple plugs per outlet?
5. Should cord have physics or remain visual-only?
6. What's the maximum cord length before it disconnects?
7. Do we need cord tension/resistance?

---

## 🎮 Testing Scenarios

### Current Tests Passing ✅
- Pick up plug from initial position
- Carry plug around
- Plug into nearby outlet
- Outlet powers device (fan)
- Outlet interaction unplugs cord
- Visual cord updates in real-time

### Tests Failing ❌
- Pick up plug after outlet unplug
- Pick up plug after direct plug unplug

### Tests Not Yet Implemented
- Multiple cords in one outlet
- Cord length limits
- Cord through walls/obstacles
- Plug damage from throwing
- Outlet overload/short circuit
- Cord tangling with other cords

---

## 💡 Inspiration & References

Similar systems in games:
- **Death Stranding** - Rope/cable mechanics
- **Portal** - Laser redirection, cable puzzles
- **The Witness** - Cable connection puzzles
- **Amnesia** - Physics object interaction

Godot resources:
- RigidBody3D physics
- RayCast3D for interaction
- ArrayMesh for procedural cord
- Joint3D for rope physics (future?)

---

## Next Session Goals

1. **Primary:** Fix plug pickup after unplug
2. **Secondary:** Clean up code and remove redundant parts
3. **Tertiary:** Plan multi-plug outlet system
