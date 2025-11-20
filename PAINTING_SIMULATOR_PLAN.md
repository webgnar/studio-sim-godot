# Painting Simulator System Plan for Godot

## 1. Overview
**Core Gameplay:** A painting puzzle game where players recreate target images by placing, ordering, and positioning sticker layers on a canvas wall.

- **Phase 1:** Basic mechanics - spawn stickers, move them around canvas surface, adjust z-ordering, rotate.
- **Phase 2:** Challenge mode - procedurally generated target paintings that players must match.
- **Phase 3 (Future):** Advanced validation with position/rotation accuracy.

**Design Philosophy:** Keep it simple, one step at a time. Build foundation first, add complexity later.

---

## 2. Scene Structure
- **PaintingRoot** (`Node3D`)
  - **WallMesh** (`MeshInstance3D`): static wall
  - **CanvasRoot** (`Node3D`): all layers placed here

- `CanvasRoot` must be positioned flush against the wall.
- All layers are children of `CanvasRoot`.
- Sorting is logical, not by render order; agent manages render priority via `material.render_priority`.

---

## 3. Data Models
- **PaintingLayerDefinition** (Sticker Library Entry)
  - `id: String`
  - `texture: Texture2D`
  - `unlock_cost: int` (price to unlock this sticker)
  - `unlocked: bool` (player has purchased/unlocked)
  - `rarity: String` (optional: common/rare/epic for progression)
  - Optional: metadata

- **PlacedLayer** (Instance on Canvas)
  - `id: String`
  - `node: Node3D` (Sprite3D or QuadMesh + material)
  - `order: int` (lower = back, higher = front)
  - `rotation_deg: float` (around wall normal)

- **PaintingMission**
  - `mission_id: String`
  - `target_layers: Array[PaintingLayerDefinition]` (ordered)
  - `reward: int` (money earned on completion)
  - `required_stickers: Array[String]` (IDs of stickers needed)
  - `difficulty: int` (optional tier/difficulty rating)

---

## 4. Spawn Logic
- On player selecting a layer and raycasting onto the wall:
  - Convert raycast hit position to `CanvasRoot` local space.
  - Create a new `PlacedLayer`.
  - Instantiate a `Sprite3D` or `QuadMesh` with unshaded, alpha-blend material.
  - Parent to `CanvasRoot`.
  - Assign `order` (next available integer), `rotation_deg = 0`.
  - Set `material.render_priority = order`.

---

## 5. Interaction Mechanics
### 5.1 Ordering
- `raise_order(layer_id)` / `lower_order(layer_id)`
- Update `order` and `material.render_priority`.
- Ensure unique order (reindex if needed).

### 5.2 Rotation
- Rotate around wall’s normal (CanvasRoot axis).
- Store in `rotation_deg`.
- Use `layer_node.rotate_object_local(normal, radians)`.

### 5.3 Position
- Allow dragging sticker face around on canvas surface.
- Raycast → convert mouse movement to position along canvas plane.
- Update `node.translation` (local to CanvasRoot).
- Keep sticker flush against wall while moving across surface.

---

## 6. Phase 2 — Challenge / Matching Mode
### 6.1 Target Painting Generation (FLEXIBLE)
- **TargetPainting**: `layers: Array[PaintingLayerDefinition]` (ordered by correct z_index)
- **Two approaches supported (TBD):**
  - **Option A - Procedural:** System randomly generates compositions from available stickers
  - **Option B - Hand-Crafted:** Pre-designed paintings stored as data/resources
- System should support both approaches interchangeably
- Store targets as simple data structure (easy to swap between procedural/manual)

### 6.2 Display
- Show preview of target painting via SubViewport render
- Display on in-game computer monitor (Missions UI)
- Side-by-side comparison view optional

---

## 7. Validation Logic
- Compare player's sticker arrangement to procedurally generated target.
- Given `player_layers: Array[PlacedLayer]`, `target_layers: Array[PaintingLayerDefinition]`
- Validation rules (Phase 1 - Simple):
  - Same number of layers
  - Sort `player_layers` by order
  - For each index: `player_layers[i].id == target_layers[i].id`
  - Ignore rotation/position initially.
- Return boolean (success/failure).

```gdscript
func verify(player_layers, target_layers):
    if player_layers.size() != target_layers.size():
        return false
    var sorted = player_layers.sorted(func(a,b): return a.order < b.order)
    for i in target_layers.size():
        if sorted[i].id != target_layers[i].id:
            return false
    return true
```

