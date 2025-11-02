# Studio Sim - Pickup & Physics System Roadmap
**Based on COGITO Implementation Analysis**  
**Date:** November 1, 2025  
**Goal:** Implement physics-based carrying and inventory pickup systems

---

## 📊 Current State Assessment

### ✅ What We Have (Strengths):
- **Component-based architecture** - `InteractionComponent` base class working well
- **Centralized player interaction** - `PlayerInteractionComponent` handles raycasting
- **Clean interaction patterns** - BoxInteraction, ArtboxInteraction, BoomboxInteraction
- **Signal-based communication** - Objects emit state changes
- **Working HUD system** - Shows interaction prompts
- **3D audio system** - Spatial sound working
- **Animation integration** - Complex multi-stage animations working

### ❌ What We're Missing (From COGITO):
- **Physics-based carrying system** - Can't pick up/carry RigidBody3D objects
- **Inventory system** - No item storage/management
- **Pickup components** - No way to collect items
- **Resource-based items** - No item data structure
- **Carryable objects** - No objects that can be physically held
- **Throw mechanics** - No way to toss carried objects

### 🎯 Gap Analysis:
Our current system is **great for stateful interactions** (boxes, switches, etc.) but **lacks physics manipulation** and **item collection**. COGITO excels at both.

---

## 🗺️ Implementation Roadmap

### Phase 1: Physics Carrying System (Week 1) 🔴
**Priority:** CRITICAL  
**Time Estimate:** 8-10 hours  
**Dependencies:** None (uses existing infrastructure)

#### Task 1.1: Create CarryableComponent ⭐⭐⭐
**Time:** 3-4 hours  
**File:** `scripts/components/CarryableComponent.gd`

**What to Build:**
```gdscript
extends InteractionComponent
class_name CarryableComponent

# Simplified version based on COGITO analysis
# Focus on core carrying mechanics without advanced features

@export_group("Carry Settings")
@export var carry_distance_offset: float = 0.0
@export var carry_smoothness: float = 10.0
@export var drop_distance: float = 1.5
@export var lock_rotation_when_carried: bool = true

@export_group("Throw Settings")
@export var throw_power: float = 15.0
@export var drop_power: float = 1.0

@export_group("Audio")
@export var pickup_sound: AudioStream
@export var drop_sound: AudioStream

var parent_rigid_body: RigidBody3D
var player_ref: PlayerInteractionComponent
var is_carried: bool = false
var carry_target: Vector3
```

**Key Implementation Details:**
- Must be child of `RigidBody3D`
- Uses **velocity-based movement** (not position teleporting)
- Locks rotation during carry (prevents tumbling)
- Auto-drops if object gets too far away
- Excludes from raycast when carried

**Success Criteria:**
- [ ] Can pick up RigidBody3D objects smoothly
- [ ] Objects float in front of camera
- [ ] Can drop/throw objects
- [ ] No clipping through walls
- [ ] Auto-drop protection works

**Testing:**
1. Create test box (RigidBody3D + CollisionShape3D + MeshInstance3D)
2. Add CarryableComponent as child
3. Test pickup/carry/drop/throw
4. Test wall collision handling
5. Test rapid pickup/drop

---

#### Task 1.2: Extend PlayerInteractionComponent (Carry State) ⭐⭐⭐
**Time:** 2-3 hours  
**File:** `scripts/PlayerInteractionComponent.gd`

**What to Add:**
```gdscript
# In PlayerInteractionComponent.gd

@export var carry_marker: Node3D  # Marker3D for carry position
var carried_object: CarryableComponent = null

var is_carrying: bool:
    get: return carried_object != null

func start_carrying(carryable: CarryableComponent):
    carried_object = carryable
    _rebuild_interaction_prompts()

func stop_carrying():
    carried_object = null
    _rebuild_interaction_prompts()

func get_carry_position(offset: float) -> Vector3:
    if !carry_marker:
        return global_position
    
    var camera = get_viewport().get_camera_3d()
    var forward = -camera.global_transform.basis.z
    
    # Check for wall collisions
    var target = carry_marker.global_position + forward * offset
    
    if _raycast.is_colliding():
        var collision_point = _raycast.get_collision_point()
        var to_target = _raycast.global_position.distance_squared_to(target)
        var to_collision = _raycast.global_position.distance_squared_to(collision_point)
        if to_collision < to_target:
            return collision_point
    
    return target

func get_look_direction() -> Vector3:
    var camera = get_viewport().get_camera_3d()
    return -camera.global_transform.basis.z

func throw_carried_object():
    if carried_object and is_instance_valid(carried_object):
        carried_object.throw(15.0)  # Fixed throw power

func drop_carried_object():
    if carried_object and is_instance_valid(carried_object):
        carried_object.throw(1.0)  # Gentle drop
```

