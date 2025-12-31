# Input System Analysis for Windows/Linux Builds

## Executive Summary

You have **good foundations** in place but several **critical issues** that could cause controller problems on Steam Deck, Windows, and Linux builds. The main problem is that your game code **bypasses** your SteamInput wrapper and directly uses Godot's Input system with hard-coded device indices.

---

## ✅ What's Working Well

### 1. Steam Input VDF File ✅
- **Location**: `steam_input_manifest.vdf` exists in root
- **Content**: Properly defines actions and action sets
- **Coverage**: All major gameplay actions mapped

### 2. InputMap Configuration ✅
- **Device Handling**: All actions use `device:-1` (All Devices) ✅
- This is CORRECT per the guide - won't fail on Steam Deck where internal pad might be device 1 or 2

### 3. GodotSteam Integration ✅
- GodotSteam addon installed and initialized
- `SteamManager` calls `Steam.inputInit()` at line 306
- Steam callbacks run every frame in `_process()`

### 4. Platform Detection ✅
- `ControllerMapper.gd` detects Steam Deck properly
- Multiple detection methods (DMI, GodotSteam API, controller name)

---

## ⚠️ Critical Issues That Will Break Cross-Platform Input

### 1. **PlayerController Bypasses Steam Input Wrapper** 🔴 HIGH PRIORITY

**Problem:**
```gdscript
# PlayerController.gd:224
if Input.is_action_just_pressed("jump") and is_on_floor():

# PlayerController.gd:229
var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
```

Your `PlayerController` uses `Input.*` directly instead of `SteamInput.*`

**Why This Matters:**
- Steam Deck's internal controller won't work if Steam Input is enabled
- You built a wrapper (`SteamInput.gd`) but never use it
- Guide says: "Always query both Steam Input and Input.is_action_pressed() and merge them"

**Fix:**
Replace all `Input.is_action_*` calls in gameplay code with `SteamInput.is_action_*`

---

### 2. **Hard-Coded Device 0 in Camera Look** 🔴 HIGH PRIORITY

**Problem:**
```gdscript
# PlayerController.gd:265-270
if ControllerMapper:
    look_x = ControllerMapper.get_axis_raw(0, "right_stick_x", 0.15)
    look_y = ControllerMapper.get_axis_raw(0, "right_stick_y", 0.15)
else:
    look_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)  # ← Hard-coded device 0!
    look_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
```

**Why This Matters:**
- Guide explicitly warns: "Hard-coding device 0 → works on your Xbox pad, fails on Deck (internal pad is device 1 or 2)"
- Steam Deck's built-in controller is often NOT device 0
- This is the #1 reason games fail Steam Deck certification

**Fix:**
Use `SteamInput.get_analog_action("camera")` instead of raw axis polling

---

### 3. **Incorrect VDF Action Types** 🟡 MEDIUM PRIORITY

**Problem:**
```vdf
# steam_input_manifest.vdf:8-9
"move"
{
    "type" "joystick_move"  # ← Should be "analog"
```

**Why This Matters:**
- Guide says: `"Move" "analog"` and `"Fire" "digital"`
- Steam expects standard types: `"analog"` or `"digital"` (sometimes `"button"` works)
- `"joystick_move"` and `"joystick_camera"` are non-standard and may not work correctly

**Fix:**
```vdf
"move"
{
    "type" "analog"
    "title" "Movement"
}

"camera"
{
    "type" "analog"
    "title" "Camera Look"
}
```

---

### 4. **Missing Device Callbacks** 🟡 MEDIUM PRIORITY

**Problem:**
```gdscript
# SteamManager.gd:306
var init_result = Steam.inputInit(false)
```

Guide says you need:
```gdscript
Steam.inputInit()
Steam.enableDeviceCallbacks()  # ← Missing!
```

**Why This Matters:**
- Without device callbacks, you won't know when controllers connect/disconnect
- Hot-swapping controllers won't work properly

---

### 5. **SteamInput Wrapper Incomplete** 🟡 MEDIUM PRIORITY

**Problems in `SteamInput.gd`:**

```gdscript
# Lines 118-126
func is_action_just_pressed(action_name: String) -> bool:
    if _is_steam_input_active():
        # Steam Input doesn't have "just pressed" - we'd need to track state changes
        # For now, use the state directly (this is a limitation)
        return _get_steam_digital_action_state(action_name)  # ← Wrong!
```

**Why This Matters:**
- "Just pressed" will fire every frame, not just once
- Jump will be uncontrollable with Steam Input enabled
- You need to track previous frame state

