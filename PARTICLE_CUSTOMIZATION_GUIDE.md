# 🎨 Particle Customization Guide

## How to Use Your Own Art for Particles

### Method 1: Custom Textures (Recommended for 2D Art)

#### Step 1: Create Your Particle Images
Create PNG files with transparency for your particles. Good examples:
- **Glass shards**: Triangular/jagged shapes with cyan tint
- **Dust clouds**: Soft, fluffy circular shapes
- **Sparks**: Bright streaks or stars

**Tips:**
- Use **transparent backgrounds** (PNG with alpha channel)
- Keep images square (e.g., 256x256, 512x512)
- Make them **bright** - particles often appear darker in 3D
- Use **white** as base color, you can tint in code

#### Step 2: Import to Godot
1. Create folder: `res://textures/particles/`
2. Drop your PNG files there
3. Godot auto-imports them

#### Step 3: Assign in Inspector
1. Open your `breakable_window.tscn` scene
2. Select the `StaticBody3D` node (the window)
3. In Inspector, scroll to "Particle Effects" section
4. Check `Use Custom Shard Texture`
5. Drag your texture to `Custom Shard Texture` field
6. Same for dust: check `Use Custom Dust Texture` and assign

That's it! Test by breaking the window.

---

### Method 2: Custom 3D Models

For advanced users who want 3D particle meshes:

#### Option A: Use .glb Models
```gdscript
# In spawn_glass_shatter() function, replace the mesh creation:
var mesh = load("res://models/particles/glass_shard.glb")
particles.draw_pass_1 = mesh
```

#### Option B: Create Procedural Meshes
The code currently uses `BoxMesh` for shards. Other options:
- `SphereMesh` - round particles
- `CylinderMesh` - cylindrical
- `PrismMesh` - triangular prisms
- `QuadMesh` - flat billboards (best for textures)

---

## Folder Structure (Recommended)

```
textures/
  particles/
    glass_shard_01.png
    glass_shard_02.png
    dust_cloud.png
    sparkle.png

models/
  particles/
    custom_shard.glb  (if using 3D models)
```

**Note:** You don't *need* a particles folder, but it helps organization!

---

## Advanced: Multiple Random Textures

Want variety? You can randomize particle appearance:

```gdscript
# Array of textures
var shard_textures = [
    load("res://textures/particles/shard_01.png"),
    load("res://textures/particles/shard_02.png"),
    load("res://textures/particles/shard_03.png"),
]

# In spawn_glass_shatter():
var random_texture = shard_textures[randi() % shard_textures.size()]
shard_material.albedo_texture = random_texture
```

---

## Quick Reference: Key Particle Properties

In `ParticleProcessMaterial`:
- `amount` - number of particles
- `lifetime` - how long they exist (seconds)
- `initial_velocity_min/max` - how fast they fly
- `gravity` - falling speed
- `spread` - cone angle (0-180°)
- `scale_min/max` - particle size
- `color` - tint color (multiplied with texture)

---

## Example Custom Texture Specs

**Glass Shard:**
- Size: 256x256px
- Shape: Irregular triangle/shard
- Color: White with slight cyan
- Alpha: Transparent edges, opaque center

**Dust Cloud:**
- Size: 128x128px
- Shape: Soft circular cloud
- Color: White/light gray
- Alpha: Soft gradient (opaque center, transparent edges)

---

## 💡 Pro Tips

1. **Billboard Mode** (`BILLBOARD_ENABLED`) makes flat textures always face the camera
2. **Unshaded Mode** (`SHADING_MODE_UNSHADED`) prevents lighting from darkening particles
3. **Emission** makes particles glow - great for magical effects!
4. **Multiple Draw Passes** - you can use `draw_pass_2`, `draw_pass_3` for variety
5. Test in-game, not just the editor - particles look different in motion!

---

Have fun customizing! 🎨✨