**Scene Setup Required:**
1. Add `Marker3D` as child of Camera3D (name: "CarryMarker")
2. Position it ~2 units in front of camera
3. Assign to `carry_marker` export in PlayerInteractionComponent

**Input Handling:**
```gdscript
# Add to _input() in PlayerInteractionComponent

func _input(event: InputEvent) -> void:
    # Throw while carrying (primary action = left click)
    if is_carrying and event.is_action_pressed("action_primary"):
        throw_carried_object()
        return
    
    # Drop while carrying (interact again)
    if is_carrying and event.is_action_pressed("interact"):
        drop_carried_object()
        return
    
    # Normal interaction
    if event.is_action_pressed("interact") and current_interactable:
        _handle_interaction()
```

**Success Criteria:**
- [ ] Player stores reference to carried object
- [ ] Carry position calculates correctly
- [ ] Wall collision detection works
- [ ] Throw/drop input works
- [ ] Can't interact with other objects while carrying

---

#### Task 1.3: Create Test Scene ⭐⭐
**Time:** 1 hour  
**File:** `scenes/test_carry.tscn`

**Scene Structure:**
```
Node3D (root)
├── Player (CharacterBody3D)
├── TestBox1 (RigidBody3D)
│   ├── CollisionShape3D
│   ├── MeshInstance3D (BoxMesh)
│   └── CarryableComponent
├── TestBox2 (RigidBody3D, mass=5.0)
│   ├── CollisionShape3D
│   ├── MeshInstance3D (BoxMesh)
│   └── CarryableComponent
├── TestSphere (RigidBody3D)
│   ├── CollisionShape3D
│   ├── MeshInstance3D (SphereMesh)
│   └── CarryableComponent
└── TestWalls (StaticBody3D)
    └── ...
```

**Test Checklist:**
- [ ] Light object (1kg) - should float smoothly
- [ ] Heavy object (5kg) - should feel more sluggish
- [ ] Sphere object - test rotation locking
- [ ] Wall obstacles - test collision detection
- [ ] Rapid pickup/drop - test state cleanup

---

#### Task 1.4: Update HUD for Carry State ⭐
**Time:** 1 hour  
**File:** `scripts/HUD.gd`

**What to Add:**
```gdscript
# In HUD.gd

@onready var carry_hint: Label = $CarryHint  # New label

func _ready():
    # ... existing code ...
    if player.has_node("PlayerInteractionComponent"):
        var pic = player.get_node("PlayerInteractionComponent")
        pic.interaction_prompt_changed.connect(_on_prompt_changed)
        # Add listener for carry state changes if needed

func _process(_delta):
    # Show carry controls when holding object
    if player and player.has_node("PlayerInteractionComponent"):
        var pic = player.get_node("PlayerInteractionComponent")
        if pic.is_carrying:
            carry_hint.text = "[E] Drop  [Left Click] Throw"
            carry_hint.show()
        else:
            carry_hint.hide()
```

**HUD Scene Updates:**
```
CanvasLayer (HUD)
├── InteractionPrompt (Label) [existing]
└── CarryHint (Label) [NEW]
    - Position: Bottom-center
    - Text: "[E] Drop  [Left Click] Throw"
    - Initially hidden
```

**Success Criteria:**
- [ ] Carry hint shows when holding object
- [ ] Carry hint hides when not holding object
- [ ] Normal interaction prompts hidden while carrying
- [ ] Clear visual feedback for controls

---

### Phase 2: Inventory System (Week 2) 🟡
**Priority:** HIGH  
**Time Estimate:** 10-12 hours  
**Dependencies:** Phase 1 complete and tested

#### Task 2.1: Create Item Resource System ⭐⭐⭐
**Time:** 2-3 hours  
**Files:**
- `resources/items/InventoryItem.gd` (Resource class)
- `resources/items/InventorySlot.gd` (Resource class)
- `resources/items/Inventory.gd` (Resource class)

