# Baked lighting (world.tscn)

The building's walls, floors and ceilings get their bounce light from a
`LightmapGI` bake (`scenes/world.lmbake` + `scenes/world.exr`). The sun,
moon fill light and everything that moves stay real time.

## What is baked

- **CSG shells.** CSG can't be lightmapped, so each static CSG shell has a
  `<name> (baked)` MeshInstance3D twin next to it with a UV2 mesh from
  `scenes/world_lightmap/`. The CSG nodes are still there for collision and
  navmesh, drawn on render layer 0 (invisible, no shadow).
- **Lights.** Lamps (gallery spots, fluorescents) use the default
  bake mode Dynamic: their bounce is baked, their direct light and shadows
  stay live. The sun (`DayNightCycle/.../DirectionalLight3D2`), the fill/moon
  `DirectionalLight3D`, the DanceParty rig and the Lou Gnar screen glow are
  bake **Disabled** because they move, change color or switch off.
- **Skylight.** `LightmapGI.environment_mode` is Custom Color (a neutral
  warm grey), not the sky: the sky changes through the day, and its blue
  would come back into every room.

## Environment (`materials/world_environ.tres`)

Ambient is a neutral Color (not the sky) and sky reflections are off: the
sky shader paints the whole sphere with the blue cloud image, which tinted
every surface blue. Tonemap is AgX; SSAO gives moving things contact shadows.

## After editing walls or moving lights

1. If you changed a baked CSG shell:
   `godot --path . --script res://tools/bake_csg_shells.gd`
2. New shell: add it to the lists in `tools/bake_csg_shells.gd` and
   `tools/add_lightmap_shells.py`, run both (the python one from the repo root).
3. Open `world.tscn`, select `LightmapGI`, press **Bake Lightmaps** (~2 min).
4. Commit `world.lmbake`, `world.exr` and `world.exr.import` (the import
   file is un-ignored on purpose: without it the lightmap loads as a flat
   image and the level renders fully bright).

Until a re-bake, a moved wall keeps its old light.
