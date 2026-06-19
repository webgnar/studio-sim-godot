# Godot Development Rules

## Node-First Philosophy
- ALWAYS prefer built-in Godot nodes over custom code
- Before writing any GDScript, ask: "is there a node that does this?"
- Use AnimationPlayer over tweening in code
- Use Area2D/CollisionShape2D for triggers, not manual position checks
- Use Timer nodes, not `await get_tree().create_timer()`
- Use StateMachine / AnimationTree for complex state, not if/else chains
- Use NavigationAgent2D for pathfinding, not custom logic

## Visual Positioning
- NEVER hardcode visual positions in scripts
- Set positions, sizes, and layout in the editor/scene file
- Anything the user might want to tweak visually belongs in the editor

## Editor-Owned Properties
- Labels and icons on SellButton and StoreButton must be set in the editor, never overwritten by @export setters or _ready() code

## When Code IS Appropriate
- Connecting signals between nodes
- Lightweight logic that has no node equivalent
- Game-specific calculations (damage formulas, score math, etc.)

## Running the Project
- NEVER try to launch or run the project (no searching for/running Godot binaries, no `/run` skill, etc.)
- The user runs and tests the game manually in the Godot editor