**InventoryItem.gd:**
```gdscript
extends Resource
class_name InventoryItem

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var is_stackable: bool = false
@export var max_stack_size: int = 1

@export_group("Audio")
@export var pickup_sound: AudioStream
@export var drop_sound: AudioStream
@export var use_sound: AudioStream

@export_group("World Representation")
@export var drop_scene: PackedScene  # Scene to spawn when dropped
```

**InventorySlot.gd:**
```gdscript
extends Resource
class_name InventorySlot

signal quantity_changed(new_quantity: int)

@export var item: InventoryItem
@export var quantity: int = 1:
    set(value):
        quantity = value
        quantity_changed.emit(quantity)

func can_stack_with(other: InventorySlot) -> bool:
    return (item == other.item 
            and item.is_stackable 
            and quantity < item.max_stack_size)

func add_quantity(amount: int) -> int:
    var space = item.max_stack_size - quantity
    var to_add = min(amount, space)
    quantity += to_add
    return amount - to_add  # Return overflow

func remove_quantity(amount: int) -> bool:
    if quantity >= amount:
        quantity -= amount
        return true
    return false
```

**Inventory.gd:**
```gdscript
extends Resource
class_name Inventory

signal inventory_changed()
signal item_added(item: InventoryItem, amount: int)
signal item_removed(item: InventoryItem, amount: int)

@export var max_slots: int = 20
@export var slots: Array[InventorySlot] = []

func add_item(item: InventoryItem, amount: int = 1) -> bool:
    var remaining = amount
    
    # First pass: try to stack with existing items
    if item.is_stackable:
        for slot in slots:
            if slot.item == item:
                remaining = slot.add_quantity(remaining)
                if remaining <= 0:
                    inventory_changed.emit()
                    item_added.emit(item, amount)
                    return true
    
    # Second pass: create new slots for remaining items
    while remaining > 0 and slots.size() < max_slots:
        var new_slot = InventorySlot.new()
        new_slot.item = item
        var stack_amount = min(remaining, item.max_stack_size if item.is_stackable else 1)
        new_slot.quantity = stack_amount
        slots.append(new_slot)
        remaining -= stack_amount
    
    if remaining < amount:
        inventory_changed.emit()
        item_added.emit(item, amount - remaining)
    
    return remaining == 0

func remove_item(item: InventoryItem, amount: int = 1) -> bool:
    var remaining = amount
    
    for i in range(slots.size() - 1, -1, -1):  # Iterate backwards
        if slots[i].item == item:
            if slots[i].quantity <= remaining:
                remaining -= slots[i].quantity
                slots.remove_at(i)
            else:
                slots[i].remove_quantity(remaining)
                remaining = 0
            
            if remaining == 0:
                inventory_changed.emit()
                item_removed.emit(item, amount)
                return true
    
    return false

func has_item(item: InventoryItem, amount: int = 1) -> bool:
    var total = 0
    for slot in slots:
        if slot.item == item:
            total += slot.quantity
    return total >= amount

func get_item_count(item: InventoryItem) -> int:
    var total = 0
    for slot in slots:
        if slot.item == item:
            total += slot.quantity
    return total

func is_full() -> bool:
    return slots.size() >= max_slots

func clear():
    slots.clear()
    inventory_changed.emit()
```

**Create Example Items:**
1. Create `res://resources/items/` folder
2. Create `example_key.tres` (InventoryItem resource)
   - item_name: "Office Key"
   - is_stackable: false
   - icon: key icon texture
3. Create `example_coin.tres` (InventoryItem resource)
   - item_name: "Coin"
   - is_stackable: true
   - max_stack_size: 99
   - icon: coin icon texture

**Success Criteria:**
- [ ] Can create item resources in editor
- [ ] Items can be added/removed programmatically
- [ ] Stacking works correctly
- [ ] Signals emit on inventory changes
- [ ] Full inventory detection works

---

#### Task 2.2: Add Inventory to Player ⭐⭐
**Time:** 1 hour  
**File:** `scripts/PlayerController.gd`

**What to Add:**
```gdscript
# In PlayerController.gd

@export var inventory: Inventory  # Assign in editor or create in _ready()

func _ready():
    # ... existing code ...
    
    # Setup inventory if not assigned
    if not inventory:
        inventory = Inventory.new()
        inventory.max_slots = 20
    
    # Connect to inventory signals for feedback
    inventory.item_added.connect(_on_item_added)
    inventory.item_removed.connect(_on_item_removed)

func _on_item_added(item: InventoryItem, amount: int):
    print("✅ Added to inventory: " + item.item_name + " x" + str(amount))
    # TODO: Show UI notification

func _on_item_removed(item: InventoryItem, amount: int):
    print("❌ Removed from inventory: " + item.item_name + " x" + str(amount))
    # TODO: Show UI notification
```

