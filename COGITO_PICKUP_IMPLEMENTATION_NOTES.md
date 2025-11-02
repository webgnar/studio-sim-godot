# COGITO Pickup & Physics Implementation Notes

**Date:** November 1, 2025  
**Purpose:** Detailed code analysis for Phase 3 - Pickup & Physics System  
**Target Project:** Studio Sim - Godot FPS Interaction System  
**Source:** Cogito First Person Immersive Sim Template

---

## 📋 Table of Contents

1. [CarryableComponent - Physics Carrying](#carryablecomponent---physics-carrying)
2. [PlayerInteractionComponent - Carry State](#playerinteractioncomponent---carry-state)
3. [PickupComponent - Inventory Items](#pickupcomponent---inventory-items)
4. [Item Resource System](#item-resource-system)
5. [Implementation Recommendations](#implementation-recommendations)

---

## CarryableComponent - Physics Carrying

**File:** `addons/cogito/Components/Interactions/CarryableComponent.gd`

### 1. Core Structure & Signals

```gdscript
extends InteractionComponent
class_name CogitoCarryableComponent

signal carry_state_changed(is_being_carried : bool)
signal thrown(impulse)
```

**Key Insights:**
- Extends `InteractionComponent` - uses the base component system
- Emits signals for state changes (UI can react)
- Separate signal for throwing (with impulse data for VFX/audio)

---

### 2. Export Variables (Configurability)

```gdscript
@export_group("Carriable Settings")
@export var pick_up_sound : AudioStream
@export var drop_sound : AudioStream
@export var is_carryable_while_wielding : bool = false
@export var carry_distance_offset : float = 0
@export var lock_rotation_when_carried : bool = true
@export var carrying_velocity_multiplier : float = 10
@export var drop_distance : float = 1.5
@export var enable_manual_rotating : bool = true
@export var rotation_speed : float = 2.0
```

**Key Insights:**
- **carry_distance_offset**: Adjusts position relative to player (negative = closer, positive = farther)
- **lock_rotation_when_carried**: Usually `true` - prevents objects tumbling awkwardly
- **carrying_velocity_multiplier**: Higher = snappier, Lower = floatier feel
  - Default `10` feels responsive without being instant
- **drop_distance**: Auto-drops if object gets this far from carry position
  - Prevents carrying through walls/objects
- **Manual rotation**: Optional feature to rotate held objects with input

**Configurability Pattern:**
- Almost everything exposed via @export
- Reasonable defaults provided
- Per-object customization possible

---

### 3. State Variables

```gdscript
var camera : Camera3D
var parent_object  # The RigidBody3D being carried
var is_being_carried : bool
var is_being_rotated : bool = false
var player_interaction_component : PlayerInteractionComponent
var carry_position : Vector3  # Target position object floats toward
```

**Key Insights:**
- `parent_object` cached in `_ready()` - must be RigidBody3D
- `carry_position` updated every physics frame
- Camera cached only when needed (rotation feature)
- Player reference stored for accessing methods

---

### 4. Initialization & Validation

```gdscript
func _ready():
    parent_object = get_parent()
    if parent_object.has_signal("body_entered"):
        parent_object.body_entered.connect(_on_body_entered)
    else:
        CogitoGlobals.debug_log(true, "CarryableComponent.gd", 
            parent_object.name + ": CarriableComponent needs to be child to a RigidBody3D to work.")
```

**Key Insights:**
- **Validates parent is RigidBody3D** by checking for `body_entered` signal
- Connects to collision signal to auto-drop if carried object hits player
- Error message if parent isn't compatible

**Pattern to adopt:**
- Always validate component requirements in `_ready()`
- Connect necessary signals early
- Provide helpful error messages

---

### 5. Interaction Entry Point

```gdscript
func interact(_player_interaction_component: PlayerInteractionComponent):
    if !is_disabled:
        if attribute_check == AttributeCheck.NONE:
            carry(_player_interaction_component)
            was_interacted_with.emit(interaction_text, input_map_action)
        else:
            if check_attribute(_player_interaction_component):
                carry(_player_interaction_component)
                was_interacted_with.emit(interaction_text, input_map_action)

func carry(_player_interaction_component: PlayerInteractionComponent):
    player_interaction_component = _player_interaction_component
    
    # Validation: Can't carry while wielding (unless allowed)
    if player_interaction_component.is_wielding and not is_carryable_while_wielding:
        player_interaction_component.send_hint(null, tr("HINT_cant_carry"))
        return

    # Toggle: Drop if already carrying, pickup if not
    if is_being_carried:
        leave()
    else:
        hold()
```

**Key Insights:**
- **Toggle behavior**: Press again to drop
- **Validation check**: Can't carry while wielding weapon (configurable)
- **Hint system**: Shows message to player if can't carry
- **Attribute checks**: Optional strength/stamina requirements (inherited from base)

**Pattern:**
- Validate before state change
- Provide feedback on failure
- Toggle on repeated interaction

---

### 6. Physics Update Loop (THE CORE MECHANIC)

```gdscript
func _physics_process(_delta):
    if is_being_carried:
        # Update target position
        carry_position = player_interaction_component.get_carryable_destination_point(carry_distance_offset)
        
        # Apply velocity toward target (smooth following)
        parent_object.set_linear_velocity(
            (carry_position - parent_object.global_position) * carrying_velocity_multiplier
        )
        
        # Optional manual rotation
        if enable_manual_rotating and Input.is_action_pressed("action_secondary"):
            player_interaction_component.player.is_movement_paused = true
            is_being_rotated = true
            rotate_object(_delta)
        
        # Resume player movement when rotation released
        if is_being_rotated and Input.is_action_just_released("action_secondary"):
            player_interaction_component.player.is_movement_paused = false
        
        # Auto-drop if too far away
        if (carry_position - parent_object.global_position).length() >= drop_distance:
            leave()
```

**Key Insights:**

#### Position Calculation:
- Uses **player method** `get_carryable_destination_point(offset)`
- Returns point in front of camera, accounting for collisions
- Offset adjusts distance from player

#### Movement Method:
- **Uses velocity, NOT direct position setting**
- Formula: `velocity = (target - current) * multiplier`
- This creates smooth "floating" movement
- RigidBody3D physics still active (can bounce/collide)

#### Why Velocity Instead of Position?
- More natural physics interaction
- Objects can collide with world
- Smoother visual movement
- Player can "feel" object weight

#### Auto-Drop Protection:
- Prevents carrying through walls
- If object gets stuck/blocked, it drops
- `drop_distance` of 1.5 is reasonable default

**Critical Pattern to Adopt:**
```gdscript
# DON'T do this (rigid/teleporty):
object.global_position = target_position

# DO this (smooth/physics-based):
object.linear_velocity = (target_position - object.global_position) * smoothing_factor
```

---

### 7. Manual Rotation (Optional Feature)

```gdscript
func rotate_object(_delta):
    var input_dir = Input.get_vector("left", "right", "forward", "back")
    
    if input_dir.length() > 0:
        if not camera:
            camera = get_viewport().get_camera_3d()
        
        # Create rotation basis relative to camera (ignoring pitch)
        var rotation_basis: Basis = camera.global_basis.rotated(
            camera.global_basis.x, 
            -camera.global_rotation.x
        )
        
        # Convert input to 3D rotation vector
        var rotation_vector: Vector3 = rotation_basis * Vector3(input_dir.y, input_dir.x, 0).normalized()
        
        # Apply rotation
        parent_object.global_rotate(rotation_vector, deg_to_rad(rotation_speed))
```

**Key Insights:**
- Uses movement keys (WASD) to rotate object
- Rotation is relative to camera view
- Pauses player movement during rotation
- 2 degrees/second default speed

**You can skip this feature initially** - it's nice-to-have, not essential.

---

### 8. Pickup Logic (`hold()`)

```gdscript
func hold():
    # Lock rotation to prevent tumbling
    if lock_rotation_when_carried:
        parent_object.set_lock_rotation_enabled(true)
    
    # Un-freeze physics (needs to move via velocity)
    parent_object.freeze = false
    
    # Tell player to start carrying
    player_interaction_component.start_carrying(self)
    
    # Exclude from raycast (don't detect the held object)
    player_interaction_component.interaction_raycast.add_exception(parent_object)
    
    # Play pickup sound
    if pick_up_sound != null:
        audio_stream_player_3d.stream = pick_up_sound
        audio_stream_player_3d.play()
    
    # Update state
    is_being_carried = true
    carry_state_changed.emit(is_being_carried)
```

**Key Insights:**

#### Physics State Management:
1. **Lock rotation** (prevents object spinning wildly)
2. **Un-freeze physics** (object needs to move)
3. This seems contradictory but:
   - Locked rotation = can't rotate from collisions
   - Un-frozen = can still move via velocity

#### Player Integration:
- Calls `player_interaction_component.start_carrying(self)`
- Passes reference to THIS component
- Player stores this reference

#### Raycast Exclusion:
- **Critical**: Add object to raycast exceptions
- Otherwise player would continuously detect held object
- Would block interaction with other objects

#### State Update Pattern:
- Set boolean flag
- Emit signal with new state
- UI/other systems can react to signal

**Critical takeaway:**
```gdscript
# The sequence matters:
1. Configure physics (lock rotation, unfreeze)
2. Tell player (start_carrying)
3. Exclude from detection (add_exception)
4. Audio feedback
5. Update state & emit signal
```

---

### 9. Drop Logic (`leave()`)

```gdscript
func leave():
    # Resume player movement if was rotating
    if is_being_rotated:
        player_interaction_component.player.is_movement_paused = false
        
    # Unlock rotation
    if lock_rotation_when_carried:
        parent_object.set_lock_rotation_enabled(false)
    
    # Tell player to stop carrying (with null check)
    if player_interaction_component and is_instance_valid(player_interaction_component):
        player_interaction_component.stop_carrying()
        player_interaction_component.interaction_raycast.remove_exception(parent_object)
    
    # Update state
    is_being_carried = false
    carry_state_changed.emit(is_being_carried)
```

**Key Insights:**

#### Safety Checks:
- **Null validation**: `is_instance_valid()` check
- Prevents crashes if player/component deleted mid-carry
- Important for save/load, scene transitions

#### Physics Restoration:
- Unlock rotation (object can tumble naturally)
- Remove raycast exception (can be detected again)

#### Player Integration:
- Calls `player_interaction_component.stop_carrying()`
- Removes player's reference to carried object

**Pattern:**
- Always validate references before using them
- Reverse the pickup sequence
- Clean up state completely

---

### 10. Throw Mechanic

```gdscript
func throw(power):
    leave()  // Drop first (cleanup state)
    
    // Play drop sound
    if drop_sound:
        audio_stream_player_3d.stream = drop_sound
        audio_stream_player_3d.play()
    
    // Calculate impulse vector
    var impulse = player_interaction_component.Get_Look_Direction() * power
    
    // Apply physics impulse
    parent_object.apply_central_impulse(impulse)
    
    // Emit signal
    thrown.emit(impulse)
```

**Key Insights:**

#### Throw Sequence:
1. Drop/cleanup state first
2. Play feedback sound
3. Get throw direction (where camera is looking)
4. Apply impulse (instant velocity change)
5. Emit signal with impulse data

#### Impulse Application:
- **Uses `apply_central_impulse()`** not `apply_impulse()`
- Central = applies at object's center of mass
- Takes a Vector3 (direction * magnitude)

#### Direction Calculation:
- Uses `Get_Look_Direction()` from player
- Returns normalized vector where camera points
- Multiply by power for final impulse

**The formula:**
```gdscript
impulse = look_direction * power
// Example: Vector3(0, 0, -1) * 15 = Vector3(0, 0, -15)
```

---

### 11. Auto-Drop on Collision

```gdscript
func _on_body_entered(body):
    if body.is_in_group("Player") and is_being_carried:
        leave()
```

**Key Insights:**
- Connected to RigidBody3D's `body_entered` signal
- Drops if carried object hits player
- Prevents object getting stuck inside player
- Simple but effective edge case handling

---

### 12. Cleanup on Node Removal

```gdscript
func _exit_tree():
    if is_being_carried:
        leave()
```

**Key Insights:**
- Called when node is removed from scene
- Ensures clean state if object deleted while carried
- Prevents dangling references
- Important for save/load systems

---

## PlayerInteractionComponent - Carry State

**File:** `addons/cogito/Components/PlayerInteractionComponent.gd`

### 1. Carry State Variables

```gdscript
@export var carryable_position: Node3D  // Reference to marker/node for carry position

var carried_object = null:  // The CarryableComponent being carried
    set = _set_carried_object
    
var is_carrying: bool:
    get: return carried_object != null  // Computed property
```

**Key Insights:**

#### Carried Object Reference:
- Stores the **CarryableComponent**, not the RigidBody3D
- Uses setter for custom logic (could emit signals, etc.)
- `null` when not carrying

#### Computed Property:
- `is_carrying` is a getter, not a variable
- Returns `true` if `carried_object != null`
- Cleaner than maintaining separate boolean

#### Carryable Position:
- A Node3D (probably a Marker3D) in the scene
- Defines where carried objects float
- Exported so it can be set in editor

**Pattern to adopt:**
```gdscript
// Computed properties instead of redundant booleans:
var carried_object = null
var is_carrying: bool:
    get: return carried_object != null
```

---

### 2. Throw Settings

```gdscript
@export_group("Throw Settings")
@export var max_throw_power: float = 25.0
@export var throw_power_mass_multiplier: float = 10.0
@export var throw_stamina_threshold: float = 20.0
@export var throw_stamina_drain: float = 5.0
@export var drop_when_cant_throw: bool = true
@export var stamina_attribute: CogitoAttribute

@export_group("Drop Settings")
@export var max_drop_power: float = 1.0
@export var drop_power_mass_multiplier: float = 1.0
```

**Key Insights:**

#### Throw Power Calculation:
```gdscript
throw_force = object_mass * throw_power_mass_multiplier
throw_force = clamp(throw_force, 0, max_throw_power)
```

- Heavier objects = more force (up to max)
- Prevents launching light objects at supersonic speed
- `max_throw_power = 25` caps the force

#### Drop vs. Throw:
- **Throw**: High power (default 25), uses stamina
- **Drop**: Low power (default 1), gentle placement

#### Stamina Integration:
- Optional stamina cost for powerful throws
- Threshold determines when stamina is drained
- Can drop instead if not enough stamina

**You can simplify this:**
```gdscript
// Minimal version:
var throw_power: float = 15.0
var drop_power: float = 1.0
// Skip stamina, skip mass calculation initially
```

---

### 3. Carry Position Calculation

```gdscript
func get_carryable_destination_point(distance_offset: float) -> Vector3:
    if !carryable_position:
        print("PIC: Error, no carryable position reference set!")
        return self.global_position
    
    // Calculate position in front of camera
    var destination_point = carryable_position.global_position 
        - distance_offset * get_viewport().get_camera_3d().get_global_transform().basis.z
    
    // Check if raycast hits something between player and destination
    if interaction_raycast.is_colliding():
        var collision_point = interaction_raycast.get_collision_point()
        
        // Use whichever is closer: destination or collision
        if interaction_raycast.global_position.distance_squared_to(destination_point) 
            < interaction_raycast.global_position.distance_squared_to(collision_point):
            return destination_point
        else:
            return collision_point
    
    return destination_point
```

**Key Insights:**

#### Base Position:
- Uses `carryable_position` node (set in editor)
- This is typically a Marker3D child of camera
- Defines the default "carry spot"

#### Distance Offset:
- Subtracts offset along camera's forward (-z) direction
- Negative offset = closer to camera
- Positive offset = farther from camera

#### Collision Detection:
- **Prevents carrying through walls!**
- Checks if raycast hits something
- If wall is closer than carry position, use wall position
- Object will be "pushed" against the wall

**Why this matters:**
- Without collision check, objects clip through walls
- With it, objects feel more physical/realistic
- They can't be carried through solid objects

**Simplified version:**
```gdscript
func get_carry_position(offset: float) -> Vector3:
    var camera = get_viewport().get_camera_3d()
    var forward = -camera.global_transform.basis.z
    return camera.global_position + forward * (2.0 + offset)
```

---

### 4. Carry State Management

```gdscript
func start_carrying(_carried_object):
    carried_object = _carried_object

func stop_carrying():
    carried_object = null
    _rebuild_interaction_prompts()  // Update UI
```

**Key Insights:**

#### Simple State:
- Just sets/clears the reference
- That's it! Very minimal.

#### UI Update:
- `_rebuild_interaction_prompts()` called on stop
- Ensures "Drop" prompt is removed
- UI stays in sync with state

**Pattern:**
- Keep state management simple
- Update UI after state changes
- Let other systems react via signals or checks

---

### 5. Throw Implementation

```gdscript
func _attempt_throw() -> void:
    if !is_carrying:
        return
    
    // Calculate throw force based on mass
    var carried_object_mass: float = (carried_object.get_parent() as RigidBody3D).mass
    var throw_force: float = carried_object_mass * throw_power_mass_multiplier
    throw_force = clamp(throw_force, 0, max_throw_power)
    
    // Check stamina (optional)
    if stamina_attribute and throw_force >= throw_stamina_threshold:
        if stamina_attribute.value_current < throw_stamina_drain:
            if drop_when_cant_throw:
                _drop_carried_object()
            return
        else:
            player.decrease_attribute(stamina_attribute.attribute_name, throw_stamina_drain)
    
    // Execute throw
    carried_object.throw(throw_force)
```

**Key Insights:**

#### Mass-Based Force:
1. Get object's mass from RigidBody3D
2. Multiply by multiplier (default 10)
3. Clamp to max (prevents absurd speeds)

Example:
- 1kg object: 1 * 10 = 10 (used)
- 5kg object: 5 * 10 = 50, clamped to 25
- 0.1kg object: 0.1 * 10 = 1 (very gentle)

#### Stamina Check:
- Only for strong throws (>= threshold)
- Drain stamina if available
- Otherwise drop gently (if configured)

#### Delegation:
- Calls `carried_object.throw(force)`
- CarryableComponent handles actual physics
- Clean separation of concerns

**Simplified version (no stamina):**
```gdscript
func throw_object():
    if !is_carrying: return
    var force = 15.0  // Fixed power
    carried_object.throw(force)
```

---

### 6. Drop Implementation

```gdscript
func _drop_carried_object() -> void:
    if !is_carrying:
        return
    
    // Calculate gentle drop force
    var carried_object_mass: float = (carried_object.get_parent() as RigidBody3D).mass
    var drop_force: float = carried_object_mass * drop_power_mass_multiplier
    drop_force = clamp(drop_force, 0, max_drop_power)
    
    // Execute drop (reuses throw() with low force)
    carried_object.throw(drop_force)
```

**Key Insights:**

#### Reuses Throw Method:
- `drop` is just `throw` with low power
- No need for separate physics code
- Max of 1.0 makes it gentle

#### Use Cases:
- Normal drop (press button again)
- Forced drop (low stamina)
- Auto-drop (too far/collision)

---

### 7. Look Direction Helper

```gdscript
func Get_Look_Direction() -> Vector3:
    var viewport = get_viewport().get_visible_rect().size
    var camera = get_viewport().get_camera_3d()
    return camera.project_ray_normal(viewport/2)
```

**Key Insights:**

#### Camera Ray at Screen Center:
- `viewport/2` = center of screen
- `project_ray_normal()` = normalized direction
- Returns where camera is pointing

**Simpler version:**
```gdscript
func get_look_direction() -> Vector3:
    var camera = get_viewport().get_camera_3d()
    return -camera.global_transform.basis.z  // Forward direction
```

---

### 8. Input Handling

```gdscript
func _input(event: InputEvent) -> void:
    // Throw while carrying
    if is_carrying and !get_parent().is_movement_paused and is_instance_valid(carried_object):
        if Input.is_action_just_pressed("action_primary"):
            _attempt_throw()
    
    // Interact button
    if event.is_action_pressed("interact") or event.is_action_pressed("interact2"):
        var action: String = "interact" if event.is_action_pressed("interact") else "interact2"
        _handle_interaction(action)
```

**Key Insights:**

#### Throw Input:
- Uses `action_primary` (left click/trigger)
- Only when carrying
- Checks if movement paused (during rotation)
- Validates object still exists

#### Interact Input:
- Two possible interact buttons supported
- Delegated to `_handle_interaction()`
- Pass which button was pressed

---

### 9. Interaction While Carrying

```gdscript
func _handle_interaction(action: String) -> void:
    if is_carrying:
        if is_instance_valid(carried_object):
            // If pressing same button as pickup, drop it
            if carried_object.input_map_action == action:
                _drop_carried_object()
                return
            else:
                // Allow interacting with components on carried object
                var carry_parent: CogitoObject = carried_object.get_parent() as CogitoObject
                if carry_parent:
                    for node: InteractionComponent in carry_parent.interaction_nodes:
                        if node.input_map_action == action and not node.is_disabled:
                            // Special handling for pickup components
                            if node is PickupComponent or node is BackpackComponent:
                                if !node.ignore_open_gui and get_parent().is_showing_ui:
                                    return
                                node.interact(self)
                                _rebuild_interaction_prompts()
                                break
        else:
            stop_carrying()
            return
    
    // Normal interaction when not carrying
    if interactable != null and not is_carrying:
        for node: InteractionComponent in interactable.interaction_nodes:
            if node.input_map_action == action and not node.is_disabled:
                node.interact(self)
                _rebuild_interaction_prompts()
                break
```

**Key Insights:**

#### Toggle Behavior:
- If same button, drop object
- Prevents accidental double-pickup

#### Carried Object Interaction:
- **You can interact with what you're carrying!**
- Example: Pick up a crate, then open it (if it has container component)
- Example: Pick up item, add to inventory while holding

#### Null Safety:
- Checks `is_instance_valid(carried_object)`
- If object deleted, clean up state

#### UI Blocking:
- `ignore_open_gui` check
- Can't add to inventory while inventory UI open

**This is advanced** - skip initially, just support drop.

---

## PickupComponent - Inventory Items

**File:** `addons/cogito/Components/Interactions/PickupComponent.gd`

### Complete Implementation

```gdscript
extends InteractionComponent
class_name PickupComponent

@export var slot_data : InventorySlotPD
@export var display_item_name : bool = false

var player_interaction_component

func _enter_tree() -> void:
    if display_item_name:
        var owner_object : CogitoObject = get_parent()
        owner_object.display_name = slot_data.inventory_item.name

func interact(_player_interaction_component: PlayerInteractionComponent):
    if !is_disabled:
        pick_up(_player_interaction_component)

func pick_up(_player_interaction_component: PlayerInteractionComponent):
    ### Currency Item handling
    if slot_data.inventory_item is CurrencyItemPD and slot_data.inventory_item.add_on_pickup:
        if slot_data.inventory_item.use(_player_interaction_component.get_parent()):
            Audio.play_sound(slot_data.inventory_item.sound_pickup)
            was_interacted_with.emit(interaction_text, input_map_action)
            self.get_parent().queue_free()
            return
        else:
            _player_interaction_component.send_hint(slot_data.inventory_item.icon, 
                tr(slot_data.inventory_item.name) + " " + tr("HINT_cant_pick_up"))
            return
    
    // Attempt to add to inventory
    if not _player_interaction_component.get_parent().inventory_data.pick_up_slot_data(slot_data):
        return

    // Update wieldable UI if picked up ammo
    if _player_interaction_component.is_wielding:
        var is_ammo: bool = "reload_amount" in slot_data.inventory_item
        var is_current_ammo: bool = _player_interaction_component.equipped_wieldable_item.ammo_item_name == slot_data.inventory_item.name
        if is_ammo and is_current_ammo:
            var equipped_wieldable = _player_interaction_component.equipped_wieldable_item
            if equipped_wieldable.charge_current < equipped_wieldable.charge_max:
                _player_interaction_component.equipped_wieldable_item.update_wieldable_data(_player_interaction_component)

    // Success feedback
    _player_interaction_component.send_hint(slot_data.inventory_item.icon, 
        tr(slot_data.inventory_item.name) + " " + tr("INVENTORY_add_item"))
    was_interacted_with.emit(interaction_text, input_map_action)
    Audio.play_sound(slot_data.inventory_item.sound_pickup)
    
    // DESTROY THE OBJECT
    self.get_parent().queue_free()
```

**Key Insights:**

### 1. Slot Data Structure
- `@export var slot_data : InventorySlotPD`
- This is a **Resource** containing:
  - `inventory_item` (the item data)
  - `quantity` (how many)

### 2. Display Name Feature
- Optional: Shows item name in world
- Sets parent object's `display_name` on `_enter_tree()`

### 3. Currency Auto-Consume
- Special case: Currency items can auto-add on pickup
- Calls `item.use()` instead of adding to inventory
- Example: Coins auto-add to wallet

### 4. Inventory Integration
- Calls `inventory_data.pick_up_slot_data(slot_data)`
- Returns `false` if inventory full
- On failure, just return (silent fail - could add hint)

### 5. Ammo Update (Wieldable Integration)
- If player holding weapon
- If picked up ammo for that weapon
- Update the weapon UI
- **You can skip this** if no weapons

### 6. Success Feedback
- Send hint to player (icon + text)
- Emit signal
- Play pickup sound

### 7. Object Destruction
- **`queue_free()`** - Deletes the pickup object
- This is why respawning is hard in Cogito
- Object is gone from scene

**Critical Pattern:**
```gdscript
// Sequence:
1. Validate (not disabled)
2. Try to add to inventory
3. If failed, return early
4. If succeeded:
   - Show feedback
   - Play sound
   - Emit signal
   - Destroy object
```

---

## Item Resource System

### InventoryItemPD (Base Class)

**File:** `addons/cogito/InventoryPD/CustomResources/InventoryItemPD.gd`

```gdscript
extends Resource
class_name InventoryItemPD

@export var name : String = ""
@export_multiline var description : String = ""
@export var icon : Texture2D
@export var is_stackable : bool = false
@export var is_droppable : bool = true
@export var is_unique : bool = false
@export_range(1, 99) var stack_size : int
@export var drop_scene : String  // Path to scene when dropped

// Quickslot binding
@export var can_auto_slot: bool = false
@export var slot_number: int = -1

// Runtime variables
var player_interaction_component
var is_being_wielded : bool
var wielded_item
```

**Key Insights:**

#### Core Properties:
- **name/description/icon**: Display data
- **is_stackable**: Can multiple be in one slot?
- **stack_size**: Max stack (if stackable)
- **is_unique**: Only one allowed in entire world
- **is_droppable**: Can player drop it?

#### Drop Scene:
- Path (as String) to a scene file
- When item dropped, this scene is instantiated
- Example: `"res://items/health_potion_pickup.tscn"`

#### Why String Path vs. PackedScene?
- Avoids circular dependencies
- Smaller resource file size
- Loaded on demand

**Minimal version for your project:**
```gdscript
extends Resource
class_name InventoryItem

@export var item_name : String = ""
@export var icon : Texture2D
@export var is_stackable : bool = false
@export var stack_size : int = 1
@export var drop_scene : PackedScene  // Can use PackedScene if simpler
```

---

### InventorySlotPD

**File:** `addons/cogito/InventoryPD/CustomResources/InventorySlotPD.gd`

```gdscript
extends Resource
class_name InventorySlotPD

signal stack_has_changed

@export var inventory_item : InventoryItemPD
@export var quantity : int = 1:
    set(value):
        quantity = value
        stack_has_changed.emit()

@export var origin_index = -1  // For grid inventory

func can_merge_with(other_slot_data: InventorySlotPD) -> bool:
    return (inventory_item == other_slot_data.inventory_item
            or inventory_item.name == other_slot_data.inventory_item.name) \
            and inventory_item.is_stackable \
            and quantity < inventory_item.stack_size

func can_fully_merge_with(other_slot_data: InventorySlotPD) -> bool:
    return (inventory_item == other_slot_data.inventory_item
            or inventory_item.name == other_slot_data.inventory_item.name) \
            and inventory_item.is_stackable \
            and quantity + other_slot_data.quantity <= inventory_item.stack_size

func fully_merge_with(other_slot_data: InventorySlotPD):
    quantity += other_slot_data.quantity
```

**Key Insights:**

#### Purpose:
- Container for items in inventory
- Tracks quantity
- Handles stacking logic

#### Merge Logic:
- `can_merge_with()`: Can add more to this stack?
- `can_fully_merge_with()`: Can add ALL of other stack?
- `fully_merge_with()`: Combine two stacks

#### Stacking Rules:
1. Must be same item
2. Item must be stackable
3. Total quantity <= stack_size

**Simplified version:**
```gdscript
extends Resource
class_name InventorySlot

@export var item : InventoryItem
@export var quantity : int = 1

func can_stack_with(other: InventorySlot) -> bool:
    return item == other.item and item.is_stackable and quantity < item.stack_size

func add_quantity(amount: int):
    quantity += amount
```

---

### CogitoInventory (Inventory Container)

**File:** `addons/cogito/InventoryPD/cogito_inventory.gd`

```gdscript
extends Resource
class_name CogitoInventory

signal inventory_updated(inventory_data: CogitoInventory)

@export var inventory_size : Vector2i = Vector2i(4,1)  // Grid size
@export var inventory_slots : Array[InventorySlotPD]

func pick_up_slot_data(slot_data: InventorySlotPD) -> bool:
    // Try to stack with existing
    for index in inventory_slots.size():
        slot_data.origin_index = index
        if inventory_slots[index] and inventory_slots[index].can_fully_merge_with(slot_data):
            inventory_slots[index].fully_merge_with(slot_data)
            inventory_updated.emit(self)
            return true
    
    // Find empty slot
    for index in inventory_slots.size():
        slot_data.origin_index = index
        if not inventory_slots[index]:
            inventory_slots[index] = slot_data
            inventory_updated.emit(self)
            return true
    
    // Inventory full
    return false
```

**Key Insights:**

#### Two-Pass Algorithm:
1. First pass: Try to stack with existing items
2. Second pass: Find empty slot
3. If both fail, return false (inventory full)

#### Why This Order?
- Keeps inventory organized
- Fills existing stacks before creating new ones
- Player-friendly behavior

#### Signal Emission:
- `inventory_updated` emitted on every change
- UI can react to this signal
- Updates inventory display

**Simplified version (list-based, not grid):**
```gdscript
extends Resource
class_name Inventory

signal changed()

@export var max_slots : int = 20
var slots : Array[InventorySlot] = []

func add_item(item: InventoryItem, amount: int = 1) -> bool:
    // Try to stack
    if item.is_stackable:
        for slot in slots:
            if slot.item == item and slot.quantity < item.stack_size:
                var space = item.stack_size - slot.quantity
                var to_add = min(amount, space)
                slot.quantity += to_add
                amount -= to_add
                changed.emit()
                if amount <= 0:
                    return true
    
    // Create new slots for remaining
    while amount > 0 and slots.size() < max_slots:
        var new_slot = InventorySlot.new()
        new_slot.item = item
        new_slot.quantity = min(amount, item.stack_size if item.is_stackable else 1)
        slots.append(new_slot)
        amount -= new_slot.quantity
        changed.emit()
    
    return amount == 0
```

---

## Implementation Recommendations

### Phase 1: Basic Carrying (Week 1)

**What to implement:**
1. CarryableComponent (simplified)
2. Player carry state
3. Basic physics carrying

**Skip:**
- Manual rotation
- Stamina system
- Advanced throw calculations

**Minimal CarryableComponent:**
```gdscript
extends InteractionComponent
class_name CarryableComponent

signal being_carried(state: bool)

@export var carry_distance_offset : float = 0
@export var carry_smoothness : float = 10.0
@export var drop_distance : float = 1.5

var parent_rigid_body: RigidBody3D
var player_ref: PlayerInteractionComponent
var is_carried: bool = false
var carry_target: Vector3

func _ready():
    parent_rigid_body = get_parent() as RigidBody3D
    if !parent_rigid_body:
        push_error("CarryableComponent must be child of RigidBody3D")

func interact(player_interaction: PlayerInteractionComponent):
    if is_carried:
        drop()
    else:
        pickup(player_interaction)

func pickup(player_interaction: PlayerInteractionComponent):
    player_ref = player_interaction
    parent_rigid_body.lock_rotation = true
    parent_rigid_body.freeze = false
    player_ref.start_carrying(self)
    is_carried = true
    being_carried.emit(true)

func drop():
    parent_rigid_body.lock_rotation = false
    player_ref.stop_carrying()
    player_ref = null
    is_carried = false
    being_carried.emit(false)

func throw(power: float):
    var direction = player_ref.get_look_direction()
    drop()
    parent_rigid_body.apply_central_impulse(direction * power)

func _physics_process(_delta):
    if is_carried and player_ref:
        carry_target = player_ref.get_carry_position(carry_distance_offset)
        parent_rigid_body.linear_velocity = (carry_target - parent_rigid_body.global_position) * carry_smoothness
        
        if parent_rigid_body.global_position.distance_to(carry_target) > drop_distance:
            drop()
```

**Minimal PlayerInteractionComponent additions:**
```gdscript
@export var carry_marker: Node3D  // Marker3D in scene
var carried_object: CarryableComponent = null

func start_carrying(carryable: CarryableComponent):
    carried_object = carryable

func stop_carrying():
    carried_object = null

func get_carry_position(offset: float) -> Vector3:
    if !carry_marker:
        return global_position
    var camera = get_viewport().get_camera_3d()
    var forward = -camera.global_transform.basis.z
    return carry_marker.global_position + forward * offset

func get_look_direction() -> Vector3:
    var camera = get_viewport().get_camera_3d()
    return -camera.global_transform.basis.z

func _input(event):
    if carried_object and event.is_action_pressed("action_primary"):
        carried_object.throw(15.0)
```

---

### Phase 2: Inventory Pickups (Week 2)

**What to implement:**
1. InventoryItem resource
2. InventorySlot resource
3. Inventory resource (simple list)
4. PickupComponent

**Skip:**
- Grid inventory
- Currency items
- Ammo/wieldable integration
- Advanced stacking

**Minimal Resources:**
```gdscript
// inventory_item.gd
extends Resource
class_name InventoryItem

@export var item_name: String = ""
@export var icon: Texture2D
@export var is_stackable: bool = false
@export var max_stack: int = 1
```

```gdscript
// inventory_slot.gd
extends Resource
class_name InventorySlot

var item: InventoryItem
var quantity: int = 1
```

```gdscript
// inventory.gd
extends Resource
class_name Inventory

signal updated()

@export var max_slots: int = 20
var slots: Array[InventorySlot] = []

func add_item(item: InventoryItem, qty: int = 1) -> bool:
    // Try to stack
    if item.is_stackable:
        for slot in slots:
            if slot.item == item and slot.quantity < item.max_stack:
                var add_amount = min(qty, item.max_stack - slot.quantity)
                slot.quantity += add_amount
                qty -= add_amount
                updated.emit()
                if qty == 0:
                    return true
    
    // New slot
    if slots.size() < max_slots:
        var new_slot = InventorySlot.new()
        new_slot.item = item
        new_slot.quantity = min(qty, item.max_stack if item.is_stackable else 1)
        slots.append(new_slot)
        updated.emit()
        return true
    
    return false
```

```gdscript
// pickup_component.gd
extends InteractionComponent
class_name PickupComponent

@export var item: InventoryItem
@export var quantity: int = 1

func interact(player_interaction: PlayerInteractionComponent):
    var player = player_interaction.get_parent()
    if player.inventory.add_item(item, quantity):
        // Success
        Audio.play_sound(item.pickup_sound)
        player_interaction.show_hint(item.icon, item.item_name + " added")
        get_parent().queue_free()
    else:
        // Failed
        player_interaction.show_hint(null, "Inventory full")
```

---

### Phase 3: Polish (Week 3)

**Add:**
- Sounds (pickup, drop, throw)
- Visual feedback (outline on hover)
- Better UI hints
- Drop functionality (spawn pickup in world)

**Drop Implementation:**
```gdscript
// In Inventory:
func drop_item(slot_index: int) -> bool:
    if slot_index < 0 or slot_index >= slots.size():
        return false
    
    var slot = slots[slot_index]
    if !slot or !slot.item.is_droppable:
        return false
    
    // Spawn pickup in world
    var pickup_scene = load(slot.item.drop_scene)
    if pickup_scene:
        var pickup = pickup_scene.instantiate()
        get_tree().current_scene.add_child(pickup)
        pickup.global_position = player.global_position + player.get_forward() * 2.0
        pickup.item = slot.item
        pickup.quantity = slot.quantity
    
    // Remove from inventory
    slots.remove_at(slot_index)
    updated.emit()
    return true
```

---

### What NOT to Implement (Yet)

❌ **Skip These:**
1. Grid inventory (complex UI)
2. Item durability
3. Item modifications/upgrades
4. Equipment slots (armor, weapons)
5. Currency system
6. Quest items
7. Combinable items
8. Wieldable system (unless you need weapons)
9. Ammo/reload system
10. Manual rotation of carried objects
11. Stamina drain on throw
12. Save/load persistence

**Why skip?**
- Get basic systems working first
- Add complexity incrementally
- Test each feature thoroughly
- Many are game-specific

---

### Testing Checklist

**Carrying:**
- [ ] Can pick up RigidBody3D objects
- [ ] Objects float smoothly in front of player
- [ ] Objects don't clip through walls
- [ ] Can drop objects
- [ ] Can throw objects
- [ ] Objects respond to physics after drop
- [ ] Can't carry through narrow gaps
- [ ] Auto-drops if too far

**Inventory:**
- [ ] Can pick up items
- [ ] Items add to inventory
- [ ] Stackable items stack correctly
- [ ] Inventory full message appears
- [ ] Can drop items from inventory
- [ ] Dropped items spawn in world
- [ ] Pickup feedback (sound, message)
- [ ] Inventory UI updates

---

### Performance Notes

**From Cogito:**

1. **Physics updates in `_physics_process()`** not `_process()`
   - Consistent with physics engine
   - Prevents jitter

2. **Use velocity, not position**
   - Smoother movement
   - Better physics interaction
   - Prevents tunneling

3. **Cache references**
   - `parent_object` cached in `_ready()`
   - Camera cached when needed
   - Don't `get_viewport()` every frame

4. **Null checks on interactions**
   - `is_instance_valid()` before using references
   - Prevents crashes on scene transitions
   - Handle freed objects gracefully

5. **Signals for UI updates**
   - Don't poll state every frame
   - Emit signal when state changes
   - UI reacts to signals

---

### Common Pitfalls

#### 1. Forgetting to Unfreeze
```gdscript
// WRONG:
parent_object.freeze = true  // Object won't move!

// RIGHT:
parent_object.freeze = false  // Can move via velocity
parent_object.lock_rotation = true  // But won't rotate
```

#### 2. Direct Position Setting
```gdscript
// WRONG (jittery, teleporty):
object.global_position = target

// RIGHT (smooth, physics-based):
object.linear_velocity = (target - object.global_position) * smoothing
```

#### 3. Not Excluding from Raycast
```gdscript
// WRONG: Player will constantly detect held object

// RIGHT:
interaction_raycast.add_exception(carried_object)
// On drop:
interaction_raycast.remove_exception(carried_object)
```

#### 4. No Null Checks
```gdscript
// WRONG:
carried_object.drop()  // Crash if object freed!

// RIGHT:
if carried_object and is_instance_valid(carried_object):
    carried_object.drop()
```

#### 5. Wrong Physics Layer
```gdscript
// Make sure RigidBody3D is on correct collision layer
// Otherwise raycast won't detect it
// Or it will collide with player
```

---

### Quick Reference

**Key Values from Cogito:**
- `carrying_velocity_multiplier`: 10 (smooth following)
- `drop_distance`: 1.5 meters (auto-drop threshold)
- `throw_power`: 15-25 (reasonable throw force)
- `drop_power`: 1.0 (gentle placement)
- `rotation_speed`: 2.0 degrees/second (manual rotation)

**Key Methods:**
- `apply_central_impulse(Vector3)` - For throwing
- `set_linear_velocity(Vector3)` - For carrying
- `set_lock_rotation_enabled(bool)` - Prevent tumbling
- `add_exception(Node)` - Exclude from raycast

**Key Patterns:**
- Velocity-based movement (not position)
- Signal-based UI updates (not polling)
- Null validation before use
- Cache references, don't look up every frame
- Two-pass inventory add (stack, then new slot)

---

## Summary

### What Cogito Does Well:
1. **Smooth physics carrying** via velocity
2. **Clean component architecture**
3. **Resource-based items** (serializable, reusable)
4. **Signal-driven updates**
5. **Good validation** and error handling

### What to Simplify:
1. **Skip grid inventory** - use simple list
2. **Skip manual rotation** - add later if needed
3. **Skip stamina** - just throw with fixed power
4. **Skip ammo/wieldables** - unless you need weapons
5. **Fixed throw power** - skip mass calculation initially

### Implementation Order:
1. **Week 1**: Basic carrying (velocity-based, drop/throw)
2. **Week 2**: Inventory pickups (simple list, stacking)
3. **Week 3**: Polish (sounds, hints, drop from inventory)
4. **Week 4+**: Advanced features as needed

### Core Takeaways:
- **Use velocity**, not position for carrying
- **Lock rotation**, keep physics active
- **Exclude from raycast** when carrying
- **Validate references** before using
- **Emit signals** for state changes
- **Start simple**, add complexity later

**You now have everything needed to implement a solid pickup and carrying system!** 🎮

---

**Next Steps:**
1. Create your simplified CarryableComponent
2. Add carry state to your PlayerInteractionComponent
3. Test with a few RigidBody3D boxes
4. Once working, add inventory system
5. Polish with feedback and edge cases

Good luck! The code patterns above should get you 90% of the way there. The remaining 10% will be game-specific tweaks and polish.
