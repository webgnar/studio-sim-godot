# COGITO Source Files Review Request

**Date:** November 1, 2025  
**Purpose:** Gather implementation details for Phase 3 - Pickup & Physics System  
**Project:** Studio Sim - Godot FPS Interaction System

---

## 📋 What We Need

We're ready to implement **object pickup** and **physics-based carrying** in our project. The COGITO analysis document gave us a great architectural overview, but we need to see the actual implementation code to understand:

1. **Physics handling** - How to freeze/unfreeze objects smoothly
2. **Carry mechanics** - Position calculation, rotation locking, edge cases
3. **Item data structure** - Resource-based inventory items
4. **Pickup validation** - Distance checks, inventory full handling
5. **Drop/throw physics** - Applying impulses correctly

---

## 🎯 Priority 1: Core Carrying Mechanics

### File: `Components/Interactions/CarryableComponent.gd`

**What to extract:**

#### 1. Physics State Management
- [ ] How do they freeze/unfreeze RigidBody3D?
- [ ] Do they cache original physics properties?
- [ ] How do they handle collision during carry?
- [ ] What layers/masks do they modify?

**Look for:**
```gdscript
# Example patterns to find:
rigid_body.freeze = true/false
collision_layer = ?
collision_mask = ?
# Any state caching before pickup
```

---

#### 2. Carry Position Logic
- [ ] How is the carried object positioned relative to camera?
- [ ] What's their carry distance calculation?
- [ ] Do they use lerp/smoothing for movement?
- [ ] How do they handle rotation locking?

**Look for:**
```gdscript
# Position updates in _process() or _physics_process()
global_position = ?
# Rotation handling
lock_rotation_when_carried
# Distance offsets
carry_distance_offset
```

---

#### 3. Player Integration
- [ ] How does CarryableComponent communicate with player?
- [ ] What signals are emitted?
- [ ] How does player reference the carried object?
- [ ] Is there a `start_carrying()` / `stop_carrying()` pattern?

**Look for:**
```gdscript
player_interaction_component.start_carrying(self)
player_interaction_component.stop_carrying()
# Any signals
signal being_carried(object)
signal was_dropped(object)
```

---

#### 4. Drop & Throw Mechanics
- [ ] How is throwing implemented?
- [ ] What's the force calculation?
- [ ] Do they use `apply_central_impulse()` or `apply_impulse()`?
- [ ] How do they determine throw direction?

**Look for:**
```gdscript
drop_distance
throw_force
apply_central_impulse()
# Direction calculation
camera.global_transform.basis.z
```

---

#### 5. Edge Cases & Validation
- [ ] Can you carry while wielding weapons?
- [ ] Maximum carry weight/size limits?
- [ ] What happens if carried object collides with wall?
- [ ] Can objects be dropped anywhere or specific zones?

**Look for:**
```gdscript
is_carryable_while_wielding
# Validation checks
if player.is_wielding: return
# Drop validation
can_drop_here()
```

---

#### 6. Audio & Feedback
- [ ] Pickup sound handling
- [ ] Drop sound handling
- [ ] Any haptic/visual feedback?

**Look for:**
```gdscript
@export var pick_up_sound : AudioStream
@export var drop_sound : AudioStream
Audio.play_sound()
```

---

## 🎯 Priority 2: Inventory Pickup System

### File: `Components/Interactions/PickupComponent.gd`

**What to extract:**

#### 1. Item Data Integration
- [ ] How does PickupComponent reference InventoryItemPD?
- [ ] How is quantity handled?
- [ ] What's the structure of `slot_data`?

**Look for:**
```gdscript
@export var slot_data : InventorySlotPD
slot_data.inventory_item
slot_data.quantity
```

---

#### 2. Pickup Logic
- [ ] What happens when player interacts?
- [ ] How do they add items to player inventory?
- [ ] What if inventory is full?
- [ ] Do they destroy the object or hide it?

**Look for:**
```gdscript
func pick_up(player_interaction_component):
    # Inventory check
    if player.inventory_data.pick_up_slot_data(slot_data):
        # Success - what happens to object?
        queue_free() or visible = false?
    else:
        # Inventory full handling
        show_hint("Inventory full")
```

---

#### 3. Display & Feedback
- [ ] Do they show item name in prompt?
- [ ] Custom interaction text?
- [ ] Pickup sound/animation?

**Look for:**
```gdscript
display_item_name
interaction_text = slot_data.inventory_item.name
sound_pickup
```

---

## 🎯 Priority 3: Item Data Resources

### File: `InventoryPD/CustomResources/InventoryItemPD.gd`

**What to extract:**

#### 1. Base Item Properties
- [ ] What are the core @export variables?
- [ ] How is icon/texture handled?
- [ ] Stackable logic?
- [ ] Unique items (only one allowed in world)?

**Look for:**
```gdscript
@export var name : String
@export var description : String
@export var icon : Texture2D
@export var is_stackable : bool
@export var stack_size : int
@export var is_unique : bool
```

---

#### 2. Drop Scene System
- [ ] How do items create their 3D representation when dropped?
- [ ] What's the `drop_scene` pattern?
- [ ] How is it instantiated?

**Look for:**
```gdscript
@export var drop_scene : String
# or
@export var drop_scene : PackedScene
# How it's used
var dropped = load(drop_scene).instantiate()
```

---

#### 3. Item Usage
- [ ] Is there a virtual `use()` method?
- [ ] How do subclasses override it?
- [ ] What parameters are passed?

**Look for:**
```gdscript
func use(target) -> bool:
    # Base implementation
    return false
```

---

### File: `InventoryPD/CustomResources/InventorySlotPD.gd`

**What to extract:**

#### 1. Slot Structure
- [ ] How does slot reference item?
- [ ] Quantity tracking?
- [ ] Any position/grid data?