**Success Criteria:**
- [ ] Player has inventory instance
- [ ] Inventory persists during gameplay
- [ ] Signals connected and working
- [ ] Can access inventory from other scripts

---

#### Task 2.3: Create PickupComponent ⭐⭐⭐
**Time:** 2-3 hours  
**File:** `scripts/components/PickupComponent.gd`

**Implementation:**
```gdscript
extends InteractionComponent
class_name PickupComponent

@export var item: InventoryItem  # Item to give player
@export var quantity: int = 1
@export var destroy_on_pickup: bool = true
@export var respawn_time: float = 0.0  # 0 = no respawn

var _can_pickup: bool = true

func _on_ready():
    if item:
        interaction_text = "Pick Up " + item.item_name
    else:
        interaction_text = "Pick Up Item"
        push_error("PickupComponent has no item assigned!")

func _on_interacted(player_interaction: PlayerInteractionComponent):
    if not _can_pickup:
        return
    
    if not item:
        print("❌ No item assigned to pickup!")
        return
    
    var player = player_interaction.get_parent()
    if not player.inventory:
        print("❌ Player has no inventory!")
        return
    
    # Attempt to add item to inventory
    if player.inventory.add_item(item, quantity):
        # Success!
        print("✅ Picked up: " + item.item_name + " x" + str(quantity))
        
        # Play pickup sound
        if item.pickup_sound:
            _play_sound(item.pickup_sound)
        
        # Show feedback to player
        player_interaction.show_hint(item.icon, item.item_name + " added to inventory")
        
        # Handle object destruction/respawn
        if destroy_on_pickup:
            if respawn_time > 0:
                _hide_and_respawn()
            else:
                parent_object.queue_free()
    else:
        # Inventory full
        print("❌ Inventory full!")
        player_interaction.show_hint(null, "Inventory full")

func _hide_and_respawn():
    _can_pickup = false
    parent_object.visible = false
    
    await get_tree().create_timer(respawn_time).timeout
    
    parent_object.visible = true
    _can_pickup = true
    print("♻️ Pickup respawned: " + item.item_name)
```

**Create Test Pickup Scene:**
```
Node3D (PickupItem)
├── MeshInstance3D (visual representation)
├── StaticBody3D or Area3D
│   └── CollisionShape3D
└── PickupComponent
    - item: [assign InventoryItem resource]
    - quantity: 1
    - destroy_on_pickup: true
```

**Success Criteria:**
- [ ] Can pick up items from world
- [ ] Items add to inventory
- [ ] Pickup object disappears (if destroy_on_pickup = true)
- [ ] Inventory full message works
- [ ] Pickup sound plays
- [ ] Respawn works (if enabled)

---

#### Task 2.4: Create Basic Inventory UI ⭐⭐
**Time:** 3-4 hours  
**Files:**
- `scenes/InventoryUI.tscn`
- `scripts/InventoryUI.gd`

**Scene Structure:**
```
CanvasLayer (InventoryUI)
├── Panel (background)
│   ├── VBoxContainer
│   │   ├── Label (title: "Inventory")
│   │   └── GridContainer (slots container)
│   │       ├── InventorySlotUI (x20)
│   │       │   ├── Panel (slot background)
│   │       │   ├── TextureRect (item icon)
│   │       │   └── Label (quantity)
│   └── CloseButton
```

