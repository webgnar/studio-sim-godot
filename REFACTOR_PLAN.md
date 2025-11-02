# Studio Sim - Refactoring Plan
**Based on COGITO Interaction System Analysis**  
**Date:** November 1, 2025

---

## 🎯 Current State Analysis

### What We Currently Have:
- ✅ **Basic FPS controller** with movement, sprinting, head bob, FOV
- ✅ **Individual clickable scripts** for specific objects (Box, Artbox, Boombox, Light Switch)
- ✅ **Raycast-based interaction** (built into each clickable object)
- ✅ **Audio system** with 3D spatial sound
- ✅ **Animation integration** (box lids, artbox unfolding, etc.)

### What We're Missing (That COGITO Has):
- ❌ **Unified interaction system** (each object does its own raycasting)
- ❌ **Component-based architecture** (tightly coupled scripts)
- ❌ **Centralized player interaction component**
- ❌ **UI/HUD prompts** (no interaction hints)
- ❌ **Signal-based communication** (limited use of signals)
- ❌ **Inventory system** (no item pickup/storage)
- ❌ **Reusable interaction components**

---

## 🚀 Implementation Plan

### **Phase 1: Foundation (Highest Priority)** 🔴

#### ☐ Task 1.1: Centralized Player Interaction Component ⭐⭐⭐
**Time Estimate:** 2-3 hours  
**Priority:** CRITICAL  
**Why:** Currently, every clickable object has its own raycasting logic. This is inefficient and hard to maintain.

**Implementation Steps:**
1. Create `scripts/PlayerInteractionComponent.gd`
2. Add `InteractionRaycast` as child of Camera3D
3. Move raycast logic from individual objects to this component
4. Emit signals for interaction events
5. Update PlayerController to use this component

**Code Template:**
```gdscript
# PlayerInteractionComponent.gd
extends Node3D
class_name PlayerInteractionComponent

signal interactive_object_detected(interactable: Node3D)
signal nothing_detected()
signal interaction_prompt_changed(prompt_text: String)

@onready var raycast: RayCast3D = $Camera3D/InteractionRaycast
var current_interactable: Node3D = null

func _process(_delta):
    _update_interactable()

func _update_interactable():
    if raycast.is_colliding():
        var hit = raycast.get_collider()
        if hit and hit.is_in_group("interactable"):
            if hit != current_interactable:
                current_interactable = hit
                interactive_object_detected.emit(hit)
                _update_interaction_prompt()
        else:
            _clear_interactable()
    else:
        _clear_interactable()

func _clear_interactable():
    if current_interactable:
        current_interactable = null
        nothing_detected.emit()
        interaction_prompt_changed.emit("")

func _input(event):
    if event.is_action_pressed("interact") and current_interactable:
        _handle_interaction()

func _handle_interaction():
    if current_interactable and current_interactable.has_method("interact"):
        current_interactable.interact(self)

func _update_interaction_prompt():
    if current_interactable and current_interactable.has("interaction_text"):
        interaction_prompt_changed.emit(current_interactable.interaction_text)
```

**Success Criteria:**
- [ ] One raycast handles all interactions
- [ ] Player detects interactable objects via groups
- [ ] Signals emitted for UI updates
- [ ] Input handling centralized

---

#### ☐ Task 1.2: Base Interaction Component ⭐⭐⭐
**Time Estimate:** 1-2 hours  
**Priority:** CRITICAL  
**Why:** Eliminate ~200 lines of duplicate code per script

**Implementation Steps:**
1. Create `scripts/InteractionComponent.gd` base class
2. Define common properties (interaction_text, sounds, etc.)
3. Define virtual `interact()` method
4. Add auto-registration to "interactable" group
5. Move common audio/hover logic here

