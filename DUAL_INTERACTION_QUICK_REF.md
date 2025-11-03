# Dual Interaction System - Quick Reference

## Input Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    PLAYER INPUT                              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────┴─────────────────┐
        │                                   │
        ▼                                   ▼
  [LEFT CLICK]                          [E KEY]
        │                                   │
        ▼                                   ▼
┌───────────────┐                   ┌───────────────┐
│ Not Carrying  │                   │ Not Carrying  │
│ ─────────────│                   │ ─────────────│
│ Look for      │                   │ Call          │
│ CarryableComp │                   │ interact()    │
│ ↓             │                   │ on current    │
│ Call pickup() │                   │ interactable  │
└───────────────┘                   └───────────────┘
        │                                   │
┌───────────────┐                   ┌───────────────┐
│ Carrying      │                   │ Carrying      │
│ ─────────────│                   │ ─────────────│
│ Call throw()  │                   │ Call drop()   │
└───────────────┘                   └───────────────┘
```

## Component Type Decision Tree

```
Do you want the object to be PICKABLE?
│
├─ NO ──────────────────────┐
│                           │
│   Is it interactive?      │
│   ├─ YES → InteractionComponent
│   └─ NO  → Just Node3D/StaticBody3D
│
└─ YES ─────────────────────┐
                            │
    Do you want E-key interaction too?
    │
    ├─ NO  → CarryableComponent
    │         (Only pickup/throw/drop)
    │
    └─ YES → CarryableInteractableComponent
              │
              └─ Can interact while carrying?
                 ├─ YES → can_interact_while_carried = true
                 └─ NO  → can_interact_while_carried = false
```

## Component Comparison

```
┌──────────────────────────────────────────────────────────────┐
│                    InteractionComponent                       │
├──────────────────────────────────────────────────────────────┤
│ • E-key only                                                  │
│ • No physics required                                         │
│ • Examples: Light switches, doors, buttons                    │
└──────────────────────────────────────────────────────────────┘
                            │
                            │ extends
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                    CarryableComponent                         │
├──────────────────────────────────────────────────────────────┤
│ • Left-click to pickup                                        │
│ • Left-click to throw (while carrying)                        │
│ • E-key to drop (while carrying)                              │
│ • Requires RigidBody3D parent                                 │
│ • Examples: Boxes, props, generic objects                     │
└──────────────────────────────────────────────────────────────┘
                            │
                            │ extends
                            ▼
┌──────────────────────────────────────────────────────────────┐
│              CarryableInteractableComponent                   │
├──────────────────────────────────────────────────────────────┤
│ • Left-click to pickup/throw (same as above)                  │
│ • E-key to interact (separate from drop)                      │
│ • Can optionally interact while carrying                      │
│ • Requires RigidBody3D parent                                 │
│ • Examples: Radios, tools, interactive devices                │
└──────────────────────────────────────────────────────────────┘
```

## Scene Structure Examples

### Simple Switch (E-key only)
```
LightSwitch (Node3D)
├── MeshInstance3D
├── StaticBody3D
│   └── CollisionShape3D
└── LightSwitchInteraction (extends InteractionComponent)
```

### Simple Box (Pickup only)
```
WoodenBox (RigidBody3D)
├── MeshInstance3D
├── CollisionShape3D
└── CarryableComponent
```

### Interactive Radio (Pickup + E-key)
```
BoomBox (RigidBody3D)
├── MeshInstance3D
├── CollisionShape3D
├── AudioStreamPlayer3D
└── RadioInteraction (extends CarryableInteractableComponent)
```

## Code Templates

### Template 1: Simple Carryable
```gdscript
# Just attach CarryableComponent - no custom code needed!
# Object can be picked up and thrown
```

### Template 2: Interactive Carryable (Can't interact while carrying)
```gdscript
extends CarryableInteractableComponent

func _ready() -> void:
    can_interact_while_carried = false  # Must drop first
    e_key_interaction_text = "Open"
    super._ready()

func _on_e_key_interacted(player: PlayerInteractionComponent) -> void:
    # Do something when E is pressed (and not carrying)
    print("Opened!")
```

### Template 3: Interactive Carryable (Can interact while carrying)
```gdscript
extends CarryableInteractableComponent

var is_on: bool = false

func _ready() -> void:
    can_interact_while_carried = true  # Can toggle while carrying
    e_key_interaction_text = "Toggle"
    super._ready()

func _on_e_key_interacted(player: PlayerInteractionComponent) -> void:
    is_on = !is_on
    # Do something when E is pressed (anytime)
    print("Toggled: ", is_on)
```

## Interaction Prompts

The system automatically generates context-aware prompts:

```
┌─────────────────────────────────────────────────────────┐
│ Looking at Simple Carryable:                            │
│ "[Click] Pick Up"                                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Looking at Interactive Carryable:                       │
│ "[Click] Pick Up | [E] Toggle Power"                    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ While Carrying:                                         │
│ (Prompts hidden - HUD shows carry controls)            │
└─────────────────────────────────────────────────────────┘
```

## Common Use Cases

| Object Type | Component | Example |
|-------------|-----------|---------|
| Static switch/button | `InteractionComponent` | Light switch, door button |
| Simple prop | `CarryableComponent` | Box, ball, cup |
| Tool/device (simple) | `CarryableComponent` | Wrench, key |
| Tool/device (complex) | `CarryableInteractableComponent` | Radio, flashlight, phone |
| Container (locked) | `CarryableInteractableComponent` | Lockbox, safe |
| Powered device | `CarryableInteractableComponent` | Fan, lamp, speaker |

