---
name: "godot-baked-lighting"
description: "Bake a Godot 4 level's lighting with LightmapGI (walls and furniture baked, lamps and moving things live), tune it, and compare before/after renders. Use when asked to bake lighting, turn off GI or reflections, or set furniture to static."
---

# Baked lighting in Godot 4 (LightmapGI)

Works in any Godot 4.x project (written against 4.7, Forward+). The goal:
the light bouncing around a room (walls, ceilings, furniture, daylight from
windows) is worked out once and stored in a lightmap, so rooms get soft
shading in corners and under furniture, cheaply. Lamps stay live so
characters and props still cast moving shadows.

## 0. Look first: what "GI" is the level using?

Read the level's `WorldEnvironment` resource and grep the scene:
- `sdfgi_enabled`, `ssr_enabled`, `ssil_enabled`, VoxelGI nodes: the heavy live GI.
  Turn these off for interiors you bake.
- `ambient_light_source = 2/3` (sky/color) and `reflected_light_source = 2`
  (sky): the cheap "GI". A sky ambient lights every indoor surface evenly
  (flat, often blue) and sky reflections put the sky on every shiny surface
  indoors. Baked surfaces ignore the environment ambient, so the ambient can
  stay for outdoors and anything outside the bake; set
  `reflected_light_source = 1` (disabled) and use reflection probes instead
  (step 5).

Tell the user plainly which of these the level actually has before changing
anything. Try it on a copy first: an **inherited scene** of the level
(`[node name="Root" instance=ExtResource("level")]` plus overrides) changes
nothing in the real level and is easy to throw away.

## 1. Every static mesh needs a second UV set (UV2)

LightmapGI only bakes `GeometryInstance3D`s with `gi_mode = Static` (the
default for MeshInstance3D) **and** UV2. Anything without UV2 is skipped
silently and lit by the lightmap's probes instead (fine for moving things,
poor for walls and furniture).