**Code Template:**
```gdscript
# InteractionComponent.gd (Base class)
class_name InteractionComponent
extends Node3D

signal interacted()
signal hover_started()
signal hover_ended()
signal state_changed(new_state: String)

@export_group("Interaction Settings")
@export var interaction_text: String = "Interact"
@export var interaction_distance: float = 5.0
@export var is_disabled: bool = false

@export_group("Audio")
@export var interaction_sound: AudioStream
@export var hover_sound: AudioStream

var parent_object: Node3D
var _audio_player: AudioStreamPlayer3D

func _ready():
    parent_object = get_parent()
    parent_object.add_to_group("interactable")
    _setup_audio()

func _setup_audio():
    if interaction_sound or hover_sound:
        _audio_player = AudioStreamPlayer3D.new()
        _audio_player.name = "InteractionAudio"
        add_child(_audio_player)

func _play_sound(sound: AudioStream):
    if sound and _audio_player:
        _audio_player.stream = sound
        _audio_player.play()

# Override this in subclasses
func interact(player_interaction_component: PlayerInteractionComponent):
    if is_disabled:
        return
    
    if interaction_sound:
        _play_sound(interaction_sound)
    
    interacted.emit()
```

**Success Criteria:**
- [ ] Base class created with common functionality
- [ ] Auto-adds parent to "interactable" group
- [ ] Audio setup handled in base class
- [ ] Virtual interact() method defined

---

#### ☐ Task 1.3: Refactor ClickableBox to Use Components
**Time Estimate:** 2-3 hours  
**Priority:** HIGH  
**Why:** Proof of concept for new system

**Implementation Steps:**
1. Create `BoxInteraction.gd` extending `InteractionComponent`
2. Move box-specific logic (lid animations, state machine)
3. Remove raycast/camera finding code
4. Keep only unique box behavior
5. Test thoroughly

**Code Template:**
```gdscript
# BoxInteraction.gd
extends InteractionComponent
class_name BoxInteraction

enum BoxState { CLOSED, OPENING_1, PAIR_1_OPEN, OPENING_2, OPEN, CLOSING_1, PAIR_2_CLOSED, CLOSING_2 }

@export var flap_1_open_sound: AudioStream
@export var flap_2_open_sound: AudioStream
@export var box_close_sound: AudioStream
@export var sequence_buffer: float = 0.3

var _current_state: BoxState = BoxState.CLOSED

func _ready():
    super._ready()
    interaction_text = "Open Box"

func interact(player_interaction_component: PlayerInteractionComponent):
    super.interact(player_interaction_component)
    _handle_box_interaction()

func _handle_box_interaction():
    match _current_state:
        BoxState.CLOSED:
            _open_lid_pair_1()
        BoxState.PAIR_1_OPEN:
            _open_lid_pair_2()
        # ... rest of state machine
```

**Success Criteria:**
- [ ] Box works with new component system
- [ ] No raycast code in box script
- [ ] No camera finding code
- [ ] Same functionality as before
- [ ] Cleaner, more maintainable code

---

#### ☐ Task 1.4: Basic HUD/UI System ⭐⭐
**Time Estimate:** 1-2 hours  
**Priority:** HIGH  
**Why:** Players need visual feedback for interactions

**Implementation Steps:**
1. Create `scenes/HUD.tscn` with CanvasLayer
2. Add Label for interaction prompt
3. Add crosshair (optional)
4. Create `scripts/HUD.gd`
5. Connect to PlayerInteractionComponent signals

**Code Template:**
```gdscript
# HUD.gd
extends CanvasLayer

@onready var interaction_label: Label = $InteractionPrompt
@onready var player: CharacterBody3D = get_parent()

func _ready():
    interaction_label.hide()
    
    if player.has_node("PlayerInteractionComponent"):
        var pic = player.get_node("PlayerInteractionComponent")
        pic.interaction_prompt_changed.connect(_on_prompt_changed)
        pic.interactive_object_detected.connect(_on_object_detected)
        pic.nothing_detected.connect(_on_nothing_detected)

func _on_prompt_changed(prompt: String):
    if prompt == "":
        interaction_label.hide()
    else:
        interaction_label.text = "Press E to " + prompt
        interaction_label.show()

func _on_object_detected(obj):
    # Optional: Add hover effects
    pass

func _on_nothing_detected():
    interaction_label.hide()
```

**HUD Scene Structure:**
```
CanvasLayer (HUD.gd)
├── CenterContainer
│   └── Label (InteractionPrompt)
│       - Text: "Press E to Interact"
│       - Align: Center
│       - Position: Top-center of screen
└── Control (Crosshair) [optional]
    └── TextureRect (crosshair.png)
```

