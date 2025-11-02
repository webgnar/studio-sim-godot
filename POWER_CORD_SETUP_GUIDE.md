# Power Cord System - Setup Guide
**Physics-Based Power Cords with Plug/Unplug Mechanics**  
**Date:** November 1, 2025

---

## ✅ Files Created:

1. `scripts/components/PowerCordPlugComponent.gd` - Extends CarryableComponent
2. `scripts/components/OutletComponent.gd` - Extends InteractionComponent  
3. `scripts/tools/PowerCordBuilder.gd` - @tool script to generate cords
4. Updated `PlayerInteractionComponent.gd` - Handles plug interactions

---

## 🔧 How to Create a Power Cord:

### **Step 1: Create New Scene**

1. **File → New Scene**
2. **Root node:** Node3D
3. **Name:** `power_cord`
4. **Save as:** `scenes/props/power_cord.tscn`

### **Step 2: Add PowerCordBuilder**

1. **Attach script** to root Node3D
2. **Navigate to:** `res://scripts/tools/PowerCordBuilder.gd`
3. **In Inspector**, configure settings:
   ```
   Cord Structure:
   - Segment Count: 20 (adjust for longer/shorter cord)
   - Segment Length: 0.1
   - Segment Radius: 0.02 (thickness)
   
   Physics Properties:
   - Cord Mass: 0.05 (per segment)
   - Linear Damping: 0.1
   - Angular Damping: 0.2
   
   Joint Settings:
   - Joint Stiffness: 0.01 (lower = tighter)
   - Angular Limit: 45.0 degrees
   
   Visual:
   - Cord Material: (optional - assign a material)
   - Plug Mesh: (optional - custom plug model)
   ```

4. **Toggle "Rebuild Cord"** checkbox in Inspector
5. **Watch the magic!** The tool will generate:
   - Anchor (StaticBody3D - fixed point)
   - 20 Segments (RigidBody3D with physics)
   - 20 Joints (Generic6DOFJoint3D)
   - PowerCordPlugComponent on last segment

### **Step 3: Position the Anchor**

1. **Select "Anchor"** node in scene tree
2. **Position it** where the cord should be attached (wall, device, etc.)
3. The cord will dangle from this point with physics!

### **Step 4: Save and Test**

1. **Save the scene**
2. **Instance it** in your world
3. **Run the game**
4. **Pick up the plug** (E key) - cord drags along!

---

## 🔌 How to Create an Outlet:

### **Step 1: Create Outlet Scene**

```
Outlet (StaticBody3D)
├── CollisionShape3D (BoxShape)
├── MeshInstance3D (outlet model/plate)
├── PlugSocketMarker (Marker3D) ← Where plug snaps to
└── OutletComponent (script)
```

### **Step 2: Setup OutletComponent**

1. **Add OutletComponent** to StaticBody3D
2. **Create Marker3D** as child (name: PlugSocketMarker)
3. **Position marker** slightly in front of outlet face
4. **Assign marker** to OutletComponent → Plug Socket Marker field

### **Step 3: Configure Settings**

In Inspector:
```
Outlet Settings:
- Plug Socket Marker: (drag PlugSocketMarker here)
- Auto Power On Plug: ✅ true
- Allow Unplug: ✅ true

Visual Feedback: (optional)
- Powered Material: (green/on material)
- Unpowered Material: (gray/off material)
- Indicator Mesh: (LED mesh)

Audio: (optional)
- Plug In Sound: (click sound)
- Plug Out Sound: (unplug sound)
```

### **Step 4: Save and Instance**

1. **Save as:** `scenes/props/wall_outlet.tscn`
2. **Instance in world**
3. **Position on wall** or wherever needed

---

## 🎮 How It Works (Player Experience):

### **Carrying the Plug:**

1. **Look at plug** → See "Pick Up Plug" prompt
2. **Press E** → Pick up plug
3. **Cord drags** behind with realistic physics
4. **Carry toward outlet**

### **Near an Outlet:**

1. **Get close** (within 0.5m by default)
2. **Prompt changes** → "Press E to Plug In • Click to Throw"
3. **Press E or Left Click** → Plug snaps to outlet, locks in place
4. **Or walk away** → Cord stays carried

### **Unplugging:**

1. **Look at outlet** with plugged cord
2. **Prompt:** "Unplug"
3. **Press E** → Cord unplugs, becomes physics-based again
4. **Can pick up** and move to another outlet

---

## ⚙️ Advanced Features:

### **Connect Device to Outlet Power:**

```gdscript
# In your device script (e.g., lamp, computer, etc.)
extends Node3D

@onready var outlet: OutletComponent = $NearbyOutlet

func _ready():
    if outlet:
        outlet.power_state_changed.connect(_on_power_changed)

func _on_power_changed(is_powered: bool):
    if is_powered:
        print("💡 Device powered on!")
        # Turn on lights, play sounds, etc.
    else:
        print("💡 Device powered off!")
        # Turn off lights
```

