# Dual Interaction System Guide

## Overview

The dual interaction system allows objects to have **two separate interaction methods**:
- **LEFT CLICK** - Pick up / Throw
- **E KEY** - Interact (toggle, activate, use, etc.)

This is implemented through the `CarryableInteractableComponent` which extends `CarryableComponent`.

---

## Component Hierarchy

```
InteractionComponent (base)
└── CarryableComponent (adds pickup/carry/throw)
    └── CarryableInteractableComponent (adds E-key interaction)
        └── Your Custom Script (RadioInteraction, etc.)
```

---

## How It Works

### Input Mapping

| Input | Not Carrying | Carrying |
|-------|-------------|----------|
| **LEFT CLICK** | Pick up object | Throw object |
| **E KEY** | Interact with object | Drop object (or interact if `can_interact_while_carried = true`) |

### Component Types

1. **InteractionComponent** - E-key only (light switches, doors, buttons)
2. **CarryableComponent** - Click to pickup, E to drop while carrying
3. **CarryableInteractableComponent** - Click to pickup, E to interact (dual system)

---

## Setup Guide

### Basic Setup (Object that can be picked up AND interacted with)

1. **Create your object** (RigidBody3D)
   ```
   BoomBox (RigidBody3D)
   ├── MeshInstance3D
   ├── CollisionShape3D
   ├── AudioStreamPlayer3D (optional)
   └── RadioInteraction (script)
   ```

2. **Add CarryableInteractableComponent-based script**
   ```gdscript
   extends CarryableInteractableComponent
   class_name RadioInteraction
   
   func _ready() -> void:
       can_interact_while_carried = true  # Allow E-key while carrying
       e_key_interaction_text = "Toggle Power"
       super._ready()
   
   func _on_e_key_interacted(player: PlayerInteractionComponent) -> void:
       # Your E-key interaction logic here
       print("Radio toggled!")
   ```

3. **Configure in Inspector**
   - Set physics properties (mass, friction, etc.)
   - Configure carry settings (throw power, carry distance)
   - Set interaction text and sounds

---

## Examples

### Example 1: Radio (Can Interact While Carrying)

```gdscript
extends CarryableInteractableComponent
class_name RadioInteraction

@export var audio_player: AudioStreamPlayer3D
var is_playing: bool = false

func _ready() -> void:
    can_interact_while_carried = true  # ✅ Can toggle while carrying
    e_key_interaction_text = "Toggle Power"
    super._ready()

func _on_e_key_interacted(_player: PlayerInteractionComponent) -> void:
    is_playing = not is_playing
    if is_playing:
        audio_player.play()
    else:
        audio_player.stop()
    
    e_key_interaction_text = "Turn " + ("Off" if is_playing else "On")
```

**Usage:**
- Click to pick up radio
- Press E while carrying to turn it on/off
- Click again to throw radio

---

### Example 2: Box with Lock (Must Place to Interact)

```gdscript
extends CarryableInteractableComponent
class_name LockableBoxInteraction

@export var animation_player: AnimationPlayer
var is_locked: bool = true

func _ready() -> void:
    can_interact_while_carried = false  # ❌ Cannot unlock while carrying
    e_key_interaction_text = "Unlock"
    super._ready()

func _on_e_key_interacted(_player: PlayerInteractionComponent) -> void:
    if is_locked:
        is_locked = false
        animation_player.play("unlock")
        e_key_interaction_text = "Open"
    else:
        animation_player.play("open")
```

**Usage:**
- Click to pick up box
- Press E to drop box
- Press E again (while not carrying) to unlock/open

---

### Example 3: Simple Carryable (No E-key Interaction)

For objects that only need to be carried (no E-key interaction), use `CarryableComponent`:

```gdscript
extends CarryableComponent
# That's it! No E-key interaction
```

**Usage:**
- Click to pick up
- Click to throw
- E to drop (while carrying)

---

## Converting Existing Objects

### From InteractionComponent to Dual System

**Before:**
```gdscript
extends InteractionComponent
class_name BoomboxInteraction

func _on_interacted(player: PlayerInteractionComponent) -> void:
    # Toggle music
```

