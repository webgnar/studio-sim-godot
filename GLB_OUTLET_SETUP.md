# Setting Up GLB Outlet Models

**Quick Reference for Making GLB Models into Outlets**

---

## 🔌 GLB Outlet Setup (Same Pattern as Carryable Objects):

### **Step 1: Import GLB with Physics Disabled**

1. **Select your outlet GLB** in FileSystem
2. **Click "Import" tab** (next to Scene)
3. **Find "Meshes" section**
4. **Set:** `Meshes > Physics > Body Type` → **Static** (or disable entirely)
5. **Click "Reimport"**

This prevents duplicate collision issues.

---

### **Step 2: Create Outlet Scene**

**Scene Structure:**
```
WallOutlet (StaticBody3D)
├── CollisionShape3D (BoxShape3D or ConvexPolygonShape3D)
├── outlet_model (Imported GLB as child scene)
├── PlugSocketMarker (Marker3D)
└── OutletComponent (script attached to StaticBody3D)
```

**Detailed Steps:**

1. **Create new scene:** Scene → New Scene
2. **Root node:** StaticBody3D (name: "WallOutlet")
3. **Add collision:**
   - Add Child → CollisionShape3D
   - Shape → BoxShape3D
   - Size to match outlet faceplate
4. **Instance GLB:**
   - Right-click StaticBody3D → Instance Child Scene
   - Navigate to your outlet GLB
   - Select and instance
5. **Add marker:**
   - Add Child → Marker3D (name: "PlugSocketMarker")
   - Position ~0.05 units in front of outlet face
   - This is where plugs snap to
6. **Add script:**
   - Select StaticBody3D (root)
   - Attach script → `res://scripts/components/OutletComponent.gd`

---

### **Step 3: Configure OutletComponent**

**In Inspector (with StaticBody3D selected):**

1. **Plug Socket Marker:**
   - Drag PlugSocketMarker node into this field
   
2. **Settings:**
   ```
   Auto Power On Plug: ✅ true
   Allow Unplug: ✅ true
   ```

3. **Optional - Visual Feedback:**
   - If your GLB has an LED indicator mesh, assign it to `Indicator Mesh`
   - Assign materials for powered/unpowered states

---

### **Step 4: Position PlugSocketMarker Correctly**

**Critical for plug snapping!**

1. **Select PlugSocketMarker** in scene tree
2. **Move it** using 3D gizmo
3. **Position:** 
   - 0.05-0.1 units in **front** of outlet face
   - Centered on the socket holes
4. **Rotation:**
   - Should face outward from wall
   - Z-axis pointing away from outlet

**Test position:**
- When plug connects, it should look natural
- Not inside wall, not floating away

---

### **Step 5: Collision Layers**

**Set on StaticBody3D:**
- **Collision Layer:** 2 (Static World)
- **Collision Mask:** 1 (can be 0 if outlet doesn't need to detect anything)

---

### **Step 6: Add to Group**

**Important for plug detection!**

1. **Select StaticBody3D** (root)
2. **Node tab** (next to Inspector)
3. **Groups section**
4. **Add to group:** `outlets`

*(OutletComponent does this automatically, but good to verify)*

---

## 📐 Example Setup:

### **GLB Model: `models/props/wall_outlet.glb`**

**Import Settings:**
- Meshes → Physics → Body Type: **Static** (disabled)

**Scene Hierarchy:**
```
WallOutlet (StaticBody3D)
│   Script: OutletComponent.gd
│   Collision Layer: 2
│   Collision Mask: 0
│   Groups: ["outlets"]
│
├── CollisionShape3D
│   └── Shape: BoxShape3D
│       └── Size: (0.15, 0.1, 0.05)
│
├── wall_outlet_model (Instanced from GLB)
│   └── [GLB mesh hierarchy]
│
└── PlugSocketMarker (Marker3D)
    └── Position: (0, 0, 0.05)  ← In front of outlet
```

**OutletComponent Inspector:**
- Plug Socket Marker: → PlugSocketMarker
- Auto Power On Plug: ✅
- Allow Unplug: ✅

---

## 🎨 Visual Polish (Optional):

### **If GLB has LED Indicator:**

1. **Find LED mesh** in GLB hierarchy
2. **Create two materials:**
   - `outlet_led_on.tres` (green/bright)
   - `outlet_led_off.tres` (gray/dim)
3. **Assign in OutletComponent:**
   - Indicator Mesh: → (LED mesh from GLB)
   - Powered Material: → outlet_led_on.tres
   - Unpowered Material: → outlet_led_off.tres

Now LED changes color when plug connects!

### **If GLB has Socket Holes:**

Position PlugSocketMarker precisely at socket entrance so plug aligns visually.

---

## ✅ Quick Checklist:

- [ ] GLB imported with physics disabled
- [ ] StaticBody3D created as root
- [ ] CollisionShape3D added and sized
- [ ] GLB instanced as child
- [ ] PlugSocketMarker created and positioned
- [ ] OutletComponent attached to root
- [ ] Marker assigned in OutletComponent
- [ ] Collision layer set to 2
- [ ] Added to "outlets" group
- [ ] Saved scene

---

## 🐛 Common Issues:

### **Plug won't detect outlet:**
- Check outlet is in "outlets" group
- Verify PlugSocketMarker is assigned in component
- Check collision layer is 2

### **Plug snaps to wrong position:**
- Adjust PlugSocketMarker position
- Should be in front of outlet face, centered

### **Outlet has invisible collision:**
- Disable physics in GLB import settings
- Only use CollisionShape3D on StaticBody3D

### **LED doesn't change:**
- Check Indicator Mesh is assigned
- Verify materials are different (on vs off)

---

## 🚀 You're Done!

**Instance outlet in your world:**
1. Drag saved outlet scene into world
2. Position on wall
3. Test with power cord
4. Should work perfectly!

---

**Pattern:** GLB model → StaticBody3D wrapper → Manual collision → Component script

*(Same pattern as making GLB objects carryable, just StaticBody3D instead of RigidBody3D)*