**InventoryUI.gd:**
```gdscript
extends CanvasLayer

@onready var slots_container: GridContainer = $Panel/VBoxContainer/GridContainer
@onready var close_button: Button = $Panel/CloseButton

var player: CharacterBody3D
var inventory: Inventory

func _ready():
    hide()
    close_button.pressed.connect(_on_close)

func setup(player_ref: CharacterBody3D):
    player = player_ref
    inventory = player.inventory
    inventory.inventory_changed.connect(_refresh_ui)
    _refresh_ui()

func _input(event):
    if event.is_action_pressed("toggle_inventory"):
        toggle()

func toggle():
    visible = !visible
    if visible:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        _refresh_ui()
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_close():
    hide()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_ui():
    # Clear all slots
    for child in slots_container.get_children():
        child.queue_free()
    
    # Create slot UI for each inventory slot
    for slot in inventory.slots:
        var slot_ui = _create_slot_ui(slot)
        slots_container.add_child(slot_ui)
    
    # Fill remaining empty slots
    var empty_count = inventory.max_slots - inventory.slots.size()
    for i in empty_count:
        var empty_slot = _create_empty_slot_ui()
        slots_container.add_child(empty_slot)

func _create_slot_ui(slot: InventorySlot) -> Panel:
    var panel = Panel.new()
    panel.custom_minimum_size = Vector2(64, 64)
    
    var icon = TextureRect.new()
    icon.texture = slot.item.icon
    icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    icon.anchor_right = 1.0
    icon.anchor_bottom = 1.0
    panel.add_child(icon)
    
    if slot.item.is_stackable and slot.quantity > 1:
        var quantity_label = Label.new()
        quantity_label.text = str(slot.quantity)
        quantity_label.add_theme_font_size_override("font_size", 12)
        quantity_label.anchor_left = 1.0
        quantity_label.anchor_top = 1.0
        quantity_label.anchor_right = 1.0
        quantity_label.anchor_bottom = 1.0
        quantity_label.offset_left = -20
        quantity_label.offset_top = -20
        panel.add_child(quantity_label)
    
    return panel

func _create_empty_slot_ui() -> Panel:
    var panel = Panel.new()
    panel.custom_minimum_size = Vector2(64, 64)
    return panel
```

**Add Input Action:**
- Project Settings → Input Map
- Add `toggle_inventory` action
- Bind to `I` key and `Tab` key

**Success Criteria:**
- [ ] Inventory UI shows all items
- [ ] Stacks show quantity
- [ ] Empty slots shown
- [ ] Can open/close with I key
- [ ] Mouse shows when inventory open
- [ ] Updates when inventory changes

---

#### Task 2.5: Drop Item from Inventory ⭐⭐
**Time:** 2 hours  
**Files:** Update `InventoryUI.gd` and `Inventory.gd`

**What to Add:**
```gdscript
# In InventoryUI.gd

func _create_slot_ui(slot: InventorySlot) -> Panel:
    var panel = Panel.new()
    # ... existing code ...
    
    # Make slot clickable
    var button = Button.new()
    button.flat = true
    button.anchor_right = 1.0
    button.anchor_bottom = 1.0
    button.mouse_filter = Control.MOUSE_FILTER_PASS
    button.pressed.connect(func(): _on_slot_clicked(slot))
    panel.add_child(button)
    
    return panel

func _on_slot_clicked(slot: InventorySlot):
    # Show context menu or drop item
    _drop_item(slot)

func _drop_item(slot: InventorySlot):
    if not slot.item.drop_scene:
        print("❌ Item has no drop scene assigned")
        return
    
    # Remove from inventory
    inventory.remove_item(slot.item, 1)
    
    # Spawn in world
    var pickup = slot.item.drop_scene.instantiate()
    get_tree().current_scene.add_child(pickup)
    
    # Position in front of player
    var camera = player.get_viewport().get_camera_3d()
    var spawn_pos = camera.global_position + (-camera.global_transform.basis.z * 2.0)
    pickup.global_position = spawn_pos
    
    # Play drop sound
    if slot.item.drop_sound:
        AudioManager.play_sound_3d(slot.item.drop_sound, spawn_pos)
    
    print("📦 Dropped: " + slot.item.item_name)
```

**Create Drop Scenes:**
1. For each item, create a pickup scene
2. Example: `scenes/pickups/key_pickup.tscn`
   ```
   Node3D
   ├── MeshInstance3D (key model)
   ├── StaticBody3D
   │   └── CollisionShape3D
   └── PickupComponent
       - item: [InventoryItem resource]
       - quantity: 1
   ```
3. Assign to `drop_scene` field in InventoryItem resource

**Success Criteria:**
- [ ] Can click slot to drop item
- [ ] Item removed from inventory
- [ ] Pickup spawns in front of player
- [ ] Can pick up dropped items again
- [ ] Drop sound plays

---

### Phase 3: Integration & Polish (Week 3) 🟢
**Priority:** MEDIUM  
**Time Estimate:** 6-8 hours  
**Dependencies:** Phases 1 & 2 complete

