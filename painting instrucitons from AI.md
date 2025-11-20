Guide for Building the Painting Layer System in Godot (Agent Specification)
1. Overview
Implement a system where a player in an FPS environment can construct images by stacking 2D painted layers on a 3D wall.
Phase 1: free-form sandbox for placing, ordering, rotating layers.
Phase 2: challenge mode where the system generates a target composition for the player to match.

Phase 1 — Free-Form Painting Simulator
2. Scene Structure
Create a node tree with the following structure:
PaintingRoot (Node3D)
    WallMesh (MeshInstance3D)        // static wall
    CanvasRoot (Node3D)              // all layers placed here



CanvasRoot must be positioned flush against the wall.


All layers are children of CanvasRoot.


Sorting is done logically, not by render order; the agent manages render priority via material render_priority.



3. Data Models
PaintingLayerDefinition
Represents one layer type from the library.


id: String


texture: Texture2D


Optional: metadata if needed later.


PlacedLayer
Instance created when the player places a layer.


id: String


node: Node3D (Sprite3D or QuadMesh + material)


order: int (lower = back, higher = front)


rotation_deg: float around wall normal



4. Spawn Logic
When the player selects a layer and raycasts onto the wall:


Convert raycast hit position to CanvasRoot local space.


Create a new PlacedLayer.


Instantiate:


A Sprite3D or QuadMesh with an unshaded material.


Use alpha-blend.




Parent it to CanvasRoot.


Assign:


order = next available integer


rotation_deg = 0




Assign material.render_priority = order.



5. Interaction Mechanics
5.1 Ordering
Implement:


raise_order(layer_id)


lower_order(layer_id)


Changing order requires:


Update the order field.


Update material.render_priority.


Ensure no two layers share the same order (reindex if necessary).


5.2 Rotation
Rotation is always around the wall’s normal (the axis normal of CanvasRoot).
Implementation:
layer_node.rotate_object_local(normal, radians)

Keep this mechanic simple:


Only rotate around one axis.


Rotation stored in rotation_deg.


5.3 Position (Phase 1 partial)
Basic dragging allowed, no clipping yet.


Raycast → convert screen drag to movement along the canvas plane.


Update node.translation (local to CanvasRoot).


No trimming or masking yet.

Phase 2 — Challenge / Matching Mode
6. Target Painting Generation
6.1 TargetPainting


layers: Array[PaintingLayerDefinition]


Ordered by the intended correct z_index


Agent must generate a random subset, fixed order.


6.2 Display
Show a preview of the target painting (a simple SubViewport render of layered textures in 2D).

7. Validation Logic
Given:


player_layers: Array[PlacedLayer]


target_layers: Array[PaintingLayerDefinition]


Validation rules:


Same number of layers.


Sort player_layers by order.


For index i:


player_layers[i].id == target_layers[i].id




Rotation optionally ignored for now.


Position optionally ignored for now.


Return boolean.
Pseudocode:
func verify(player_layers, target_layers):
    if player_layers.size() != target_layers.size():
        return false
    var sorted = player_layers.sorted(func(a,b): return a.order < b.order)
    for i in target_layers.size():
        if sorted[i].id != target_layers[i].id:
            return false
    return true


Clipping / Masking (to be added after Phase 1)
8. Canvas Masking (Rectangle)
All layers must be confined to a rectangular area later.
Two supported methods:
8.1 Shader Mask (Recommended)
Place a single quad representing the canvas.
Apply a masking shader to all layers:


Input UVs of each layer.


Discard pixels outside [0,1] in each axis.


For rectangles, scale UVs accordingly.


8.2 SubViewport-based Clipping


Render all layers into a SubViewport sized to canvas resolution.


Present that viewport on the wall as a texture.


Automatically clipped.


The agent may choose either method.

9. Technical Requirements


Use unshaded materials for layers.


All layers must maintain consistent pixel density.


Avoid using 3D lighting on layers.


All logic implemented in a dedicated script PaintingSystem.gd.



10. Deliverables for the Agent
The agent must produce:


Scene tree and setup scripts.


Data models (layer definitions, placed layers).


Functions:


spawn layer


raise/lower order


rotate layer


move layer


verify target match




Input handling hooks for FPS controller.


Optional: masking implementation chosen from section 8.


Simple UI for selecting layers and viewing the target painting (Phase 2).



If you want, I can produce an even more strict version (a fully enumerated requirements spec) or convert this into a file-tree + script-stub layout for the agent.