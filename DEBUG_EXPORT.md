# Debugging Export Issues - Studio Sim

This guide helps you debug input issues in exported builds of Studio Sim.

## Quick Diagnosis Tools

### Debug Overlay (F4)
Press **F4** in-game to toggle the Input Debug Overlay showing:
- Platform and controller type
- Mouse mode and position
- All controller axes and buttons (real-time)
- Right stick values via ControllerMapper
- Steam Input status
- Active input actions

**This is the fastest way to diagnose controller issues!**

### Console Window (Windows)
Windows exports include a console window (via `debug/export_console_wrapper=1`) that shows:
- Initialization messages from all systems
- Mouse capture status
- Controller detection
- Input validation results
- Any errors or warnings

### Debug Log File
All exported builds write detailed logs to:
- **Windows**: `%APPDATA%\Godot\app_userdata\studio sim\debug.log`
- **Linux/Steam Deck**: `~/.local/share/godot/app_userdata/studio sim/debug.log`

The log contains:
- Platform information
- All mouse motion and button events
- Controller names and GUIDs
- Mouse capture attempts (success/failure)
- Input system validation results

## Windows - Mouse Not Working

### Symptoms
- Mouse camera control doesn't work
- Can't look around with mouse
- Mouse may be visible when it should be hidden

### Diagnosis Steps

1. **Check the console window** for these messages:
   ```
   [PlayerController] Mouse captured successfully
   ```
   If you see `Mouse capture FAILED`, that's the problem.

2. **Check debug.log** for mouse events:
   ```
   MouseMotion: relative=(x, y), mouse_mode=CAPTURED
   ```
   If you don't see these when moving the mouse, motion events aren't being received.

3. **Press F4** to show debug overlay and check "Mouse Mode":
   - Should show `CAPTURED` during gameplay
   - If it shows `VISIBLE`, mouse isn't being captured

### Solutions

**If mouse capture fails on startup:**
- Try Alt+Tab out and back into the game
- The window focus handler should recapture the mouse automatically
- Check console for: `[PlayerController] Window focused - recapturing mouse`

**If mouse still doesn't work:**
- Try running as administrator (Windows may be blocking mouse capture)
- Check if another application is capturing the mouse
- Verify no accessibility software is interfering

**If mouse works in editor but not export:**
- This is fixed by the new window focus handling code
- Check debug.log to see if mouse mode transitions are happening

## Steam Deck - Controller Not Working

### Symptoms
- Some buttons work, others don't
- Right stick doesn't control camera
- Controller partially functional

### Diagnosis Steps

1. **Press F4** to show debug overlay:
   - Check "Platform" section - should show "Steam Deck: YES"
   - Watch "Axes" section while moving right stick
   - Note which axis numbers change when you move right stick

2. **Check the console** for controller detection:
   ```
   [ControllerMapper] Steam Deck detected
   [ControllerMapper] Connected controllers: 1
     [0] Valve Jupiter (GUID: ...)
   ```

3. **If controller name is wrong** (e.g., shows as "Xbox Controller"):
   - Steam Deck detection may have failed
   - The controller will use wrong axis mappings

### Solutions

**If right stick doesn't work:**

Run the game with controller calibration:
```bash
./studio-sim.x86_64 --calibrate-controller
```

Follow the on-screen instructions:
1. You'll have 3 seconds to move the RIGHT STICK in circles
2. The game will auto-detect which axes are the right stick
3. Calibration complete!

**If detection fails:**

Force Steam Deck mode:
```bash
./studio-sim.x86_64 --force-steam-deck
```

This overrides detection and forces Steam Deck controller mapping.

**If some buttons don't work:**
- Check which buttons work in the F4 overlay
- Compare button numbers to `project.godot` input mappings
- Some bindings may need adjustment for Steam Deck

## Launch Options (Command-Line Flags)

Run the game with these flags for debugging:

### Windows
```batch
studio-sim.exe --debug-overlay
```

### Linux / Steam Deck
```bash
./studio-sim.x86_64 --debug-overlay
```

### Available Options

| Flag | Description |
|------|-------------|
| `--debug-overlay` | Show debug overlay on startup (instead of pressing F3) |
| `--debug-input` | Enable extra verbose input logging |
| `--calibrate-controller` | Run controller calibration on startup |
| `--force-steam-deck` | Force Steam Deck controller mode |

### Examples

**Diagnose controller issues on Steam Deck:**
```bash
./studio-sim.x86_64 --debug-overlay --force-steam-deck
```

**Calibrate unknown controller:**
```bash
./studio-sim.x86_64 --calibrate-controller
```

## Steam Input API (When Launched Through Steam)

