# COGITO Interaction System - Comprehensive Analysis

**Source Project**: Cogito - First Person Immersive Sim Template for Godot 4  
**Analysis Date**: November 1, 2025  
**Purpose**: Learning reference for implementing component-based interaction systems

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Core Architecture](#core-architecture)
3. [Component-Based Interaction System](#component-based-interaction-system)
4. [Object Types](#object-types)
5. [Inventory & Item System](#inventory--item-system)
6. [Player Attribute System](#player-attribute-system)
7. [Implementation Patterns](#implementation-patterns)
8. [Key Takeaways for Your Project](#key-takeaways-for-your-project)

---

## System Overview

### Philosophy

Cogito uses a **component-based architecture** where:
- **Objects** are dumb containers (just Node3D with collision)
- **Components** define behavior (what you can do with objects)
- **Clear separation** between visual representation and functionality
- **Signal-based communication** between systems

### Key Design Principles

1. **Composition over Inheritance**: Objects get behavior by adding components, not extending classes
2. **Raycast Detection**: Player uses raycast to detect what they're looking at
3. **Signal-Driven UI**: UI updates via signals, not polling
4. **Resource-Based Data**: Items, slots, and inventories are Resources (can be saved/loaded)
5. **Component Discovery**: Parent objects find their child components automatically

---

## Core Architecture

### Three-Layer System

```
┌─────────────────────────────────────────┐
│  PLAYER INTERACTION COMPONENT           │
│  - Manages raycast detection            │
│  - Handles input for interactions       │
│  - Coordinates with HUD                 │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  COGITO OBJECT (Container)              │
│  - Extends Node3D                       │
│  - Must be in "interactable" group      │
│  - Finds and stores child components    │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  INTERACTION COMPONENTS (Behavior)      │
│  - Define what player can do            │
│  - Handle specific interaction logic    │
│  - Emit signals for state changes       │
└─────────────────────────────────────────┘
```

### File Structure

```
addons/cogito/
├── CogitoObjects/           # Object types (containers)
│   ├── cogito_object.gd     # Base object class
│   ├── cogito_door.gd       # Doors, gates
│   ├── cogito_switch.gd     # Switches, levers
│   ├── cogito_container.gd  # Chests, boxes
│   └── ...
│
├── Components/
│   ├── Interactions/        # Interaction components
│   │   ├── InteractionComponent.gd      # BASE CLASS
│   │   ├── PickupComponent.gd
│   │   ├── CarryableComponent.gd
│   │   ├── BasicInteraction.gd
│   │   ├── HoldInteraction.gd
│   │   ├── DualInteraction.gd
│   │   └── ...
│   │
│   ├── Attributes/          # Player attributes (health, stamina)
│   ├── Properties/          # Systemic properties (fire, wet, etc)
│   └── PlayerInteractionComponent.gd  # Player's interaction manager
│
└── InventoryPD/             # Inventory & items
    ├── CustomResources/
    │   ├── InventoryItemPD.gd        # BASE ITEM CLASS
    │   ├── ConsumableItemPD.gd
    │   ├── WieldableItemPD.gd
    │   ├── AmmoItemPD.gd
    │   └── ...
    └── cogito_pickup.gd     # Legacy pickup (deprecated)
```

---

## Component-Based Interaction System

### Base Class: InteractionComponent

**Location**: `addons/cogito/Components/Interactions/InteractionComponent.gd`

```gdscript
class_name InteractionComponent
extends Node3D

signal was_interacted_with(interaction_text, input_map_action)

# Core properties
@export var input_map_action : String      # e.g., "interact", "interact2"
@export var interaction_text : String      # Display text for HUD
@export var is_disabled : bool = false     # Can be toggled on/off
@export var ignore_open_gui : bool = true  # Works when inventory is open?

# Attribute checks (optional requirements)
@export var attribute_check : AttributeCheck
@export var attribute_to_check : String
@export var min_value_to_pass : float
@export var message_on_pass: String
@export var message_on_fail: String

# Consumable effects (optional)
@export var attribute_effects : Array[ConsumableEffect]

# Main interaction function - OVERRIDE THIS
func interact(_player_interaction_component: PlayerInteractionComponent):
    # Your interaction logic here
    pass
```

**Key Methods**:
- `interact()` - Called when player presses interaction button
- `check_attribute()` - Optional requirement checking (strength, health, etc.)
- `set_disabled()` - Can be overridden to dynamically enable/disable

### Interaction Component Types

#### 1. BasicInteraction
**Use Case**: Simple one-time or repeatable interactions

```gdscript
extends InteractionComponent

func interact(_player_interaction_component: PlayerInteractionComponent):
    if parent_node.has_method("interact"):
        parent_node.interact(_player_interaction_component)
    was_interacted_with.emit(interaction_text, input_map_action)
```

**Example Uses**:
- Light switches
- Buttons
- Levers
- Simple doors

---

#### 2. PickupComponent
**Use Case**: Adding items to inventory

```gdscript
extends InteractionComponent
class_name PickupComponent

@export var slot_data : InventorySlotPD  # Contains item + quantity
@export var display_item_name : bool = false

func interact(_player_interaction_component: PlayerInteractionComponent):
    if !is_disabled:
        pick_up(_player_interaction_component)

func pick_up(_player_interaction_component: PlayerInteractionComponent):
    # Add to player inventory
    if _player_interaction_component.get_parent().inventory_data.pick_up_slot_data(slot_data):
        # Play sound, show hint
        Audio.play_sound(slot_data.inventory_item.sound_pickup)
        # DELETE THE OBJECT
        self.get_parent().queue_free()
```

**Important**: Object is destroyed after pickup! (This might not be what you want)

---

#### 3. CarryableComponent
**Use Case**: Physically carrying/throwing objects

```gdscript
extends InteractionComponent
class_name CogitoCarryableComponent

@export var pick_up_sound : AudioStream
@export var drop_sound : AudioStream
@export var is_carryable_while_wielding : bool = false
@export var carry_distance_offset : float = 0
@export var lock_rotation_when_carried : bool = true
@export var carrying_velocity_multiplier : float = 10
@export var drop_distance : float = 3.0

func interact(_player_interaction_component: PlayerInteractionComponent):
    if is_being_carried:
        leave()  # Drop it
    else:
        hold()   # Pick it up

func hold():
    # Freeze physics, tell player to start carrying
    parent_object.freeze = false
    player_interaction_component.start_carrying(self)
    is_being_carried = true

func leave():
    # Drop the object, resume physics
    parent_object.freeze = false
    player_interaction_component.stop_carrying()
    is_being_carried = false
```

**Key Difference**: Object is NOT destroyed, it's physically held in world space

---

#### 4. HoldInteraction
**Use Case**: Actions that require holding button

```gdscript
class_name HoldInteraction
extends InteractionComponent

@export var hold_time : float = 3.0

func interact(_player_interaction_component):
    # Start the hold UI
    var hud = _player_interaction_component.player.get_node(player_hud_path)
    hud.hold_ui.start_holding(self)
```

**Example Uses**:
- Lockpicking
- Hacking terminals
- Long interactions

---

#### 5. DualInteraction
**Use Case**: Two different actions on one object

```gdscript
class_name DualInteraction
extends HoldInteraction

# Quick press = one action
# Hold = different action

# Example: Door
# Quick press = Open/Close
# Hold = Lock/Unlock (if you have key)
```

---

#### 6. ExtendedPickupInteraction
**Use Case**: Instant use vs. pickup choice

```gdscript
class_name ExtendedPickupInteraction
extends HoldInteraction

# Quick press = Use item immediately (consume health potion)
# Hold = Pick up item into inventory

func use() -> void:
    if pickup.slot_data.inventory_item is ConsumableItemPD:
        consume(pickup.slot_data.inventory_item)
    elif pickup.slot_data.inventory_item is AmmoItemPD:
        attempt_reload_current_wieldable(pickup.slot_data.inventory_item)
    elif pickup.slot_data.inventory_item is WieldableItemPD:
        attempt_wield(pickup.slot_data.inventory_item)
```

---

#### 7. ReadableComponent
**Use Case**: Signs, books, notes

```gdscript
extends InteractionComponent
class_name ReadableComponent

@export var readable_title : String
@export_multiline var readable_content : String
@export var rich_text : bool  # BBCode support

func interact(_player_interaction_component: PlayerInteractionComponent):
    if is_open:
        close(_player_interaction_component)
    else:
        open(_player_interaction_component)

func open(_player_interaction_component: PlayerInteractionComponent):
    # Show UI, pause game
    _player_interaction_component.get_parent().toggled_interface.emit(true)
    readable_ui.show()
```

---

### How Components are Discovered

**In CogitoObject.gd**:
```gdscript
var interaction_nodes : Array[Node]

func _ready():
    self.add_to_group("interactable")  # REQUIRED!
    find_interaction_nodes()

func find_interaction_nodes():
    # Finds ALL child nodes that are InteractionComponents
    interaction_nodes = find_children("","InteractionComponent",true)
```

**In PlayerInteractionComponent.gd**:
```gdscript
func _handle_interaction(action: String) -> void:
    if interactable:
        # Loop through all interaction components on the object
        for node: InteractionComponent in interactable.interaction_nodes:
            # Check if this component uses the pressed action
            if node.input_map_action == action and not node.is_disabled:
                node.interact(self)
                break
```

---

## Object Types

### CogitoObject (Base Class)

**Location**: `addons/cogito/CogitoObjects/cogito_object.gd`

```gdscript
class_name CogitoObject
extends Node3D

signal damage_received(damage_value: float)
signal object_exits_tree()

@export var cogito_name : String = self.name
@export var display_name : String  # Shows in HUD

var interaction_nodes : Array[Node]  # Auto-discovered
var cogito_properties : CogitoProperties = null  # Optional

func _ready():
    add_to_group("interactable")  # CRITICAL!
    add_to_group("Persist")       # For saving
    find_interaction_nodes()
    find_cogito_properties()

# Persistence
func save():
    return {
        "filename": get_scene_file_path(),
        "parent": get_parent().get_path(),
        "pos_x": position.x,
        "pos_y": position.y,
        "pos_z": position.z,
        # ... etc
    }
```

**Usage**: Most pickups, props, physics objects

---

### CogitoSwitch

**Location**: `addons/cogito/CogitoObjects/cogito_switch.gd`

```gdscript
class_name CogitoSwitch
extends Node3D

signal object_state_updated(interaction_text: String)
signal switched(is_on: bool)

@export var is_on : bool = false
@export var allows_repeated_interaction : bool = true
@export var interaction_text_when_on : String = "SWITCH_off"
@export var interaction_text_when_off : String = "SWITCH_on"

# Required item to operate
@export var needs_item_to_operate : bool
@export var required_item_slot : InventorySlotPD

# What happens when switched
@export var nodes_to_show_when_on : Array[Node]
@export var nodes_to_hide_when_on : Array[Node]
@export var objects_call_interact : Array[NodePath]

func interact(_player_interaction_component):
    if !allows_repeated_interaction and is_on:
        player_interaction_component.send_hint(null, has_been_used_hint)
        return
    
    switch()

func switch():
    if !is_on:
        switch_on()
    else:
        switch_off()

func switch_on():
    for node in nodes_to_show_when_on:
        node.show()
    for node in nodes_to_hide_when_on:
        node.hide()
    
    is_on = true
    interaction_text = interaction_text_when_on
    object_state_updated.emit(interaction_text)
    switched.emit(is_on)
```

**Key Features**:
- Can control other objects via `objects_call_interact`
- Can require items to operate
- Visual feedback (show/hide nodes)
- Animation support
- State persistence

**Example Uses**:
- Light switches
- Levers
- Power generators
- Item sockets

---

### CogitoDoor

**Location**: `addons/cogito/CogitoObjects/cogito_door.gd`

```gdscript
class_name CogitoDoor
extends Node3D

signal object_state_updated(interaction_text: String)
signal lock_state_updated(lock_interaction_text: String)
signal door_state_changed(is_open: bool)
signal lock_state_changed(is_locked: bool)

enum DoorType { ROTATING, SLIDING, ANIMATED }

@export var door_type := DoorType.ROTATING
@export var is_open : bool = false
@export var is_locked : bool = false
@export var key : KeyItemPD  # Required item to unlock

# Door physics
@export var open_rotation : Vector3 = Vector3.ZERO
@export var closed_rotation : Vector3 = Vector3.ZERO
@export var door_speed : float = 1
@export var bidirectional_swing : bool = false

# Syncing multiple doors
@export var doors_to_sync_with : Array[NodePath]

func interact(_player_interaction_component):
    if is_locked:
        attempt_unlock(_player_interaction_component)
    else:
        toggle()

func toggle():
    if is_open:
        close()
    else:
        open()
```

**Advanced Features**:
- Three door types (rotating, sliding, animated)
- Lock system with key requirements
- Bidirectional swing (opens away from player)
- Auto-close timer
- Multi-door syncing (double doors)

---

### CogitoContainer

**Location**: `addons/cogito/CogitoObjects/cogito_container.gd`

```gdscript
class_name CogitoContainer
extends Node3D

@export var display_name : String = "CONTAINER"
@export var inventory_data : CogitoInventory  # External inventory
@export var text_when_closed : String = "DOOR_Open"
@export var text_when_open : String = "DOOR_Close"

signal toggle_inventory(external_inventory_owner)

func interact(_player_interaction_component: PlayerInteractionComponent):
    toggle_inventory.emit(self)  # Opens UI with this inventory

func open():
    # Play animation, update interaction text
    interaction_text = tr(text_when_open)

func close():
    interaction_text = tr(text_when_closed)
```

**Example Uses**:
- Chests
- Drawers
- Backpacks (dead bodies)
- Storage boxes

---

## Inventory & Item System

### Architecture

```
InventoryItemPD (Resource)
    ↓ referenced by
InventorySlotPD (Resource)
    ↓ contained in
CogitoInventory (Resource)
    ↓ attached to
Player / Container / Vendor
```

### InventoryItemPD (Base Item Class)

**Location**: `addons/cogito/InventoryPD/CustomResources/InventoryItemPD.gd`

```gdscript
class_name InventoryItemPD
extends Resource

@export var name : String = ""
@export_multiline var description : String = ""
@export var icon : Texture2D
@export var is_stackable : bool = false
@export var is_droppable : bool = true
@export var is_unique : bool = false  # Only one allowed in world
@export_range(1, 99) var stack_size : int
@export var drop_scene : String  # Path to scene when dropped

# Quickslot binding
@export var can_auto_slot: bool = false
@export var slot_number: int = -1

# For wielded items
var player_interaction_component
var is_being_wielded : bool
var wielded_item

func use(target) -> bool:
    # Override in subclasses
    return false
```

---

### Item Type Hierarchy

#### ConsumableItemPD
```gdscript
extends InventoryItemPD
class_name ConsumableItemPD

@export var attribute_name : String  # "health", "stamina", etc.
@export var attribute_change_amount : float
@export var value_to_change: ValueType  # CURRENT or MAX

enum ValueType {CURRENT, MAX}

func use(target) -> bool:
    # Apply effects to player attributes
    target.increase_attribute(attribute_name, attribute_change_amount, value_to_change)
    return true
```

**Examples**:
- Health potion (increases health.current)
- Stamina food (increases stamina.current)  
- Heart container (increases health.max permanently)

---

#### WieldableItemPD
```gdscript
extends InventoryItemPD
class_name WieldableItemPD

@export var wieldable_scene : PackedScene  # The actual 3D weapon/tool
@export var wieldable_data_icon : Texture2D  # HUD icon
@export var no_reload : bool = false
@export var charge_max : float  # Ammo capacity
@export var charge_current : float  # Current ammo
@export var ammo_item_name : String  # What ammo to use
@export var wieldable_range : float
@export var wieldable_damage : float

func use(target) -> bool:
    # Equip the wieldable
    if target.player_interaction_component.is_carrying:
        return false
    take_out()  # or put_away()
    return true

func build_wieldable_scene():
    var scene = wieldable_scene.instantiate()
    scene.item_reference = self
    return scene
```

**Important**: Item data is separate from the 3D scene!
- **WieldableItemPD** = data (damage, ammo count, etc.)
- **Wieldable Scene** = 3D model, animations, effects

---

#### AmmoItemPD
```gdscript
extends InventoryItemPD
class_name AmmoItemPD

@export var reload_amount : int = 1  # How much charge per ammo

func use(target) -> bool:
    # Ammo is used automatically when reloading
    return true
```

**Examples**:
- Bullets (reload_amount = 1)
- Batteries (reload_amount = 10)

---

#### KeyItemPD
```gdscript
extends InventoryItemPD
class_name KeyItemPD

@export var discard_after_use : bool = false

# Keys are checked by doors/switches, not "used" directly
```

---

#### CombinableItemPD
```gdscript
extends InventoryItemPD
class_name CombinableItemPD

@export var target_item_combine : String  # Name of item to combine with
@export var resulting_item : InventorySlotPD  # What you get

# Example: Saw + Log = 5x Wooden Planks
```

---

#### CurrencyItemPD
```gdscript
extends InventoryItemPD
class_name CurrencyItemPD

@export var currency_name : String  # "credits", "gold", etc.
@export var currency_change_amount : float
@export var add_on_pickup : bool  # Auto-consume when picked up

func use(target) -> bool:
    target.increase_currency(currency_name, currency_change_amount)
    return true
```

---

### InventorySlotPD

```gdscript
class_name InventorySlotPD
extends Resource

@export var inventory_item : InventoryItemPD
@export var quantity : int = 1

# Grid inventory properties
var item_rotation : int
var origin_index : int  # Slot position

func can_merge_with(other_slot_data: InventorySlotPD) -> bool:
    return inventory_item == other_slot_data.inventory_item \
        and inventory_item.is_stackable \
        and quantity < inventory_item.stack_size
```

**Purpose**: Container for items with quantity/position data

---

### CogitoInventory

```gdscript
class_name CogitoInventory
extends Resource

signal inventory_updated(inventory_data: CogitoInventory)

@export var inventory_size : Vector2i = Vector2i(6,4)  # Grid size
@export var inventory_slots : Array[InventorySlotPD]

func pick_up_slot_data(slot_data: InventorySlotPD) -> bool:
    # Try to stack with existing
    for slot in inventory_slots:
        if slot and slot.can_merge_with(slot_data):
            slot.quantity += slot_data.quantity
            inventory_updated.emit(self)
            return true
    
    # Find empty slot
    for i in range(inventory_slots.size()):
        if !inventory_slots[i]:
            inventory_slots[i] = slot_data
            inventory_updated.emit(self)
            return true
    
    return false  # Inventory full
```

---

## Player Attribute System

### CogitoAttribute (Base Class)

**Location**: `addons/cogito/Components/Attributes/cogito_attribute.gd`

```gdscript
class_name CogitoAttribute
extends Node

signal attribute_changed(attribute_name: String, value_current: float, value_max: float, has_increased: bool)
signal attribute_reached_zero(attribute_name: String, value_current: float, value_max: float)

@export var attribute_name : String  # "health", "stamina", etc.
@export var attribute_display_name : String  # "Health Points"
@export var attribute_color : Color
@export var attribute_icon : Texture2D
@export var value_max : float
@export var value_start : float
@export var is_locked : bool = false  # Unchangeable
@export var dont_save_current_value : bool = false

var value_current : float:
    set(value):
        var prev_value = value_current
        value_current = clamp(value, 0, value_max)
        
        if prev_value < value_current:
            attribute_changed.emit(attribute_name, value_current, value_max, true)
        elif prev_value > value_current:
            attribute_changed.emit(attribute_name, value_current, value_max, false)
        
        if value_current <= 0:
            attribute_reached_zero.emit(attribute_name, value_current, value_max)

func add(amount):
    if is_locked: return
    value_current += amount

func subtract(amount):
    if is_locked: return
    value_current -= amount
```

**Key Features**:
- Signal-based (UI updates automatically)
- Clamped between 0 and max
- Can be locked (unchangeable)
- Zero detection (death, etc.)

---

### Specialized Attributes

#### CogitoHealthAttribute
```gdscript
extends CogitoAttribute
class_name CogitoHealthAttribute

signal damage_taken()
signal death()

@export var sound_on_hit : AudioStream
@export var sound_on_death : AudioStream
@export var spawn_on_death : Array[PackedScene]  # Loot, ragdoll, etc.

func _ready():
    attribute_reached_zero.connect(on_death)

func on_death(_attribute_name: String, _value_current: float, _value_max: float):
    death.emit()
    # Play sound, spawn objects, etc.
```

---

#### CogitoStaminaAttribute
```gdscript
extends CogitoAttribute
class_name CogitoStaminaAttribute

@export var stamina_regen_speed : float = 1
@export var run_exhaustion_speed : float = 1
@export var jump_exhaustion : float = 1
@export var regenerate_after : float = 2  # Delay before regen
@export var auto_regenerate : bool = true

var is_regenerating : bool = false

func _process(delta):
    if is_regenerating:
        add(stamina_regen_speed * delta)
    
    if player.is_sprinting:
        subtract(run_exhaustion_speed * delta)
        is_regenerating = false
```

**Features**:
- Auto-regeneration with delay
- Slope-based exhaustion (uphill = more stamina drain)
- Jump cost

---

### Player Attribute Usage

**In CogitoPlayer.gd**:
```gdscript
var player_attributes : Dictionary  # ["health": CogitoHealthAttribute, ...]

func _ready():
    # Auto-discover all attribute components
    for attribute in find_children("", "CogitoAttribute", false):
        player_attributes[attribute.attribute_name] = attribute

func increase_attribute(attribute_name: String, value: float, value_type) -> bool:
    var attribute = player_attributes.get(attribute_name)
    if not attribute:
        return false
    
    if value_type == ConsumableItemPD.ValueType.CURRENT:
        if attribute.value_current == attribute.value_max:
            return false
        attribute.add(value)
        return true
    elif value_type == ConsumableItemPD.ValueType.MAX:
        attribute.value_max += value
        attribute.add(value)  # Also increase current
        return true
    
    return false

func decrease_attribute(attribute_name: String, value: float):
    var attribute = player_attributes.get(attribute_name)
    if not attribute: return
    attribute.subtract(value)
```

---

## Implementation Patterns

### Pattern 1: Raycast Interaction Detection

**PlayerInteractionComponent.gd**:
```gdscript
class_name PlayerInteractionComponent
extends Node3D

signal interactive_object_detected(interaction_nodes: Array[Node])
signal nothing_detected()

@export var interaction_raycast: InteractionRayCast

var interactable:
    set = _set_interactable

func _ready():
    interaction_raycast.interactable_seen.connect(_set_interactable)
    interaction_raycast.interactable_unseen.connect(_on_interactable_unseen)

func _set_interactable(value):
    interactable = value
    if interactable != null:
        interactive_object_detected.emit(interactable.interaction_nodes)
    else:
        nothing_detected.emit()
```

**InteractionRayCast.gd**:
```gdscript
class_name InteractionRayCast
extends RayCast3D

signal interactable_seen(interactable)
signal interactable_unseen()

var _interactable = null

func _process(_delta):
    _update_interactable()

func _update_interactable():
    var collider = get_collider()
    
    # Only care about objects in "interactable" group
    if collider != null and not collider.is_in_group("interactable"):
        collider = null
    
    if collider == _interactable:
        return
    
    _interactable = collider
    
    if _interactable == null:
        interactable_unseen.emit()
    else:
        interactable_seen.emit(_interactable)
```

**Key Insight**: 
- Raycast emits signals, doesn't directly interact
- Player component coordinates everything
- Objects must be in "interactable" group

---

### Pattern 2: Signal-Based UI Updates

**HUD subscribes to player signals**:
```gdscript
func _ready():
    player.player_interaction_component.interaction_prompt.connect(display_interaction_prompt)
    player.player_interaction_component.hint_prompt.connect(display_hint_prompt)
    player.player_interaction_component.interactive_object_detected.connect(build_interaction_prompts)
    player.player_interaction_component.nothing_detected.connect(clear_all_prompts)
```

**Player sends updates**:
```gdscript
func send_hint(hint_icon: Texture2D, hint_text: String):
    hint_prompt.emit(hint_icon, hint_text)

func display_interaction_prompt(text: String):
    interaction_prompt.emit(text)
```

**Benefits**:
- No polling/checking every frame
- Clean separation of concerns
- Easy to add new UI elements

---

### Pattern 3: Component Discovery

**In parent object**:
```gdscript
var interaction_nodes : Array[Node]

func _ready():
    find_interaction_nodes()

func find_interaction_nodes():
    interaction_nodes = find_children("", "InteractionComponent", true)
```

**Player iterates components**:
```gdscript
func _handle_interaction(action: String):
    if interactable:
        for node: InteractionComponent in interactable.interaction_nodes:
            if node.input_map_action == action and not node.is_disabled:
                node.interact(self)
                break
```

**Benefits**:
- Multiple interactions per object
- Easy to add/remove components
- No hard-coding references

---

### Pattern 4: State Management via Signals

**Object emits state changes**:
```gdscript
signal object_state_updated(interaction_text: String)
signal switched(is_on: bool)

func switch_on():
    is_on = true
    interaction_text = interaction_text_when_on
    object_state_updated.emit(interaction_text)
    switched.emit(is_on)
```

**Components listen and update**:
```gdscript
func _ready():
    if parent_node.has_signal("object_state_updated"):
        parent_node.object_state_updated.connect(_on_object_state_change)

func _on_object_state_change(_interaction_text: String):
    interaction_text = _interaction_text
```

**Benefits**:
- Components react to parent changes
- Parent doesn't need to know about components
- Easy to add listeners

---

### Pattern 5: Resource-Based Data

**Why Resources?**
```gdscript
# Can be created in editor as .tres files
# Can be saved/loaded easily
# Shared between instances
# Type-safe

@export var slot_data : InventorySlotPD  # Drag-and-drop in editor
@export var health_potion : ConsumableItemPD  # Reusable item definition
```

**Inventory as Resource**:
```gdscript
@export var inventory_data : CogitoInventory

# Can be:
# - Attached to player (main inventory)
# - Attached to container (chest inventory)
# - Saved to disk
# - Copied/duplicated
```

---

### Pattern 6: Object Spawning

**Common pattern for drops/spawns**:
```gdscript
func spawn_object():
    var spawned_object = object_to_spawn.instantiate()
    spawned_object.position = spawn_point.global_position
    get_tree().current_scene.add_child(spawned_object)
```

**For dropped items**:
```gdscript
func drop_item(slot_data: InventorySlotPD):
    # Load the drop scene from item data
    var item_to_spawn = load(slot_data.inventory_item.drop_scene)
    var spawned_item = item_to_spawn.instantiate()
    
    # Position near player
    spawned_item.position = player.global_position + drop_offset
    
    # Add to world
    get_tree().current_scene.add_child(spawned_item)
    
    # Optional: Apply physics impulse
    spawned_item.apply_central_impulse(throw_vector)
```

---

### Pattern 7: Persistence/Save System

**Objects implement save()**:
```gdscript
func save():
    var node_data = {
        "filename": get_scene_file_path(),
        "parent": get_parent().get_path(),
        "pos_x": position.x,
        "pos_y": position.y,
        "pos_z": position.z,
        "rot_x": rotation.x,
        "rot_y": rotation.y,
        "rot_z": rotation.z,
        # Object-specific data
        "is_on": is_on,
        "is_locked": is_locked,
    }
    return node_data
```

**Scene manager loads**:
```gdscript
func load_scene_state():
    for node_data in saved_nodes:
        var new_object = load(node_data["filename"]).instantiate()
        get_node(node_data["parent"]).add_child(new_object)
        new_object.position = Vector3(node_data["pos_x"], node_data["pos_y"], node_data["pos_z"])
        new_object.rotation = Vector3(node_data["rot_x"], node_data["rot_y"], node_data["rot_z"])
        # ... restore other properties
```

---

## Key Takeaways for Your Project

### 1. Start Simple, Build Up

**Minimum Viable Interaction System**:
```gdscript
# 1. Base interaction component
class_name InteractionComponent
extends Node3D
signal was_interacted_with()
@export var interaction_text: String
func interact(player): pass

# 2. Interactable object
class_name InteractableObject
extends Node3D
var interaction_components: Array[Node]
func _ready():
    add_to_group("interactable")
    interaction_components = find_children("", "InteractionComponent", true)

# 3. Player raycast detector
var raycast: RayCast3D
func _process(_delta):
    if raycast.is_colliding():
        var hit = raycast.get_collider()
        if hit.is_in_group("interactable"):
            current_interactable = hit

# 4. Input handling
func _input(event):
    if event.is_action_pressed("interact") and current_interactable:
        for component in current_interactable.interaction_components:
            component.interact(self)
```

Then expand from there!

---

### 2. Recommended Implementation Order

1. **Week 1**: Basic raycast detection + groups
   - Raycast to detect objects
   - "interactable" group
   - Simple highlight/outline

2. **Week 2**: Base interaction component
   - InteractionComponent base class
   - BasicInteraction (simple toggle)
   - Signal-based UI prompts

3. **Week 3**: Object types
   - Light switch (toggle state)
   - Door (open/close with animation)
   - Button (one-time use)

4. **Week 4**: Item system foundation
   - InventoryItemPD resource
   - InventorySlotPD resource
   - Basic inventory array

5. **Week 5**: Pickup system
   - PickupComponent
   - Simple inventory UI
   - Drop functionality

6. **Week 6**: Advanced components
   - CarryableComponent
   - HoldInteraction
   - Attribute checks

7. **Week 7**: Specialized items
   - ConsumableItemPD
   - WieldableItemPD
   - Item usage

8. **Week 8**: Polish
   - Sounds
   - Animations
   - Save system

---

### 3. What NOT to Copy Directly

**Avoid These Complexities Early**:
- Grid inventory (start with simple list)
- Wieldable system (complex, start with simple "use" items)
- Dual interactions (add after basic works)
- Systemic properties (fire/water reactions - very advanced)
- NPC interactions (focus on objects first)
- Quest system integration
- Localization

**Start here instead**:
- Single interaction per object
- Simple list inventory
- One input action ("interact")
- No animations (add later)
- No sounds (add later)

---

### 4. Critical Design Decisions

#### Decision 1: Destroy vs. Disable Pickups
**Cogito destroys** (`queue_free()`):
- ✅ Simpler logic
- ✅ No tracking needed
- ❌ Can't respawn
- ❌ Can't put back

**Alternative - Disable**:
```gdscript
func pick_up():
    get_parent().visible = false
    get_parent().set_physics_process(false)
    get_parent().collision_layer = 0
    # Add to "collected_items" list for save system
```

**Recommendation**: Start with destroy, add respawn later if needed

---

#### Decision 2: Single vs. Multiple Interactions
**Cogito allows multiple** (via component array):
- ✅ Flexible (carry + read + use)
- ✅ Easy to add behaviors
- ❌ More complex input handling
- ❌ Need UI for multiple prompts

**Alternative - Single**:
```gdscript
var interaction_component: InteractionComponent
# Only one component per object
```

**Recommendation**: Start single, add multiple when needed

---

#### Decision 3: Resource vs. Script Items
**Cogito uses Resources** (.tres files):
- ✅ Visual editor
- ✅ Easy to save/load
- ✅ Shareable between scenes
- ❌ Learning curve
- ❌ More files

**Alternative - Scripts**:
```gdscript
var item_data = {
    "name": "Health Potion",
    "icon": load("res://..."),
    "heal_amount": 50
}
```

**Recommendation**: Use Resources from start, worth learning

---

#### Decision 4: Signals vs. Direct Calls
**Cogito uses signals heavily**:
- ✅ Decoupled
- ✅ Easy to extend
- ✅ Multiple listeners
- ❌ Harder to debug
- ❌ Must connect properly

**Alternative - Direct calls**:
```gdscript
player.hud.show_prompt("Press E to open")
```

**Recommendation**: Use signals for UI, direct for core logic

---

### 5. Architecture Diagram for Your Project

```
┌─────────────────────────────────────────────────────────┐
│                    YOUR PROJECT                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  PHASE 1: DETECTION                                      │
│  ┌─────────────┐         ┌──────────────┐              │
│  │ Player      │────────>│ RayCast3D    │              │
│  │             │         │              │              │
│  └─────────────┘         └──────┬───────┘              │
│                                  │                       │
│                                  v                       │
│                          ┌──────────────┐               │
│                          │ Interactable │               │
│                          │ (in group)   │               │
│                          └──────┬───────┘               │
│                                  │                       │
│  PHASE 2: INTERACTION                                    │
│                                  v                       │
│                    ┌─────────────────────┐              │
│                    │ InteractionComponent│              │
│                    │ .interact(player)   │              │
│                    └─────────┬───────────┘              │
│                              │                           │
│                              v                           │
│  PHASE 3: RESULT                                         │
│                    ┌────────┴──────────┐                │
│                    │                   │                 │
│              ┌─────v─────┐      ┌─────v─────┐          │
│              │ Toggle    │      │ Add Item  │          │
│              │ State     │      │ to Inv.   │          │
│              └───────────┘      └───────────┘          │
│                    │                   │                 │
│                    v                   v                 │
│              ┌─────────────────────────────┐            │
│              │      Emit Signals           │            │
│              │  (UI updates, sounds, etc)  │            │
│              └─────────────────────────────┘            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

### 6. Starter Code Templates

#### Template: Simple Interactable
```gdscript
# simple_interactable.gd
extends Node3D

@export var interaction_text: String = "Interact"
@export var toggle_on_interact: bool = true

var is_active: bool = false

func _ready():
    add_to_group("interactable")

func interact(player):
    if toggle_on_interact:
        is_active = !is_active
    
    # Do something based on state
    if is_active:
        print("Activated!")
    else:
        print("Deactivated!")
```

---

#### Template: Simple Pickup
```gdscript
# simple_pickup.gd
extends RigidBody3D

@export var item_name: String = "Item"
@export var quantity: int = 1

func _ready():
    add_to_group("interactable")

func interact(player):
    # Add to player inventory
    player.add_item(item_name, quantity)
    
    # Remove from world
    queue_free()
```

---

#### Template: Player Interaction
```gdscript
# player.gd
extends CharacterBody3D

@onready var raycast: RayCast3D = $Camera/RayCast3D
var current_interactable = null
var inventory: Array = []

func _process(_delta):
    # Update what we're looking at
    if raycast.is_colliding():
        var hit = raycast.get_collider()
        if hit and hit.is_in_group("interactable"):
            current_interactable = hit
        else:
            current_interactable = null
    else:
        current_interactable = null
    
    # Update UI
    update_interaction_prompt()

func _input(event):
    if event.is_action_pressed("interact") and current_interactable:
        current_interactable.interact(self)

func add_item(item_name: String, quantity: int):
    inventory.append({"name": item_name, "quantity": quantity})
    print("Added ", quantity, "x ", item_name)

func update_interaction_prompt():
    if current_interactable and current_interactable.has("interaction_text"):
        # Show UI prompt
        print("Press E: ", current_interactable.interaction_text)
    else:
        # Hide UI prompt
        pass
```

---

### 7. Common Pitfalls to Avoid

1. **Forgetting to add to "interactable" group**
   - Raycast won't detect it!

2. **Not checking for null/freed objects**
   - Objects get freed, check `is_instance_valid()`

3. **Circular dependencies**
   - Use signals to break dependencies

4. **Hardcoding player references**
   - Pass player as parameter, use signals, or use singletons

5. **Not handling edge cases**
   - What if inventory is full?
   - What if player is dead?
   - What if object is destroyed mid-interaction?

6. **Over-engineering too early**
   - Start simple, refactor later

7. **Not separating data from behavior**
   - Use Resources for data (items, stats)
   - Use Components for behavior (interactions)

---

### 8. Testing Checklist

**For Each Interaction Type**:
- [ ] Object appears in world
- [ ] Raycast detects it (outline/highlight)
- [ ] UI prompt shows correct text
- [ ] Pressing interact button works
- [ ] Object state updates correctly
- [ ] UI updates after interaction
- [ ] Sounds play (if applicable)
- [ ] Animations play (if applicable)
- [ ] Can interact repeatedly (if intended)
- [ ] Can't interact when shouldn't (disabled, too far, etc.)
- [ ] Works with multiple objects of same type
- [ ] Saves/loads correctly (if applicable)

---

### 9. Performance Considerations

**From Cogito**:
1. **Raycast only checks on valid colliders**
   - Collision layers/masks
   - "interactable" group check

2. **Components found once, cached**
   - `find_children()` in `_ready()`, not every frame

3. **Signals prevent polling**
   - UI only updates when needed

4. **Resources are memory-efficient**
   - Shared between instances
   - Not duplicated unless needed

**Apply to your project**:
- Use collision layers
- Cache references
- Use signals for updates
- Profile before optimizing

---

### 10. Expansion Path

**Once basics work, add**:

1. **Audio**
   - Interaction sounds
   - Pickup sounds
   - Ambient sounds

2. **Animation**
   - Doors opening
   - Drawers sliding
   - Items rotating

3. **Visual Feedback**
   - Outline shader
   - Particles on pickup
   - UI transitions

4. **Advanced Interactions**
   - Hold to interact
   - Multiple actions per object
   - Context-sensitive prompts

5. **Item System**
   - Consumables
   - Equipables
   - Combinables

6. **Save System**
   - Object states
   - Inventory
   - World state

7. **Optimization**
   - Object pooling
   - LOD for interactions
   - Distance-based checks

---

## Additional Resources

### Cogito Documentation
- Official docs: Check `docs/` folder
- Manual: `docs/manual.rst`
- FAQ: `docs/faq.rst`

### Key Files to Study
```
Priority 1 (Core Understanding):
- Components/Interactions/InteractionComponent.gd
- CogitoObjects/cogito_object.gd
- Components/PlayerInteractionComponent.gd
- Scripts/interaction_raycast.gd

Priority 2 (Item System):
- InventoryPD/CustomResources/InventoryItemPD.gd
- InventoryPD/CustomResources/InventorySlotPD.gd
- Components/Interactions/PickupComponent.gd

Priority 3 (Examples):
- CogitoObjects/cogito_switch.gd
- CogitoObjects/cogito_door.gd
- CogitoObjects/cogito_container.gd

Priority 4 (Advanced):
- Components/Attributes/cogito_attribute.gd
- Components/Interactions/CarryableComponent.gd
- Components/Interactions/DualInteraction.gd
```

---

## Final Recommendations

### What to Use in Your Project

✅ **Definitely Use**:
1. Component-based interaction system
2. Groups for detecting interactables
3. Signal-based UI updates
4. Resource-based items
5. Raycast detection

🤔 **Consider**:
1. Attribute system (if you have health/stamina)
2. Multiple components per object
3. Hold interactions
4. Grid inventory (complex but powerful)

❌ **Skip for Now**:
1. Systemic properties (fire/water)
2. Wieldable system (if you don't need it)
3. Quest system integration
4. Localization
5. Advanced animations

---

### Simplified Architecture for Beginners

```gdscript
# 1. Base interaction (extend this for all interactions)
class_name Interaction extends Node3D
signal activated()
@export var prompt_text: String = "Interact"
func activate(player): activated.emit()

# 2. Interactable object (attach to anything interactive)
class_name Interactable extends Node3D
var interaction: Interaction
func _ready():
    add_to_group("interactable")
    interaction = get_child(0)  # Assume first child is interaction
func interact(player): 
    if interaction: interaction.activate(player)

# 3. Player (simple raycast + input)
var raycast: RayCast3D
var target: Interactable
func _process(_delta):
    target = get_raycast_target()
func _input(event):
    if event.is_action_pressed("interact") and target:
        target.interact(self)
```

**That's it!** Everything else is just expanding this pattern.

---

## Conclusion

The Cogito system is powerful because it's:
- **Modular**: Add/remove components without breaking things
- **Extensible**: Easy to create new interaction types
- **Data-driven**: Items and inventories are Resources
- **Signal-based**: Loose coupling, easy to extend
- **Well-structured**: Clear separation of concerns

For your project, start with the simplified version above, then gradually add features from Cogito as you need them. Don't try to implement everything at once!

**Remember**: 
- Start simple
- Get one thing working before moving to the next
- Use signals for communication
- Cache references
- Test thoroughly

Good luck with your project! 🎮