#### Task 3.1: Combine Carrying + Inventory ⭐⭐
**Time:** 2-3 hours  
**Goal:** Allow "putting carried object in inventory" if it has both components

**What to Add:**
```gdscript
# In PlayerInteractionComponent.gd

func _handle_interaction(action: String) -> void:
    # Special case: carrying object that also has pickup component
    if is_carrying and is_instance_valid(carried_object):
        var parent = carried_object.get_parent()
        
        # Check if carried object has pickup component
        for child in parent.get_children():
            if child is PickupComponent:
                # Add to inventory while carrying
                child.interact(self)
                # Object will be destroyed, which triggers cleanup
                return
        
        # Normal drop
        if carried_object.input_map_action == action:
            drop_carried_object()
            return
    
    # Normal interaction when not carrying
    if current_interactable and not is_carrying:
        # ... existing code ...
```

**Success Criteria:**
- [ ] Can carry object with PickupComponent
- [ ] Can add to inventory while carrying
- [ ] Proper cleanup when object destroyed

---

#### Task 3.2: Advanced Carry Features ⭐
**Time:** 2 hours  
**Features to Add:**

**Mass-Based Feel:**
```gdscript
# In CarryableComponent.gd

@export var mass_multiplier: float = 1.0

func _physics_process(delta):
    if is_carried:
        # Adjust smoothness based on mass
        var mass = parent_rigid_body.mass * mass_multiplier
        var adjusted_smoothness = carry_smoothness / (1.0 + mass * 0.1)
        
        carry_target = player_ref.get_carry_position(carry_distance_offset)
        parent_rigid_body.linear_velocity = (carry_target - parent_rigid_body.global_position) * adjusted_smoothness
        
        # ... rest of code ...
```

**Rotation Dampening:**
```gdscript
# Prevent objects from spinning wildly when picked up
func pickup(player_interaction: PlayerInteractionComponent):
    # ... existing code ...
    parent_rigid_body.angular_velocity = Vector3.ZERO  # Stop spinning
```

**Distance-Based Drop Warning:**
```gdscript
# Warn player before auto-drop
func _physics_process(delta):
    if is_carried:
        var distance = parent_rigid_body.global_position.distance_to(carry_target)
        
        if distance > drop_distance * 0.8:  # 80% threshold
            # Emit warning signal or show visual feedback
            pass
        
        if distance >= drop_distance:
            drop()
```

---

#### Task 3.3: Audio & Visual Feedback ⭐
**Time:** 1-2 hours  

**Pickup/Drop Sounds:**
- Add to CarryableComponent
- Play on state changes
- 3D spatial audio

**Visual Feedback:**
```gdscript
# In CarryableComponent.gd

@export var outline_material: Material  # Optional highlight shader

func pickup(player_interaction: PlayerInteractionComponent):
    # ... existing code ...
    
    # Add outline when carrying (optional)
    if outline_material:
        _add_outline()

func _add_outline():
    for child in parent_rigid_body.get_children():
        if child is MeshInstance3D:
            child.material_overlay = outline_material
```

**Crosshair Changes:**
```gdscript
# In HUD.gd

func _process(delta):
    if player.has_node("PlayerInteractionComponent"):
        var pic = player.get_node("PlayerInteractionComponent")
        if pic.is_carrying:
            crosshair.modulate = Color.YELLOW  # Different color when carrying
        else:
            crosshair.modulate = Color.WHITE
```

---

#### Task 3.4: Testing & Bug Fixes ⭐⭐
**Time:** 2 hours  

**Comprehensive Test Plan:**

**Carrying Tests:**
- [ ] Pick up light objects (< 1kg)
- [ ] Pick up heavy objects (> 5kg)
- [ ] Carry through doorways
- [ ] Carry near walls
- [ ] Carry up/down stairs
- [ ] Drop from height
- [ ] Throw at walls
- [ ] Rapid pickup/drop cycles
- [ ] Pickup while jumping
- [ ] Pickup while moving

**Inventory Tests:**
- [ ] Pick up non-stackable items until full
- [ ] Pick up stackable items (test stacking)
- [ ] Pick up when inventory full
- [ ] Drop items from inventory
- [ ] Pick up dropped items
- [ ] Open/close inventory repeatedly
- [ ] Pick up items while inventory open (should work)

**Integration Tests:**
- [ ] Carry object with PickupComponent
- [ ] Add carried object to inventory
- [ ] Carry → Drop → Pickup → Inventory
- [ ] Switch between carrying and normal interaction
- [ ] Interact with boxes/switches while carrying (should drop first)