**Success Criteria:**
- [ ] Prompt shows when looking at interactable
- [ ] Prompt hides when looking away
- [ ] Prompt text updates based on object
- [ ] Clean, readable UI

---

### **Phase 2: Enhancement (Medium Priority)** 🟡

#### ☐ Task 2.1: Refactor Remaining Clickable Objects
**Time Estimate:** 4-6 hours  
**Priority:** MEDIUM  
**Objects to Refactor:**
- [ ] ClickableArtbox → ArtboxInteraction
- [ ] ClickableBoombox → BoomboxInteraction
- [ ] ClickableLightSwitch → LightSwitchInteraction

**Implementation Steps (per object):**
1. Create new script extending InteractionComponent
2. Move unique behavior only
3. Remove duplicate code (camera, raycast, audio setup)
4. Test functionality
5. Delete old script once verified

**Success Criteria:**
- [ ] All objects use component system
- [ ] No duplicate code between objects
- [ ] All features working as before
- [ ] Codebase ~40% smaller

---

#### ☐ Task 2.2: AudioManager Singleton ⭐
**Time Estimate:** 1 hour  
**Priority:** MEDIUM  
**Why:** Centralize audio configuration and pooling

**Implementation Steps:**
1. Create `scripts/AudioManager.gd`
2. Add to AutoLoad in project settings
3. Create helper methods for 2D/3D audio
4. (Optional) Add audio pooling for performance

**Code Template:**
```gdscript
# AudioManager.gd
extends Node

func play_sound_3d(sound: AudioStream, position: Vector3, volume_db: float = 0.0, max_distance: float = 10.0):
    var player = AudioStreamPlayer3D.new()
    get_tree().root.add_child(player)
    player.global_position = position
    player.stream = sound
    player.volume_db = volume_db
    player.max_distance = max_distance
    player.play()
    player.finished.connect(func(): player.queue_free())
    return player

func play_sound_2d(sound: AudioStream, volume_db: float = 0.0):
    var player = AudioStreamPlayer.new()
    get_tree().root.add_child(player)
    player.stream = sound
    player.volume_db = volume_db
    player.play()
    player.finished.connect(func(): player.queue_free())
    return player
```

**Project Settings:**
```
Project → Project Settings → AutoLoad
Name: AudioManager
Path: res://scripts/AudioManager.gd
```

**Usage Example:**
```gdscript
# Instead of:
_audio_player.stream = sound
_audio_player.play()

# Use:
AudioManager.play_sound_3d(sound, global_position)
```

**Success Criteria:**
- [ ] AudioManager singleton created
- [ ] Added to AutoLoad
- [ ] Helper methods working
- [ ] Used in at least one object

---

#### ☐ Task 2.3: Signal-Based State Management
**Time Estimate:** 2 hours  
**Priority:** LOW-MEDIUM  
**Why:** Better decoupling and reactivity

**Implementation Steps:**
1. Add state signals to all interaction components
2. Update HUD to listen to state changes
3. (Optional) Add debug UI showing object states
4. Document signal patterns

**Example:**
```gdscript
# In BoxInteraction.gd
signal box_opened()
signal box_closed()
signal box_state_changed(new_state: BoxState)

# In HUD.gd or DebugUI.gd
func _on_object_detected(obj):
    if obj.has_signal("box_state_changed"):
        obj.box_state_changed.connect(_on_box_state_changed)

func _on_box_state_changed(new_state):
    print("Box is now: ", BoxInteraction.BoxState.keys()[new_state])
```

**Success Criteria:**
- [ ] All objects emit state change signals
- [ ] UI can react to state changes
- [ ] Better debugging capability

---

### **Phase 3: Polish & Optimization (Lower Priority)** 🟢

#### ☐ Task 3.1: Interaction Distance Visualization (Debug)
**Time Estimate:** 30 minutes  
**Priority:** LOW  
**Why:** Helps with debugging interaction range

**Implementation:**
- Add debug draw for raycast
- Show interaction radius
- Toggle with F3 or similar

---

#### ☐ Task 3.2: Performance Profiling
**Time Estimate:** 1 hour  
**Priority:** LOW  
**Why:** Verify refactor improved performance

**Metrics to Check:**
- [ ] Frame time before/after
- [ ] Number of raycasts per frame
- [ ] Memory usage
- [ ] Script compile time