### **Find Nearest Outlet:**

```gdscript
func find_nearest_outlet() -> OutletComponent:
    var outlets = get_tree().get_nodes_in_group("outlets")
    var closest: OutletComponent = null
    var closest_dist = INF
    
    for outlet in outlets:
        if outlet is OutletComponent:
            var dist = global_position.distance_to(outlet.global_position)
            if dist < closest_dist:
                closest_dist = dist
                closest = outlet
    
    return closest
```

### **Lock an Outlet (Can't Unplug):**

```gdscript
# In a script
outlet.lock_outlet()  # Player can't unplug this

# Later...
outlet.unlock_outlet()  # Now they can
```

### **Check if Cord is Plugged:**

```gdscript
# Get reference to plug
var plug = $PowerCord/Segment_19/PowerCordPlugComponent

if plug.get_is_plugged():
    print("🔌 Cord is plugged into: " + plug.get_current_outlet().name)
else:
    print("🔌 Cord is unplugged")
```

---

## 🎨 Customization Tips:

### **Adjust Cord Physics Feel:**

**Stiffer Cord:**
- Lower `Joint Stiffness` (0.005)
- Higher `Angular Damping` (0.3)
- Higher `Cord Mass` (0.1)

**Looser/Floppy Cord:**
- Higher `Joint Stiffness` (0.02)
- Lower `Angular Damping` (0.1)
- Lower `Cord Mass` (0.03)

**Longer Cord:**
- Increase `Segment Count` (30-40)

**Thicker Cord:**
- Increase `Segment Radius` (0.03-0.05)

### **Visual Polish:**

1. **Create cord material:**
   - Black rubber material
   - Slight roughness/metallic

2. **Add plug model:**
   - Import .glb of electrical plug
   - Assign to `Plug Mesh` in builder

3. **Outlet plate:**
   - Model realistic outlet cover
   - Add glowing LED indicator

### **Audio Feedback:**

Assign sounds:
- `pickup_sound` - Grab plug
- `drop_sound` - Release plug  
- `plug_in_sound` - Satisfying click
- `plug_out_sound` - Unplug sound

---

## 🐛 Troubleshooting:

### **Cord segments fall through floor:**
- Set collision layers on segments: Layer 3, Mask 1+2+3
- Check floor has collision layer 2

### **Cord is too stiff/loose:**
- Adjust `Joint Stiffness` and `Angular Damping`
- Try different values until it feels right

### **Plug won't snap to outlet:**
- Check `snap_distance` on PowerCordPlugComponent (default 0.5)
- Ensure outlet is in "outlets" group (automatic)
- Check PlugSocketMarker position

### **Can't unplug:**
- Check OutletComponent → `Allow Unplug` is true
- Make sure outlet isn't locked

### **Cord explodes/goes crazy:**
- Lower `Joint Stiffness` (0.01 → 0.005)
- Increase `Linear/Angular Damping`
- Check segment mass isn't too high

---

## 📋 Quick Checklist:

**Power Cord:**
- [ ] Created scene with Node3D root
- [ ] Added PowerCordBuilder script
- [ ] Configured segment count and physics
- [ ] Toggled "Rebuild Cord"
- [ ] Positioned Anchor point
- [ ] Saved scene

**Outlet:**
- [ ] Created StaticBody3D scene
- [ ] Added collision shape
- [ ] Added outlet mesh/model
- [ ] Created PlugSocketMarker (Marker3D)
- [ ] Added OutletComponent script
- [ ] Assigned marker to component
- [ ] Saved scene

**Testing:**
- [ ] Instanced cord in world
- [ ] Instanced outlet in world
- [ ] Can pick up plug
- [ ] Cord drags with physics
- [ ] Can plug into outlet
- [ ] Can unplug from outlet
- [ ] Power state changes work

---

## 🎯 Example Use Cases:

1. **Lamp that needs power:**
   - Outlet on wall
   - Lamp has cord
   - Player plugs in → lamp turns on

2. **Computer setup:**
   - Multiple devices with cords
   - Limited outlets
   - Player must manage connections

3. **Puzzle:**
   - Power must reach specific device
   - Extension cords needed
   - Cord length limits placement

4. **Audio equipment:**
   - Boombox with power cord
   - Must be near outlet to play
   - Battery mode vs plugged mode

---

## 🚀 Next Steps:

1. **Create your first power cord**
2. **Create an outlet**
3. **Test the interaction**
4. **Add visual polish** (materials, models)
5. **Connect to devices** (lights, computers, etc.)
6. **Add sounds** for satisfying feedback

---

**Ready to plug in!** 🔌⚡

---

**Created:** November 1, 2025  
**Status:** Ready to use  
**Integration:** Fully compatible with existing CarryableComponent system