- **CSG (CSGCombiner3D etc.):** can't be baked at all. Turn it into a mesh in a
  `extends SceneTree` script: `var mesh := csg.bake_static_mesh()`,
  `mesh.lightmap_unwrap(Transform3D.IDENTITY, 0.08)` (texel size in meters;
  pass IDENTITY, the mesh is already in the CSG's local space), save it with
  `ResourceSaver.save(mesh, "res://.../shell.res")`. In the level hide the CSG
  (`visible = false`: hidden CSG keeps its collision) and add a MeshInstance3D
  with the saved mesh beside it. Re-run after editing the CSG. Run the import
  (`godot --headless --import`) first, or the CSG's materials come out null.
- **Primitive meshes** (BoxMesh, PlaneMesh...): `add_uv2 = true` on the mesh.
- **Imported models (.glb/.gltf/.fbx):** import option Meshes > Light Baking =
  Static Lightmaps (`meshes/light_baking=2` in the `.import`) and Lightmap
  Texel Size 0.1 for furniture. That setting lives only in the `.import`
  file: if the project ignores `*.import` in git, add `!path/model.glb.import`
  exceptions for those files and commit them, or a fresh clone loses it.
  A small script that finds every model a level places and sets this (and the
  gitignore line) makes adding furniture one step.
- **Leave dynamic:** anything that moves, is picked up, animated or swapped
  at runtime (guns, characters, pickups). They're lit by the lightmap's probes.

## 2. Lights: pick a bake mode per light

`light_bake_mode` on each Light3D (0 Disabled, 1 Static, 2 Dynamic; default 2):
- **Dynamic (default, recommended):** the bake stores the light's bounce;
  its direct light and shadows stay real time, so moving things still cast
  shadows. Use for room lamps.
- **Static:** fully baked (cheapest, softest shadows), but nothing that moves
  casts a shadow from it. Use for lights nobody walks under.
- **Disabled:** not in the bake at all. **Use for every light that switches
  on/off or changes at runtime**, or its baked bounce stays lit when it's off.
  A switched light's room then gets no bounce: add a few shadowless live
  OmniLight3D fills (bake Disabled) just under the ceiling that switch with it.
- `light_indirect_energy` per light raises its bounce (e.g. 2.0 for a tall
  room with high lamps).

## 3. The LightmapGI node

Add one `LightmapGI` at the level root (it bakes the meshes under its parent).
Settings that matter: `quality` (2 = High for the final), `bounces` (3),
`bounce_indirect_energy` (start at 0.75: 1.0 tends to wash out white walls,
0.6 leaves ceilings over downward lamps too dark), `environment_mode`
(Scene: daylight from the sky comes in through openings), `texel_scale`,
`use_denoiser` on. Emissive static meshes (light panels) add light too if they
have UV2.

## 4. Bake (editor only)

There's no bake call for scripts: select LightmapGI, press **Bake Lightmaps**
in the 3D toolbar. The first bake of a scene asks where to save the
`.lmbake` (save next to the scene). Needs a real GPU (Vulkan or Metal);
it won't run headless or on a GPU-less cloud box. Typical: 30 s for walls
only, ~2 min with ~60 furniture models, lightmap a few MB to ~20 MB.

To bake without clicking (remote runs), a temporary EditorPlugin can press
the button. Copy into `res://addons/autobake/autobake_plugin.gd` with a
`plugin.cfg` (`script="autobake_plugin.gd"`), enable it in project.godot,
run `godot -e --path . <scene> -- --autobake <scene>`, then remove the
plugin and revert project.godot:

```gdscript
@tool
extends EditorPlugin

func _enter_tree() -> void:
	if "--autobake" in OS.get_cmdline_user_args():
		_bake.call_deferred()

func _bake() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[args.find("--autobake") + 1]
	await get_tree().create_timer(15.0).timeout
	EditorInterface.open_scene_from_path(scene)
	await get_tree().create_timer(15.0).timeout
	var lightmap := EditorInterface.get_edited_scene_root().find_child("LightmapGI", true, false) as LightmapGI
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(lightmap)
	EditorInterface.edit_node(lightmap)
	await get_tree().create_timer(2.0).timeout
	for b in EditorInterface.get_base_control().find_children("*", "Button", true, false):
		if (b as Button).text == "Bake Lightmaps":
			(b as Button).pressed.emit()
	await get_tree().create_timer(1.0).timeout
	# First bake: answer the "where to save" dialog
	for d in EditorInterface.get_base_control().get_window().find_children("*", "EditorFileDialog", true, false):
		if (d as EditorFileDialog).visible:
			(d as EditorFileDialog).hide()
			d.file_selected.emit(scene.get_basename() + ".lmbake")
	while lightmap.light_data == null:
		await get_tree().create_timer(1.0).timeout
	EditorInterface.save_scene()
	print("AUTOBAKE: OK")
	get_tree().quit()
```

The editor may re-save unrelated resources (materials, themes) while open:
revert those before committing. If the project doesn't commit `.import`
files, the editor's re-save of the scene also rewrites texture UIDs and
reorders nodes: keep the original scene and add only the two lightmap lines
(the `LightmapGIData` ext_resource and `light_data` on LightmapGI); later
re-bakes don't touch the scene at all. Commit the `.lmbake` and its `.exr`.

## 5. Reflections and contact shadows

- **Reflection probes:** with sky reflections off, metal and dark glossy
  paint go black. Add one `ReflectionProbe` per room: sized to the room's
  walls, `interior = true`, `box_projection = true`, `ambient_mode = 0`
  (the lightmap handles ambient), update mode Once. Make each box reach a
  little past the walls so doors in them are inside. Refit them when walls move.
- **AO:** LightmapGI has no separate AO pass; the bounce darkens corners and
  under baked furniture by itself. For things that move (characters, props),
  turn on **SSAO** in the Environment (`ssao_enabled = true`): contact shadows
  for what the bake can't see, at a small GPU cost. AO baked into a model's
  own material in Blender only helps its own creases.

## 6. Compare and tune

Put named `Marker3D`s (e.g. under a `LightingShots` node) at a few camera
angles per room, and render each from a windowed run (Forward+ needs a GPU;
headless renders nothing) with a small `extends SceneTree` script: load the
scene, remove the player, hide CanvasLayers and Label3Ds, add a Camera3D, move
it to each marker, wait ~30 frames, `root.get_texture().get_image().save_png()`.
Render the same markers before and after, put them side by side, and look.
Check marker positions against the walls first (print the CSG boxes' global
AABBs): a camera behind a wall wastes a render.

Tuning by symptom:
- White walls washing out: lower `bounce_indirect_energy`, or the
  Environment's `tonemap_exposure` (0.9).
- Ceilings black over downward lamps: raise `bounce_indirect_energy`.
- A tall room dim: raise its lights' `light_indirect_energy`.
- Metal/dark pieces flat black: reflection probe missing or not covering
  them; or the material is just near-black (fix the albedo).
- Furniture floating: it's not in the bake (no UV2 or gi_mode not Static).
- A light switch no longer darkens a room: that light isn't bake Disabled.

## 7. Living with it

- Moving or adding furniture, or editing walls, needs a re-bake. Until then
  a moved piece keeps its old light and leaves its old shadow, so it's easy
  to spot. Walls from CSG need the mesh step (step 1) first.
- When merging other people's level changes into a baked branch, check for
  moved walls and new models: rebuild the CSG meshes, refit the probes, set
  new models to bake, then re-bake.
- Write the light bake modes and the CSG-to-mesh step into the project's
  docs, so whoever edits the level knows to re-bake.