---

#### ☐ Task 3.3: Code Documentation
**Time Estimate:** 2 hours  
**Priority:** LOW  
**Why:** Maintainability and onboarding

**Tasks:**
- [ ] Add doc comments to all public methods
- [ ] Create README.md for scripts folder
- [ ] Document architecture decisions
- [ ] Add usage examples

---

## ❌ What NOT to Implement (Yet)

### Don't Add These Until Core is Stable:
- ❌ **Full Inventory System** - No evidence of item management needs yet
- ❌ **Wieldable Items/Weapons** - Not relevant to studio sim
- ❌ **Player Attribute System** (Health/Stamina) - Not needed
- ❌ **Save/Load System** - Add after core functionality works
- ❌ **Container/Chest System** - COGITO-specific, not needed
- ❌ **Consumable Items** - Not relevant
- ❌ **Quest System** - Way too complex for now
- ❌ **Localization** - Premature optimization

---

## 🎯 Success Metrics

### Code Quality:
- [ ] Reduce total lines of code by ~30-40%
- [ ] Eliminate all duplicate raycast code
- [ ] Single source of truth for interaction logic
- [ ] No code duplication between clickable objects

### Performance:
- [ ] One raycast per frame (down from 4+)
- [ ] Stable 60 FPS with 10+ interactable objects
- [ ] No memory leaks from audio players

### Maintainability:
- [ ] New interaction type takes <30 minutes to add
- [ ] All objects follow same pattern
- [ ] Clear separation of concerns
- [ ] Well-documented code

### User Experience:
- [ ] Visual feedback for all interactions
- [ ] Clear interaction prompts
- [ ] Responsive interactions (<100ms)
- [ ] No bugs introduced during refactor

---

## 📚 Key Learnings from COGITO

1. **One raycast per player, not per object** - Massive performance win
2. **Composition over inheritance** - Components are more flexible
3. **Signals everywhere** - Decouple systems for better maintainability
4. **Groups are powerful** - Use for organization and querying
5. **Start simple, iterate** - Don't over-engineer early
6. **Separation of concerns** - Data (Resources) vs Behavior (Components)

---

## 🔧 Quick Wins (Can Do Right Now)

### Immediate Actions (< 30 min each):
1. **Add "interactable" group to all objects**
   ```gdscript
   func _ready():
       add_to_group("interactable")
   ```

2. **Extract common _find_player_camera() to utility script**
   ```gdscript
   # Utils.gd (AutoLoad)
   static func find_player_camera() -> Camera3D:
       var players = get_tree().get_nodes_in_group("player")
       if players.size() > 0:
           return _find_camera_in_node(players[0])
       return get_viewport().get_camera_3d()
   ```

3. **Add input map for "interact" action**
   - Project Settings → Input Map
   - Add "interact" action
   - Bind to E key and Left Click

4. **Create scripts folder structure**
   ```
   scripts/
   ├── components/
   │   ├── InteractionComponent.gd
   │   ├── BoxInteraction.gd
   │   ├── ArtboxInteraction.gd
   │   ├── BoomboxInteraction.gd
   │   └── LightSwitchInteraction.gd
   ├── player/
   │   ├── PlayerController.gd
   │   ├── PlayerInteractionComponent.gd
   │   └── PlayerAnimation.gd
   ├── ui/
   │   └── HUD.gd
   └── singletons/
       └── AudioManager.gd
   ```

---

## 📅 Time Estimates

### Total Time to Complete:
- **Phase 1 (Foundation):** 8-10 hours
- **Phase 2 (Enhancement):** 7-9 hours
- **Phase 3 (Polish):** 3-4 hours
- **TOTAL:** ~18-23 hours

### Suggested Schedule (Part-Time):
- **Week 1:** Tasks 1.1, 1.2 (Foundation)
- **Week 2:** Tasks 1.3, 1.4 (First refactor + UI)
- **Week 3:** Task 2.1 (Refactor remaining objects)
- **Week 4:** Tasks 2.2, 2.3 (Polish & signals)

---

## 🐛 Testing Checklist

### After Each Phase:
- [ ] All existing functionality still works
- [ ] No console errors
- [ ] No performance regression
- [ ] Interactions feel responsive
- [ ] Audio plays correctly
- [ ] Animations play correctly
- [ ] State machines work as expected