When you launch the game through Steam, Steam Input API automatically activates:
- Provides superior controller support
- Works with ANY controller (Xbox, PlayStation, Switch, Steam Deck, adaptive controllers)
- Players can remap controls through Steam Overlay
- Automatic button glyphs for their controller type

### Checking Steam Input Status

1. Press F4 to show Input Debug Overlay
2. Look at the "STEAM INPUT" section:
   - "Status: ENABLED" = Steam Input is active (best experience)
   - "Status: Not available" = Using Godot Input fallback

### When Steam Input Doesn't Activate

Steam Input only works when:
1. Game is launched through Steam
2. Steam is running
3. You have a controller connected

If running standalone (.exe directly), you'll use Godot Input + ControllerMapper (which still works great!).

## Common Issues & Solutions

### Mouse works but camera doesn't move
- **Cause**: Mouse not captured (mode is VISIBLE instead of CAPTURED)
- **Solution**: Click in the game window, or Alt+Tab back to the game

### Controller detected but right stick doesn't work
- **Cause**: Wrong axis mapping for this controller type
- **Solution**: Run with `--calibrate-controller` flag

### Debug overlay not showing with F4
- **Cause**: Only works in exported builds (disabled in editor)
- **Solution**: Export the game and run the export
- **Note**: F3 is used by ValidationDebugOverlay, F4 is for Input Debug

### No debug.log file created
- **Cause**: Only created in exported builds (not in editor)
- **Check location**:
  - Windows: `%APPDATA%\Godot\app_userdata\studio sim\`
  - Linux: `~/.local/share/godot/app_userdata/studio sim/`

### "Steam Deck detected" but I'm on PC
- **Cause**: Controller name contains "Valve" or detection misfire
- **Solution**: This is harmless, or use `--force-xbox` (if we add it)

## Reporting Issues

If you still have input issues after trying the above:

1. **Gather this information:**
   - Platform (Windows/Linux/Steam Deck)
   - Controller type and name (from F4 Input Debug Overlay)
   - Contents of debug.log file
   - Screenshot of F4 Input Debug Overlay
   - Whether running through Steam or standalone

2. **Describe the issue:**
   - What input doesn't work (mouse/specific buttons/right stick)?
   - Does it work in Godot editor?
   - Does it work in other games?

3. **Submit:**
   - Create an issue on GitHub with the above information

## Technical Details

### Input System Architecture

The game uses a layered input system:

1. **DebugLogger**: Logs all input events to file
2. **ControllerMapper**: Detects platform and maps controller axes correctly
3. **SteamInput**: Uses Steam Input API when available, falls back to Godot Input
4. **Game Code**: Uses unified input interface (works regardless of source)

### Mouse Capture System

- Uses `Input.MOUSE_MODE_CAPTURED` to hide and center cursor
- Window focus events automatically recapture mouse
- Retry mechanism ensures capture succeeds
- UIManager integration respects menu states

### Controller Detection

**Steam Deck detection methods:**
1. Check `/sys/devices/virtual/dmi/id/product_name` for "Jupiter"
2. Use GodotSteam's `isSteamRunningOnSteamDeck()`
3. Check controller name for "Valve" or "Jupiter"

**Axis mapping:**
- Xbox: Right stick = Axis 2 (X), Axis 3 (Y)
- Steam Deck: Usually same, but can vary
- Auto-calibration detects actual axes by monitoring movement

### Export Settings

**Windows:**
- `debug/export_console_wrapper=1` - Shows console window for logging

**Linux:**
- `binary_format/architecture="x86_64"` - 64-bit for Steam Deck compatibility

## Best Practices

### Testing Exports

1. **Always test standalone first** (not through Steam):
   - This tests the core Godot Input system
   - Ensures fallback works

2. **Then test through Steam**:
   - This tests Steam Input API
   - Verifies Steam Deck profile

3. **Test both input modes**:
   - Keyboard + Mouse
   - Controller (preferably on actual target platform)

### Using Debug Tools

- **During development**: Use F4 Input Debug Overlay to verify input (F3 for validation overlay)
- **Before shipping**: Disable debug_mode in SteamManager.gd
- **For testing builds**: Keep console wrapper enabled
- **For release builds**: Can disable console wrapper if desired

## Additional Resources

- [Godot Input Documentation](https://docs.godotengine.org/en/stable/tutorials/inputs/)
- [Steam Input API Documentation](https://partner.steamgames.com/doc/features/steam_controller)
- [GodotSteam Documentation](https://godotsteam.com/)

## Version History

- v1.0 - Initial debug system implementation
  - Added DebugLogger, InputValidator, ControllerMapper
  - Window focus handling for mouse capture
  - Steam Deck controller support
  - Steam Input API integration
