# Debug Console Plan
**For In-Game Computer Screen Display**  
**Date:** November 1, 2025  
**Status:** Deferred until after pickup/physics system

---

## 🎯 Goal

Create an in-game computer screen that displays debug logs in real-time, similar to a developer console but visible as a 3D prop in the game world.

---

## 📋 Requirements

1. **Non-intrusive** - Should NOT require changing existing `print()` calls
2. **File-based logging** - Collect all debug output to a persistent log file
3. **In-game display** - Show logs on a 3D screen/monitor prop
4. **Real-time updates** - Refresh display as new logs come in
5. **No testing interference** - Keep normal debug workflow intact

---

## 🔧 Implementation Plan

### Phase 1: File Logger Singleton
- Create `FileLogger.gd` autoload singleton
- Passively collects debug messages to `user://debug_log.txt`
- Optional explicit logging: `FileLogger.info()`, `FileLogger.error()`, etc.
- Flushes to file periodically and on exit
- Does NOT replace or intercept `print()` calls

### Phase 2: In-Game Display
- Create `ConsoleDisplay.gd` script for 3D screen
- Reads log file every 0.5 seconds
- Displays last 10-20 lines on screen
- Uses RichTextLabel for color-coded output
- Rendered via SubViewport → texture on 3D mesh

### Phase 3: Polish
- Add timestamp formatting
- Color code by log level (INFO, WARN, ERROR)
- Auto-scroll to latest logs
- Optional filtering by category

---

## 💡 Key Design Decisions

- **Use file-based logging** instead of trying to intercept `print()`
- **Opt-in explicit logging** - developers call `FileLogger.log()` when they want something in the file
- **Keep `print()` unchanged** - normal debugging workflow unaffected
- **Read from file for display** - simple and robust

---

## 📝 Usage Pattern

```gdscript
# Normal debugging (works exactly as before)
print("This goes to editor console only")

# Explicit file logging (for important events)
FileLogger.info("Player picked up item")
FileLogger.error("Failed to load texture")

# Both console and file
FileLogger.debug("This message", true)  # true = also print()
```

---

## 🎮 In-Game Scene Setup

```
ComputerScreen (Node3D)
├── MeshInstance3D (screen mesh)
│   └── Material (SubViewport texture)
└── SubViewport
    └── ConsoleDisplay (Control)
        └── RichTextLabel
```

---

## 📂 File Location

Log file saved to: `user://debug_log.txt`
- **macOS:** `~/Library/Application Support/Godot/app_userdata/studio-sim-godot/`
- Persists between sessions
- Can be opened with `FileLogger.open_log_folder()`

---

## ✅ Benefits

- No code changes to existing scripts
- Works alongside normal debugging
- Persistent logs for post-session analysis
- Cool in-game visual element
- Helpful for testing/debugging without console access

---

## 📅 Timeline

**Defer until:** Pickup and physics systems are complete  
**Estimated time:** 2-3 hours total  
**Priority:** LOW (nice-to-have polish feature)

---

## 🔗 Related Files

- Implementation details in conversation history (Nov 1, 2025)
- Will create `scripts/singletons/FileLogger.gd` when ready
- Will update `scripts/consolelog.gd` to become `ConsoleDisplay.gd`

---

**Next Steps:** Focus on Phase 1 of pickup system roadmap first!