**Edge Cases:**
- [ ] Object deleted while carrying (cleanup?)
- [ ] Player dies while carrying (cleanup?)
- [ ] Scene change while carrying (cleanup?)
- [ ] Save/load with items in inventory (future)

---

### Phase 4: Advanced Features (Optional) 🔵
**Priority:** LOW  
**Time Estimate:** 8-12 hours  
**Dependencies:** All previous phases complete

#### Optional Features to Consider:

**4.1: Manual Object Rotation** (2-3 hours)
- Rotate held objects with mouse wheel
- Helps with precise placement

**4.2: Inventory Quickslots** (3-4 hours)
- Hotbar for frequently used items
- Number keys to access

**4.3: Item Combinations** (4-5 hours)
- Combine items in inventory
- Create new items (crafting-lite)

**4.4: Container System** (3-4 hours)
- Chests/boxes that store items
- Transfer UI between inventories

**4.5: Save/Load Persistence** (4-6 hours)
- Save inventory state
- Save carried object state
- Save world object positions

**⚠️ Don't implement these until core system is solid!**

---

## 🎯 Success Metrics

### Performance Targets:
- [ ] Stable 60 FPS with 20+ carryable objects
- [ ] No physics jitter when carrying
- [ ] Smooth pickup/drop transitions
- [ ] No memory leaks from audio/spawning

### Code Quality Targets:
- [ ] CarryableComponent < 200 lines
- [ ] PickupComponent < 150 lines
- [ ] All code documented
- [ ] No duplicate logic
- [ ] Clear separation of concerns

### User Experience Targets:
- [ ] Carrying feels smooth and responsive
- [ ] Clear visual feedback for all actions
- [ ] Intuitive controls
- [ ] No confusing edge cases
- [ ] Helpful error messages

---

## 📚 Key Learnings from COGITO

### Do This ✅:
1. **Use velocity-based movement** for carried objects (not position)
2. **Lock rotation** when carrying (prevents tumbling)
3. **Exclude from raycast** when carried
4. **Validate references** before using (is_instance_valid)
5. **Two-pass inventory add** (stack first, then new slots)
6. **Emit signals** for all state changes
7. **Resource-based items** (serializable, reusable)
8. **Auto-drop protection** (distance check)

### Don't Do This ❌:
1. **Direct position setting** (causes jitter)
2. **Freeze physics** on carried objects (they need to move)
3. **Forget raycast exclusion** (will detect held object)
4. **Skip null checks** (crashes on cleanup)
5. **Over-engineer early** (start simple)
6. **Grid inventory first** (use simple list)
7. **Add all features at once** (incremental is better)

---

## 🗓️ Week-by-Week Schedule

### Week 1: Physics Carrying
- **Monday:** Task 1.1 - CarryableComponent (3-4 hrs)
- **Tuesday:** Task 1.2 - PlayerInteractionComponent updates (2-3 hrs)
- **Wednesday:** Task 1.3 - Test scene creation (1 hr)
- **Thursday:** Task 1.4 - HUD updates (1 hr)
- **Friday:** Testing & bug fixes (2 hrs)
- **Weekend:** Polish & refinement

### Week 2: Inventory System
- **Monday:** Task 2.1 - Item resources (2-3 hrs)
- **Tuesday:** Task 2.2 - Player inventory + Task 2.3 Start (2 hrs)
- **Wednesday:** Task 2.3 - PickupComponent (2-3 hrs)
- **Thursday:** Task 2.4 - Inventory UI (3-4 hrs)
- **Friday:** Task 2.5 - Drop from inventory (2 hrs)
- **Weekend:** Testing & integration

### Week 3: Integration & Polish
- **Monday:** Task 3.1 - Combine systems (2-3 hrs)
- **Tuesday:** Task 3.2 - Advanced carry features (2 hrs)
- **Wednesday:** Task 3.3 - Audio & visual feedback (1-2 hrs)
- **Thursday:** Task 3.4 - Comprehensive testing (2 hrs)
- **Friday:** Bug fixes & documentation (2 hrs)
- **Weekend:** Final polish & review

---

## 🐛 Common Pitfalls to Avoid

### Physics Issues:
```gdscript
# WRONG - Freezes object (can't move)
parent_rigid_body.freeze = true

# RIGHT - Locks rotation but allows movement
parent_rigid_body.lock_rotation = true
parent_rigid_body.freeze = false
```

