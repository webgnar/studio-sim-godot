# 🎨 How to Preview Particles in the Godot Editor

## Quick Answer: Yes, but...

**GPUParticles3D can be seen in the editor**, but the particles in `BreakableWindow.gd` are created dynamically in code, so they only appear when you run the game and trigger them.

---

## Method 1: Test Scene (Easiest)

I created `scenes/particle_test.tscn` for you!

**To use it:**
1. Open `particle_test.tscn` in Godot
2. Select the `GPUParticles3D` node
3. Check **"Emitting"** in the Inspector
4. Particles will play continuously in the editor!
5. Tweak settings in real-time and see changes instantly

**Note:** You'll need to assign a mesh to `draw_pass_1` to see anything:
- Right-click `Draw Pass 1` → Quick Load
- Choose `BoxMesh`, `SphereMesh`, etc.

---

## Method 2: Add Temporary Debug Particles to Your Scene

1. Open `breakable_window.tscn`
2. Add a `GPUParticles3D` child node
3. Configure it to match your code settings
4. Set `Emitting` to true
5. Preview in editor!
6. Delete before final game (or disable)

---

## Method 3: Use the Editor's Built-in Particle Preview

When you select any `GPUParticles3D` node in the editor:
- **Emitting checkbox** - turn particles on/off
- **Restart** button - replay the effect
- **Amount slider** - see more/fewer particles

---

## Key Settings to Match Your Code:

Based on `spawn_glass_shatter()`:

```
Amount: 50
Lifetime: 1.5
One Shot: true (for testing, set to false for continuous loop)
Explosiveness: 0.9
```

**Process Material settings:**
```
Emission Shape: Box
Emission Box Extents: (9, 12, 0.5)
Direction: (0, 0, 1)
Spread: 180
Initial Velocity Min: 3.0
Initial Velocity Max: 8.0
Gravity: (0, -9.8, 0)
Angular Velocity Min: -180
Angular Velocity Max: 180
Scale Min: 0.5
Scale Max: 1.5
Color: Cyan-ish (0.7, 0.9, 1.0, 0.8)
```

---

## 💡 Pro Workflow: Design in Editor, Use in Code

1. **Create your particle effect** in `particle_test.tscn`
2. **Save it as a scene** (e.g., `glass_shatter_particles.tscn`)
3. **Load in code instead of creating from scratch:**

```gdscript
func spawn_glass_shatter():
    var particle_scene = load("res://scenes/glass_shatter_particles.tscn")
    var particles = particle_scene.instantiate()
    get_parent().add_child(particles)
    particles.global_position = global_position
    particles.emitting = true
    
    # Auto-cleanup
    await get_tree().create_timer(particles.lifetime + 1.0).timeout
    particles.queue_free()
```

This way you get **visual editor preview** + **code control**!

---

## ⚠️ Common "Why Can't I See Particles?" Issues:

1. **No mesh assigned** - check `Draw Pass 1` has a mesh
2. **Emitting is off** - check the checkbox
3. **Amount is 0** - increase particle count
4. **Camera is too far** - zoom in closer
5. **Lifetime is too short** - particles disappear quickly
6. **One Shot + already fired** - click Restart button

---

## 🎬 Editor vs Runtime:

**Editor Mode:**
- Particles loop continuously (if `One Shot` is false)
- Great for tweaking visually
- See changes in real-time

**Runtime (Game) Mode:**
- Particles trigger on events (breaking window, etc.)
- One-shot effects
- Spawned dynamically in code

---

Happy particle designing! 🎨✨