**Look for:**
```gdscript
@export var inventory_item : InventoryItemPD
@export var quantity : int
# Grid inventory
origin_index
item_rotation
```

---

#### 2. Stacking Logic
- [ ] How does `can_merge_with()` work?
- [ ] Max stack size handling?
- [ ] Merge validation?

**Look for:**
```gdscript
func can_merge_with(other_slot_data: InventorySlotPD) -> bool:
    # Implementation details
```

---

## 🎯 Priority 4: Player Carrying State

### File: `Components/PlayerInteractionComponent.gd`

**What to extract:**

#### 1. Carried Object Reference
- [ ] How do they track what's being carried?
- [ ] Single object or array?
- [ ] State flags?

**Look for:**
```gdscript
var carried_object : CogitoCarryableComponent
var is_carrying : bool
```

---

#### 2. Carry Update Loop
- [ ] Where do they update carried object position?
- [ ] Is it in `_process()` or `_physics_process()`?
- [ ] Performance considerations?

**Look for:**
```gdscript
func _process(delta):
    if is_carrying:
        # Position update logic
```

---

#### 3. Interaction Blocking
- [ ] Can you interact with other objects while carrying?
- [ ] How do they prevent picking up multiple objects?
- [ ] Any UI changes while carrying?

**Look for:**
```gdscript
if is_carrying:
    return # Block other interactions
# or
if is_carrying and not object.is_carryable_while_wielding:
```

---

## 📝 What to Document

For each code section you find, please provide:

### Format:
```markdown
## [Component Name] - [Feature]

### Code Extract:
```gdscript
// Paste relevant code here (10-30 lines)
```

### Key Insights:
- Pattern used: (e.g., "Uses lerp for smooth positioning")
- Variables involved: (e.g., "carry_distance_offset, carrying_velocity_multiplier")
- Edge cases handled: (e.g., "Checks if player is_wielding before allowing pickup")
- Signals emitted: (e.g., "being_carried, was_dropped")

### Questions/Notes:
- Any unclear patterns?
- Different from what we expected?
- Implementation gotchas?
```

---

## 🔍 Additional Context to Gather

While reviewing, also note:

### Performance Patterns
- [ ] Do they use object pooling?
- [ ] Any @onready optimizations?
- [ ] Frame-rate dependent vs. delta-based calculations?

### Error Handling
- [ ] Null checks for player reference?
- [ ] What if RigidBody3D is freed while carried?
- [ ] Validation before physics operations?

### Configurability
- [ ] What's exposed via @export?
- [ ] Reasonable default values?
- [ ] Per-object vs. global settings?

---

## 🎯 Deliverable

Create a markdown file: `COGITO_PICKUP_IMPLEMENTATION_NOTES.md`

**Structure:**
1. CarryableComponent Analysis
   - Physics handling
   - Position/rotation logic
   - Player integration
   - Drop/throw mechanics
   
2. PickupComponent Analysis
   - Inventory integration
   - Validation logic
   - Feedback systems
   
3. Item Resource System
   - InventoryItemPD structure
   - InventorySlotPD structure
   - Stacking logic
   
4. Player Integration
   - Carrying state management
   - Update loop patterns
   - Interaction blocking
   
5. Implementation Recommendations
   - What to adopt directly
   - What to simplify
   - What to skip for now

---

## ⚠️ Important Notes

### We DON'T Need:
- ❌ Wieldable weapon system (not relevant)
- ❌ Consumable items (Phase 4+)
- ❌ Ammo/reloading (not needed)
- ❌ Attribute effects (health/stamina)
- ❌ Quest system integration
- ❌ Save/load persistence (Phase 5+)

### We DO Need:
- ✅ Basic physics pickup
- ✅ Carry and drop mechanics
- ✅ Throw with velocity
- ✅ Simple item data structure
- ✅ Optional: Basic inventory (list-based, not grid)

---

## 🚀 Next Steps After Review

Once you provide the implementation notes, we will:

1. Create `scripts/CarryableInteraction.gd` based on your findings
2. Create `scripts/PickupInteraction.gd` for inventory items
3. Create `scripts/InventoryItem.gd` resource
4. Update `PlayerInteractionComponent.gd` with carry logic
5. Test with existing objects (make boxes carryable!)
6. Iterate based on results

---

## 📊 Success Criteria

Your review will be complete when we can answer:

- ✅ How to freeze object physics when picked up
- ✅ How to position carried object in front of camera
- ✅ How to apply throw force when dropped
- ✅ How to structure item data as resources
- ✅ How to integrate with our existing InteractionComponent system
- ✅ What edge cases we need to handle

---

**Estimated Review Time:** 1-2 hours  
**Source Project:** Cogito - First Person Immersive Sim Template for Godot 4  
**GitHub:** [Link if available]

**Ready to dive in!** 🎮

---

## 📚 Quick Reference: Our Current System

For context, here's what we already have:

### Our InteractionComponent Base Class:
```gdscript
class_name InteractionComponent
extends Node3D

signal interacted()
@export var interaction_text: String = "Interact"
var parent_object: Node3D
var _audio_player: AudioStreamPlayer3D

func _ready():
    parent_object = get_parent()
    parent_object.add_to_group("interactable")

func interact(player_interaction_component):
    _on_interacted(player_interaction_component)

func _on_interacted(player):
    # Override in subclasses
    pass
```

### Our PlayerInteractionComponent:
```gdscript
class_name PlayerInteractionComponent
extends Node3D

signal interactive_object_detected(interactable)
signal interaction_prompt_changed(prompt_text)
var current_interactable: Node3D = null
var _raycast: RayCast3D

# Single raycast detects all objects in "interactable" group
```

**Goal:** Extend this pattern to support carrying physics objects!
