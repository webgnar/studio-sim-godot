# Laser Beam Visualization - Setup Instructions

## What This Does
Creates a red laser beam that shows where the player is looking, **only visible when in camera zones** (cinematic view). Perfect for debugging interactions or creating a sci-fi aesthetic.

## Quick Setup

### Option 1: Add to Player in Godot Editor
1. Open `scenes/world.tscn`
2. Select the `Player` node
3. Add a new child node: `Node3D` (name it `LaserBeamVisualizer`)
4. Attach the script `scripts/PlayerLaserBeam.gd` to it
5. In the Player's `Head/Camera3D` node, add a child `RayCast3D` node
6. Configure the RayCast3D:
   - **Enabled**: true
   - **Target Position**: (0, 0, -100)
   - **Collide With Areas**: true
   - **Collide With Bodies**: true
7. Save the scene

### Option 2: Manual Scene File Edit
I can add these nodes directly to your world.tscn file if you'd like.

## How It Works
- The laser beam is **only visible** when `CameraManager.current_camera != CameraManager.player_camera`
- This means it only shows up in camera zones, not in first-person view
- The beam dynamically adjusts its length based on what the raycast hits
- Red glowing cylinder mesh with emission

## Customization (in Inspector)
- **Beam Color**: Change the color (default: red)
- **Beam Width**: Thickness of the beam (default: 0.02)
- **Max Beam Length**: How far it reaches (default: 100.0)
- **Raycast Path**: NodePath to your RayCast3D

## Testing
1. Run the game
2. Walk into a camera zone
3. You should see a red laser beam shooting from where you're looking
4. Exit the camera zone - beam disappears (back to first-person)

## Optional: Use for Interactions
If you want to use this raycast for interactions (clicking on objects), you can query it:
```gdscript
# In another script:
var laser = $Player/LaserBeamVisualizer
if laser._raycast.is_colliding():
    var hit_object = laser._raycast.get_collider()
    print("Looking at: ", hit_object.name)
```

Would you like me to add this directly to your world scene?