### 7.1 Future-Proofing for Advanced Comparison
- **Phase 2 (Future):** Add position/rotation tolerance checks
  - Position threshold (e.g., within 0.5 units of target position)
  - Rotation threshold (e.g., within 15 degrees of target rotation)
- **Phase 3 (Future):** Partial scoring system
  - Calculate percentage match
  - Score based on correct layers, order, position, rotation
  - Provide feedback on what's wrong

---

## 8. Clipping / Masking (Post-Phase 1)
- All layers must be confined to a rectangular area.
- **Shader Mask (Recommended):**
  - Single quad for canvas, masking shader for all layers.
  - Discard pixels outside [0,1] in UV.
- **SubViewport-based Clipping:**
  - Render all layers into SubViewport, present on wall as texture.

---

## 9. Technical Requirements
- Use unshaded materials for layers.
- Maintain consistent pixel density.
- Avoid 3D lighting on layers.
- All logic in `PaintingSystem.gd`.

---

## 10. Development Roadmap

### Phase 1 - Core Mechanics (MVP)
1. **Scene Setup**
   - PaintingRoot with WallMesh and CanvasRoot
   - Basic camera/player positioning
2. **Sticker Spawning**
   - Click on wall to place sticker at raycast hit point
   - Load texture as Sprite3D with alpha blend
3. **Movement**
   - Drag sticker around on canvas surface
   - Maintain position flush against wall
4. **Z-Ordering**
   - Raise/lower layer order with keyboard shortcuts
   - Visual feedback for layer priority
5. **Rotation**
   - Rotate sticker around wall normal axis
   - Smooth rotation with mouse or keyboard

### Phase 2 - Mission System & Progression
1. **Missions UI (Computer in Room)**
   - Interactable computer in game world
   - Display available painting missions
   - Show target painting preview
   - Accept/decline missions

2. **Target Generation (FLEXIBLE)**
   - **System supports both:**
     - Procedural: Random compositions from sticker pool
     - Manual: Pre-designed painting data
   - Easy toggle between approaches
   - Store missions as simple data structure

3. **Sticker Unlock System**
   - Players start with basic sticker set
   - Earn money by completing painting missions
   - Spend money to unlock new stickers
   - More expensive paintings require rare/expensive stickers
   - Shop/unlock UI (can be part of computer interface)

4. **Validation System**
   - Check if player arrangement matches target (z-order only initially)
   - Success: Award money reward
   - Failure: Allow retry or cancel mission

5. **Progression Loop**
   - Complete mission → Earn money → Unlock stickers → Access harder missions → Repeat

### Phase 3 - Future Enhancements
- Position/rotation accuracy validation
- Scoring system with percentage match (bonus rewards for accuracy)
- Time-based challenges (speed bonuses)
- Combo system (complete multiple missions in a row)
- Prestige/reputation system
- Special commissioned paintings with story elements
- Sticker rarity tiers (common/rare/epic/legendary)
- Trading/collection mechanics
- Achievement system

## 11. Technical Requirements
- Use unshaded materials for layers (no 3D lighting)
- Maintain consistent pixel density across stickers
- All logic in dedicated `PaintingSystem.gd` script
- Input handling separate from FPS controller (can be toggled)
- Performance: Support 10-20 layers minimum without lag
- **Save System:**
  - Track unlocked stickers
  - Save player money/currency
  - Save mission completion history
  - Persist current canvas state (if mid-mission)

## 12. Game Progression Architecture
### Economy System
- **Currency:** Money earned from completed paintings
- **Pricing:** Sticker unlock costs scale with rarity/power
- **Mission Rewards:** Higher difficulty = higher payout
- **Balance:** Ensure player can always progress (never softlocked)

### Mission Generation System (Flexible Design)
```gdscript
# Support both approaches with same interface
class_name MissionGenerator

# Option A: Procedural
func generate_procedural_mission(difficulty: int, available_stickers: Array) -> PaintingMission:
    # Generate random composition
    pass

# Option B: Load pre-made
func load_handcrafted_mission(mission_id: String) -> PaintingMission:
    # Load from JSON/resource file
    pass

# Both return same PaintingMission object
```

### Unlock Progression
- Start with 5-10 basic stickers (free)
- Tier 1 missions use only starter stickers
- Unlock new stickers to access Tier 2+ missions
- Each tier introduces new sticker types
- Exponential pricing curve prevents rushing content

---

*This plan reflects the core gameplay vision: a simple, focused painting puzzle game built incrementally with future-proofing for complexity.*
