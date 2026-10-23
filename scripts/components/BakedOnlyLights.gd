extends Node3D
## Holds lights whose light lives entirely in the lightmap (bake mode Static).
## Godot still processes Static lights every frame for things that aren't
## lightmapped, so they're hidden once the game runs: the baked light stays,
## the per-frame cost goes. The editor's bake still sees them.

func _ready() -> void:
	visible = false
