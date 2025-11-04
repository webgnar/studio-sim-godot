# Camera System Setup Guide

## Overview
This camera system allows for Resident Evil-style fixed camera zones and smooth transitions between first-person and cinematic cameras. It supports multiple cameras per zone, camera cycling, and priority-based zone stacking.

## Files Created
- `scripts/CameraManager.gd` - Singleton autoload for managing camera transitions
- `scripts/CameraZone.gd` - Script for camera trigger zones
- `scenes/CameraZone.tscn` - Template scene for camera zones
- `project.godot` - Updated with CameraManager autoload

## Quick Start

### 1. Integrate with Player
Add this to your `PlayerController.gd` in the `_ready()` function:

```gdscript
func _ready() -> void:
	# ... existing code ...
	
	# Register player camera with CameraManager
	if _camera:
		CameraManager.register_player_camera(_camera)
```

### 2. Check for input override in player movement
In your player's `_physics_process()` or input handling, add a check:

```gdscript
func _physics_process(delta: float) -> void:
	# Skip player input if CameraManager has disabled it
	if not CameraManager.player_input_enabled:
		return
	
	# ... rest of movement code ...
```

Or for mouse look in `_unhandled_input()`:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	# Only handle mouse if input is enabled
	if not CameraManager.player_input_enabled:
		return
	
	# ... mouse look code ...
```

### 3. Create a Camera Zone in Your Scene

**Option A: Use the template**
1. Instance `scenes/CameraZone.tscn` into your world
2. Position the zone where you want the camera trigger
3. Add Camera3D nodes as children and position them where you want the view
4. Adjust the CollisionShape3D size to define the trigger area

**Option B: Manual setup**
1. Create an Area3D node
2. Attach `scripts/CameraZone.gd` script
3. Add CollisionShape3D as child (defines trigger volume)
4. Add one or more Camera3D nodes as children
5. Position cameras to desired viewpoints

### 4. Configure Zone Properties
Select your CameraZone and configure in the Inspector:

- **Zone Priority**: Higher priority zones override lower ones when overlapping (default: 0)
- **Blend Time**: Seconds to smoothly transition between cameras (default: 0.6)
- **Auto Disable Player Input**: Prevent player movement in this zone (default: false)
- **Cycle Enabled**: Auto-cycle through multiple cameras (default: false)
- **Cycle Interval**: Seconds between camera switches (default: 4.0)
- **Cycle Cameras**: Explicit NodePaths to cameras (optional, auto-detects children)

## Usage Examples

### Example 1: Simple Fixed Camera Zone
Creates a security camera view when player enters a hallway:

1. Instance `CameraZone.tscn` 
2. Scale CollisionShape3D to cover hallway entrance
3. Position the included `SecurityCamera1` node to look down the hallway
4. Set `blend_time = 1.0` for a slow, cinematic transition

### Example 2: Multi-Camera Cycling Zone
Cycle between 3 different angles in a room:

1. Create CameraZone
2. Add 3 Camera3D children, position at different corners
3. Enable `cycle_enabled = true`
4. Set `cycle_interval = 5.0` (switches every 5 seconds)
5. Optionally `auto_disable_player_input = true` to make it cinematic

### Example 3: Overlapping Priority Zones
Layer zones with different priorities:

1. Create wide zone covering entire room: `zone_priority = 0`
2. Create smaller zone near desk: `zone_priority = 10`
3. When player approaches desk, higher priority zone takes over
4. When leaving desk area, returns to room-wide camera

## Advanced Features

### Manual Camera Control
You can script camera switches from other code:

```gdscript
# Force switch to a specific camera
CameraManager.switch_to_camera(my_camera_node, 0.5)

# Switch back to player camera
CameraManager.switch_to_camera(CameraManager.player_camera, 1.0)

# Instant switch (no blend)
CameraManager.force_camera_immediate(cutscene_camera)
```

### Scripted Camera Sequences
Switch cameras manually from a CameraZone:

```gdscript
# In your own script connected to the zone:
func _on_player_trigger_something():
	var zone = $CameraZone
	zone.set_camera_index(2)  # Switch to 3rd camera
```

### Check Active Camera
```gdscript
if CameraManager.current_camera != CameraManager.player_camera:
	print("Player is in a cinematic camera")
```

## Player Detection
By default, CameraZone checks for the player using:
1. Node name == "Player"
2. Node in group "player"

Your player is already in the "player" group (added in PlayerController._ready()), so zones will detect it automatically.

## Troubleshooting

**Camera doesn't switch:**
- Verify CameraManager is registered as autoload in project.godot
- Check that player camera was registered in PlayerController._ready()
- Ensure player has collision layer that matches zone's collision mask

**Camera switches but player can still move:**
- Set `auto_disable_player_input = true` on the zone
- Add input check in PlayerController (see step 2 above)

**Choppy transitions:**
- Increase `blend_time` for smoother transitions
- Check that camera positions aren't too far apart

**Overlapping zones fighting:**
- Use different priority values
- Check collision shapes aren't overlapping unintentionally

## Next Steps
- Create cutscene system (uses same CameraManager)
- Add camera shake/effects during transitions
- Implement camera rails/paths for moving cameras