**After:**
```gdscript
extends CarryableInteractableComponent
class_name BoomboxInteraction

func _ready() -> void:
    can_interact_while_carried = true
    e_key_interaction_text = "Toggle Music"
    super._ready()

func _on_e_key_interacted(player: PlayerInteractionComponent) -> void:
    # Toggle music (same logic)
```

**Changes:**
- Extend `CarryableInteractableComponent` instead of `InteractionComponent`
- Rename `_on_interacted()` to `_on_e_key_interacted()`
- Add `can_interact_while_carried` setting in `_ready()`
- Parent must be `RigidBody3D` (for physics)

---

## Configuration Options

### CarryableComponent Settings (Inherited)

```gdscript
@export var carry_distance_offset: float = 0.0  # Offset from carry position
@export var carry_smoothness: float = 10.0      # Movement smoothness
@export var drop_distance: float = 1.5          # Auto-drop distance
@export var lock_rotation_when_carried: bool = true  # Prevent tumbling
@export var throw_power: float = 15.0           # Throw force
@export var drop_power: float = 1.0             # Drop force
```

### CarryableInteractableComponent Settings (New)

```gdscript
@export var e_key_interaction_text: String = "Interact"  # E-key prompt text
@export var can_interact_while_carried: bool = false     # Allow E-key while carrying
@export var e_key_interaction_sound: AudioStream         # E-key sound
```

---

## Signals

```gdscript
# From CarryableComponent
signal being_carried_changed(is_being_carried: bool)
signal thrown(impulse: Vector3)

# From CarryableInteractableComponent
signal e_key_interacted(player_interaction_component: PlayerInteractionComponent)

# From InteractionComponent
signal interacted(player_interaction_component: PlayerInteractionComponent)
signal hover_started()
signal hover_ended()
signal state_changed(new_state: String)
```

---

## Best Practices

### When to Use Each Component

| Component | Use Case |
|-----------|----------|
| `InteractionComponent` | Static objects (switches, doors, buttons) |
| `CarryableComponent` | Physics objects that only need pickup (boxes, props) |
| `CarryableInteractableComponent` | Objects with both pickup AND interaction (radios, tools, devices) |

### Performance Tips

1. **Limit carryable objects** - Each uses physics simulation
2. **Use collision layers properly** - Set interactables to layer 4
3. **Disable unnecessary features** - If object doesn't tumble, use `lock_rotation_when_carried = true`

### Common Pitfalls

❌ **Don't:** Use `InteractionComponent` for physics objects you want to carry
✅ **Do:** Use `CarryableComponent` or `CarryableInteractableComponent`

❌ **Don't:** Call `interact()` directly - it's for E-key only
✅ **Do:** Call `pickup()` for left-click pickup

❌ **Don't:** Parent to Node3D if you want physics
✅ **Do:** Parent to RigidBody3D for carryable objects

---

## Troubleshooting

### Object doesn't pick up on left click
- ✅ Ensure parent is `RigidBody3D`
- ✅ Check object is in "interactable" group (auto-added)
- ✅ Verify collision layer is set correctly (layer 4)

### E-key doesn't work
- ✅ Make sure you're using `CarryableInteractableComponent`
- ✅ Implement `_on_e_key_interacted()` method
- ✅ Check `is_disabled` is false

### Object falls through floor when dropped
- ✅ Increase `drop_distance` to prevent wall clipping
- ✅ Check floor collision layer
- ✅ Ensure object has proper collision shape

---

## Migration Checklist

Converting existing objects to dual system:

- [ ] Change parent to `RigidBody3D` (if not already)
- [ ] Change script to extend `CarryableInteractableComponent`
- [ ] Rename `_on_interacted()` to `_on_e_key_interacted()`
- [ ] Set `can_interact_while_carried` in `_ready()`
- [ ] Set `e_key_interaction_text` for better prompts
- [ ] Test both left-click (pickup) and E-key (interact)
- [ ] Adjust physics properties (mass, friction)
- [ ] Configure carry settings (throw power, distance)

---

## Summary

The dual interaction system gives you powerful control over object behavior:

- **Simple objects** → Use `InteractionComponent` (E-key only)
- **Carryable objects** → Use `CarryableComponent` (click to pickup)
- **Interactive carryable objects** → Use `CarryableInteractableComponent` (both!)

This creates intuitive gameplay where:
- **Left click** = Physical interaction (pickup/throw)
- **E key** = Logical interaction (activate/toggle/use)

