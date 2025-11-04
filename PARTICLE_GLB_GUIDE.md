# 🎨 Using Custom GLB Models for Particles

## ✅ Setup Complete!

Your `breakable_window.tscn` now has particles **automatically assigned**:
- Glass shatter: `glass_shard_particle.tscn`
- Dust puffs: `dust_particle_test.tscn`

**All windows in your world automatically get these!** No need to assign them manually.

---

## 🔧 How to Use Your Custom GLB Glass Shards

### Method 1: Replace in Particle Scene (Affects All Windows)

1. Open `scenes/glass_shard_particle.tscn`
2. Select the `GPUParticles3D` node
3. In Inspector → **Draw Passes** section
4. Click dropdown next to **"Draw Pass 1"**
5. Choose **"Quick Load"** or **"Load"**
6. Navigate to your GLB file (e.g., `models/props/my_glass_shard.glb`)
7. Select it
8. Save the scene

✅ **Done!** All windows now use your custom GLB shard.

---

## 📦 Creating Your GLB Shard Model

**In Blender:**
1. Create a jagged/triangular shard shape
2. Keep it **low poly** (< 100 triangles recommended)
3. Make it **small** (about 0.2-0.5 units)
4. Add material (glass-like, transparent)
5. Export as GLB
6. Import to Godot `models/props/` folder

**Tips:**
- Make multiple shard variations for variety!
- Add slight transparency to the material
- Keep file size small (particles spawn 50+ instances)

---

## 🎭 Using Multiple Shard Styles

Want different windows with different shard types?

### Step 1: Create Variations
1. Duplicate `glass_shard_particle.tscn`
2. Rename: `glass_shard_particle_blue.tscn`
3. Open it, assign different GLB or change colors
4. Save

### Step 2: Assign to Specific Windows
1. In `world.tscn`, find a specific window instance
2. Select it
3. In Inspector → **Particle Effects**
4. Override `Glass Particle Scene` with your variation

---

## 🎨 Particle Scene Customization

Open either particle scene to tweak:

### Visual Settings:
- **Amount**: Number of particles (50 default for glass)
- **Lifetime**: How long they exist (1.5s for glass)
- **Scale Min/Max**: Size range (0.5-1.5 for glass)
- **Color**: Tint color (cyan for glass)

### Physics Settings (in ParticleProcessMaterial):
- **Initial Velocity Min/Max**: Speed (3-8 for glass)
- **Gravity**: Falling speed (-9.8 for realistic)
- **Spread**: Cone angle (180° = all directions)
- **Angular Velocity**: Spin speed (±180° for glass)

### Mesh:
- **Draw Pass 1**: The mesh/model each particle uses
- Can be: PrismMesh, BoxMesh, SphereMesh, or **GLB model**

---

## 🐛 Troubleshooting

**"Particles not showing"**
- Check `Enable Particles` is checked on window
- Check particle scenes are assigned in Inspector
- Check GLB mesh is assigned in particle scene
- Look for warnings in console

**"Particles look wrong"**
- Open particle scene and preview in editor
- Check `Emitting` is true to see them live
- Adjust scale/color/velocity settings

**"Too many/few particles"**
- Change `Amount` in the GPUParticles3D node
- 50 is good for glass, 30 for dust

---

## 💡 Pro Tips

1. **Preview in Editor**: Open particle scene, set `Emitting = true`, see changes live
2. **One Scene Per Style**: Create different particle scenes for different effects
3. **Low Poly GLBs**: Keep shard models simple for performance
4. **Test Scale**: If GLB shards are too big/small, scale them in Blender before export
5. **Material Matters**: GLB materials are preserved in particles!

---

Happy particle customizing! 🎉✨
