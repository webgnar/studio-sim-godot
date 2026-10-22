# Baked lighting (world.tscn)

The building's walls, floors and ceilings get their bounce light from a
`LightmapGI` bake (`scenes/world.lmbake` + `scenes/world.exr`). The sun,
moon fill light and everything that moves stay real time.

## What is baked

- **CSG shells.** CSG can't be lightmapped, so each static CSG shell has a
  `<name> (baked)` MeshInstance3D twin next to it with a UV2 mesh from
  `scenes/world_lightmap/`. The CSG nodes are still there for collision and
  navmesh, drawn on render layer 0 (invisible, no shadow).
- **Lights.** Always-on lamps (gallery spots) use the default bake mode
  Dynamic: their bounce is baked, their direct light and shadows stay live.
  Fluorescent and Spotlight fixtures are bake **Disabled** because the wall
  switches toggle them; each Fluorescent has a live `BounceFill` light and
  glowing tubes that follow its SpotLight3D (`FluorescentFixture.gd`). The sun (`DayNightCycle/.../DirectionalLight3D2`), the fill/moon
  `DirectionalLight3D`, the DanceParty rig and the Lou Gnar screen glow are
  also bake **Disabled** because they move or change color. Any new light a
  switch or script turns off must be bake Disabled too, or its bounce stays.
- **No skylight in the bake.** `LightmapGI.environment_mode` is Disabled, so
  the bake holds only the lamps: at night rooms are lit by their fixtures
  and windows go dark, like the real studio. Daylight indoors comes from the
  live fill `DirectionalLight3D`, which `DayNightCycle` fades between
  `fill_energy_day` and `fill_energy_night`.
- **Reflection probes** (`ReflectionProbes`, one box per room) replace sky
  reflections. Refit them if room walls move.

## Environment (`materials/world_environ.tres`)

Ambient is a neutral Color (not the sky) and sky reflections are off: the
sky shader paints the whole sphere with the blue cloud image, which tinted
every surface blue. Tonemap is AgX; SSAO gives moving things contact shadows. Debanding is on in
project settings so smooth light falloff on white walls doesn't band.

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