### Movement Issues:
```gdscript
# WRONG - Jittery, teleporty
object.global_position = target

# RIGHT - Smooth, physics-based
object.linear_velocity = (target - object.global_position) * smoothness
```

### Raycast Issues:
```gdscript
# WRONG - Will continuously detect held object
# (forgot to exclude)

# RIGHT - Exclude from raycast
interaction_raycast.add_exception(carried_object)
# On drop:
interaction_raycast.remove_exception(carried_object)
```

### Null Reference Issues:
```gdscript
# WRONG - Crashes if object deleted
carried_object.drop()

# RIGHT - Always validate
if carried_object and is_instance_valid(carried_object):
    carried_object.drop()
```

### Inventory Stacking:
```gdscript
# WRONG - Creates new slot every time
slots.append(new_slot)

# RIGHT - Try to stack first
for slot in slots:
    if slot.can_stack_with(new_item):
        slot.add_quantity(amount)
        return
# Then create new slot if needed
```

---

## 🔧 Quick Reference

### Key Values (From COGITO):
- `carry_smoothness`: 10 (smooth following)
- `drop_distance`: 1.5 meters (auto-drop)
- `throw_power`: 15-25 (reasonable throw)
- `drop_power`: 1.0 (gentle placement)

### Key Methods:
- `apply_central_impulse(Vector3)` - For throwing
- `set_linear_velocity(Vector3)` - For carrying
- `lock_rotation = true` - Prevent tumbling
- `add_exception(Node)` - Exclude from raycast

### Key Patterns:
```gdscript
# Velocity-based movement
object.linear_velocity = (target - object.position) * smoothness

# Two-pass inventory add
# 1. Try to stack
# 2. Create new slot

# Always validate before using
if obj and is_instance_valid(obj):
    obj.do_something()

# Signal-based UI updates
signal inventory_changed()
# UI listens and updates
```

---

## ✅ Phase Completion Checklists

### Phase 1 Complete When:
- [ ] Can pick up RigidBody3D objects
- [ ] Objects float smoothly in front of camera
- [ ] Can drop and throw objects
- [ ] Auto-drop works (distance check)
- [ ] No clipping through walls
- [ ] HUD shows carry controls
- [ ] All test objects work
- [ ] No console errors
- [ ] Performance is stable

### Phase 2 Complete When:
- [ ] Item resources created and working
- [ ] Player has inventory
- [ ] Can pick up items from world
- [ ] Items add to inventory correctly
- [ ] Stacking works for stackable items
- [ ] Inventory UI shows all items
- [ ] Can open/close inventory
- [ ] Can drop items from inventory
- [ ] Dropped items can be picked up again
- [ ] Inventory full message works

### Phase 3 Complete When:
- [ ] Can carry objects with PickupComponent
- [ ] Can add carried objects to inventory
- [ ] Mass affects carrying feel
- [ ] Audio feedback works
- [ ] Visual feedback clear
- [ ] All edge cases handled
- [ ] Comprehensive testing complete
- [ ] No major bugs
- [ ] Documentation updated

---

## 📖 Additional Resources

### Documentation Files:
- `COGITO_PICKUP_IMPLEMENTATION_NOTES.md` - Detailed COGITO analysis
- `COGITO_INTERACTION_SYSTEM_ANALYSIS.md` - System architecture
- `REFACTOR_PLAN.md` - Original refactoring plan
- This file (`PICKUP_SYSTEM_ROADMAP.md`) - Implementation roadmap

### Godot Documentation:
- RigidBody3D: https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html
- Resources: https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html
- Signals: https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html

---

## 🎉 Final Notes

### Key Takeaways:
1. **Start simple** - Don't try to implement everything at once
2. **Test frequently** - Catch bugs early
3. **Use COGITO patterns** - They're proven to work well
4. **Focus on feel** - Physics should feel good, not just work
5. **Keep code clean** - Future you will thank you

### Next Steps After Completion:
1. Implement specific items for your studio sim
2. Add game-specific interactions
3. Create more complex item behaviors
4. Consider save/load system
5. Add more polish and juice

**Good luck! You have everything you need to build an amazing pickup and carrying system!** 🚀

---

**Last Updated:** November 1, 2025  
**Status:** Ready to begin Phase 1  
**Estimated Completion:** ~3 weeks (20-30 hours total)