**Fix Pattern:**
```gdscript
var _previous_states: Dictionary = {}

func is_action_just_pressed(action_name: String) -> bool:
    if _is_steam_input_active():
        var current = _get_steam_digital_action_state(action_name)
        var previous = _previous_states.get(action_name, false)
        _previous_states[action_name] = current
        return current and not previous
    else:
        return Input.is_action_just_pressed(action_name)
```

---

### 6. **No Handle Validation** 🟡 MEDIUM PRIORITY

**Problem:**
```gdscript
# SteamInput.gd:52-55
input_handles = Steam.getConnectedControllers()
if input_handles.size() > 0:
    active_input_handle = input_handles[0]
```

Then later:
```gdscript
# Lines 63-85
action_handles["jump"] = Steam.getDigitalActionHandle("jump")
# ... etc
```

**Why This Matters:**
- Guide warns: "Wait for a device to connect before you ask for action handles; otherwise you get 0 handles"
- If no controller is connected at startup, all handles will be 0
- Game will fail to work if user connects controller after launch

**Fix:**
Only call `_setup_action_handles()` after confirming at least one controller is connected, OR validate handles aren't 0

---

## 🔍 Testing Checklist (From Guide)

Before shipping, you MUST test:

- [ ] **Steam off** → Native SDL still works (Windows / Linux)
- [ ] **Steam on, Steam Input off** → Still works (community template fallback)
- [ ] **Steam Input on with your VDF** → Glyphs appear, bindings stick
- [ ] **Steam Deck** → Verify on-device; Valve rejects if built-in controls fail
- [ ] **Big Picture / Desktop / Overlay** → Overlay opens and glyphs refresh
- [ ] **Controller hot-swap** → Plug/unplug controller while game running
- [ ] **Multiple controllers** → Test with 2+ controllers connected

---

## 🚨 Recommended Action Plan

### Phase 1: Critical Fixes (Do Before Exporting)

1. **Fix hard-coded device 0 in PlayerController.gd**
   - Replace all `Input.get_joy_axis(0, ...)` with `SteamInput.get_analog_action("camera")`

2. **Route all input through SteamInput wrapper**
   - Replace `Input.is_action_pressed(...)` → `SteamInput.is_action_pressed(...)`
   - Replace `Input.get_vector(...)` → `SteamInput.get_vector(...)`

3. **Fix VDF action types**
   - Change `"joystick_move"` → `"analog"`
   - Change `"joystick_camera"` → `"analog"`
   - Keep buttons as `"button"` or `"digital"`

### Phase 2: Polish (Do Before Steam Deck Testing)

4. **Implement proper just_pressed/just_released tracking in SteamInput**
   - Track previous frame state
   - Return edge detection, not current state

5. **Add device callbacks**
   - Call `Steam.enableDeviceCallbacks()`
   - Handle controller connect/disconnect events

6. **Validate action handles**
   - Check handles aren't 0 after setup
   - Fallback gracefully if handles fail

### Phase 3: Testing (Required Before Ship)

7. **Test on Windows without Steam**
   - Should fall back to Godot Input

8. **Test on Windows with Steam + Xbox controller**
   - Verify Steam Input glyphs appear

9. **Test on Steam Deck** (or Steam Deck verification environment)
   - THIS IS THE BIG ONE

---

## 📋 Code Architecture Recommendation

Your current flow:
```
PlayerController → Input (Godot) ✗ Wrong
                → ControllerMapper → Input.get_joy_axis(0, ...) ✗ Wrong
```

Should be:
```
PlayerController → SteamInput → Steam Input API (if available)
                              → Input (Godot fallback)
```

All gameplay code should ONLY talk to `SteamInput`. Never directly to Godot's `Input`.

---

## 🎯 Quick Win: Minimal Change for Export

If you need to export RIGHT NOW and can't refactor everything, here's the bare minimum:

1. In `PlayerController.gd`, find every place you use `Input.get_joy_axis(0, ...)`
2. Change the `0` to `-1` (ALL DEVICES)
3. Update VDF action types to `"analog"` / `"digital"`

This won't give you Steam Input glyphs, but it will at least work on Steam Deck in fallback mode.

---

## Questions to Clarify

1. **Do you want full Steam Input API support** (glyphs, custom bindings, Steam Deck optimized)?
   - If YES → Implement SteamInput wrapper fully
   - If NO → Keep it simple, just fix device 0 hardcoding

2. **Are you shipping on Steam only**, or also itch.io / standalone?
   - Steam only → Can rely on Steam Input more heavily
   - Multi-platform → Need robust fallback to Godot Input

3. **Testing environment**: Do you have access to:
   - Steam Deck hardware?
   - Windows PC with Xbox controller?
   - Linux PC?

Let me know which fixes you want to prioritize and I can help implement them!