### Manual Test Cases:
1. **Box Interaction:**
   - [ ] Click to open first pair of lids
   - [ ] Click to open second pair
   - [ ] Click to close (reverse order)
   - [ ] Sounds play at correct times
   - [ ] Can rapid-click without breaking

2. **Light Switch:**
   - [ ] Toggle lights on/off
   - [ ] Sounds play
   - [ ] Animation plays
   - [ ] Controlled lights respond

3. **Boombox:**
   - [ ] Start/stop audio
   - [ ] Secret song unlocks after main song
   - [ ] 3D audio distance works
   - [ ] Animation syncs with audio

4. **Artbox:**
   - [ ] Full sequence plays
   - [ ] Move to wall → orient → unfold
   - [ ] All panels unfold
   - [ ] Can't interrupt animations

---

## 📖 Resources

- **COGITO Analysis:** See `COGITO_INTERACTION_SYSTEM_ANALYSIS.md`
- **Godot Docs - Signals:** https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html
- **Godot Docs - Groups:** https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html
- **Godot Best Practices:** https://docs.godotengine.org/en/stable/tutorials/best_practices/

---

## 💭 Notes & Decisions

### Architecture Decisions:
- **Chose components over inheritance:** More flexible, easier to compose
- **Centralized raycasting:** Better performance, single source of truth
- **Signal-based UI:** Reactive, decoupled, easier to extend
- **No inventory yet:** Not needed for current scope

### Deferred Decisions:
- Save/load system architecture (wait until needed)
- Inventory system (if needed later)
- Networked multiplayer (out of scope)

---

## ✅ Completion Checklist

### Phase 1 - Foundation:
- [x] Task 1.1: PlayerInteractionComponent created
- [x] Task 1.2: InteractionComponent base class created
- [x] Task 1.3: ClickableBox refactored (PENDING TESTING)
- [x] Task 1.4: HUD system implemented
- [ ] All Phase 1 tests passing (TEST NOW)

### Phase 2 - Enhancement:
- [ ] Task 2.1: All objects refactored
- [ ] Task 2.2: AudioManager implemented
- [ ] Task 2.3: Signal-based states added
- [ ] All Phase 2 tests passing

### Phase 3 - Polish:
- [ ] Task 3.1: Debug visualization added
- [ ] Task 3.2: Performance profiled
- [ ] Task 3.3: Code documented
- [ ] All Phase 3 tests passing

### Final Review:
- [ ] Code review completed
- [ ] Performance benchmarks met
- [ ] No regressions
- [ ] Documentation up to date
- [ ] Ready for next features! 🎉

---

**Last Updated:** November 1, 2025  
**Status:** Phase 1 Complete - Ready for Testing  
**Next Steps:** Test system (see TESTING_GUIDE.md), then refactor ClickableBox (Task 1.3)

---

## 🎉 Phase 1 Progress Update

### ✅ Completed (November 1, 2025):
- **Task 1.1:** PlayerInteractionComponent.gd created ✨
- **Task 1.2:** InteractionComponent.gd base class created ✨
- **Task 1.4:** HUD system implemented ✨
- **Updated:** PlayerController.gd to auto-create interaction component
- **Updated:** project.godot to add E key to interact action
- **Created:** SimpleInteraction.gd for testing
- **Created:** TESTING_GUIDE.md and PHASE_1_SUMMARY.md

### 📋 Files Created:
1. `scripts/PlayerInteractionComponent.gd` (165 lines)
2. `scripts/InteractionComponent.gd` (169 lines)
3. `scripts/HUD.gd` (84 lines)
4. `scenes/HUD.tscn`
5. `scripts/SimpleInteraction.gd` (12 lines)
6. `TESTING_GUIDE.md`
7. `PHASE_1_SUMMARY.md`

### 📝 Next Immediate Steps:
1. Open project in Godot
2. Follow TESTING_GUIDE.md to verify system works
3. Add HUD.tscn as child of Player in world.tscn
4. Create test object with SimpleInteraction
5. Verify interaction prompts appear
6. Once verified, proceed to Task 1.3 (Refactor ClickableBox)

---
