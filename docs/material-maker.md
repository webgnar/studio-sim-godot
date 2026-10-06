# Material Maker in a cloud (headless) environment

How to make textures with [Material Maker](https://www.materialmaker.org/) 1.7 from a Linux
container with no screen, as was done for `materials/purple_carpet.tres`. Written for a Claude
Code session (or anyone) working in this repo.

## TL;DR

```bash
tools/material_maker/setup.sh                       # once per container: installs to ~/material_maker
tools/material_maker/export.sh my_graph.ptex /tmp/mm_out my_material
```

`export.sh` writes `my_material_albedo.png`, `_normal.png`, `_orm.png`, `_heightmap.png` and
`my_material.tres` into the output folder. Then bring them into the project as described below.

## What the environment needs

- **Network access** to `github.com` and `release-assets.githubusercontent.com` (the Material
  Maker download, ~95 MB) plus the default package-manager hosts for `apt-get`. If the download
  is refused, add those hosts under the environment's Network access settings
  (https://code.claude.com/docs/en/cloud-environments#network-access).
- **apt packages**: `xvfb xdotool x11-apps mesa-vulkan-drivers libvulkan1`. `setup.sh` installs
  them if they're missing.
- Optional: put `tools/material_maker/setup.sh` in the environment's **setup script** so every new
  session starts with Material Maker installed.

## How it works

1. **Write the material as a graph.** A `.ptex` file is plain JSON: a list of nodes and the
   connections between them. Easiest is to generate it with a small Python script; see
   `tools/material_maker/purple_carpet_graph.py` (rebuilds `materials/source/purple_carpet.ptex`).
   - Node types match the file names in `material_maker_1_7_linux/nodes/*.mmg` (419 of them,
     e.g. `pattern`, `fbm2`, `math`, `colorize`, `normal_map2`, `occlusion2`). Open an `.mmg` to see
     its parameter names and input/output ports.
   - Everything feeds a node of type `material`. Its input ports used so far: 0 albedo,
     2 roughness, 4 normal, 5 ambient occlusion, 6 depth/height.
2. **Export it.** Material Maker's command-line export crashes on the container's software Vulkan
   driver, so `export.sh` instead:
   - starts a virtual display (`Xvfb :77`, 1600x900) if one isn't running,
   - opens the GUI with the `.ptex` (`--rendering-method mobile`, Vulkan via lavapipe),
   - clicks **File → Export material → Godot → Godot 4 Standard** with `xdotool`, types the
     output folder and name into the save dialog, and waits for the files.

   The clicks are fixed screen coordinates for Material Maker 1.7 at 1600x900. If a different
   version moves the menus, run with `MM_SHOT=1` to save screenshots (`_shot_*.png` in the output
   folder) and adjust the coordinates in `export.sh`.
3. **Check it.** Look at the exported PNGs (they're ordinary images) before importing. For a
   look at the material itself, render a quick test scene with Godot (see below).

## Bringing it into the project

Follow the carpet's layout:

- Textures → `sprites/textures/<name>_albedo.png`, `_normal.png`, `_orm.png` (the heightmap is
  only needed for parallax).
- Material → `materials/<name>.tres`. Rather than keeping Material Maker's `.tres` as is, copy
  `materials/purple_carpet.tres` and point it at the new textures. The ORM texture holds
  AO in red, roughness in green and metallic in blue, so roughness uses
  `roughness_texture_channel = 1` and AO reads the same texture.
- Graph → `materials/source/<name>.ptex` (and the generator script, if you wrote one), so the
  material can be changed and re-exported later.
- Run a headless Godot import (`godot --headless --path . --import`) so the `.import` files are
  created, then `git checkout -- translations/` (the import rewrites the compiled translation
  files).

## Gotchas

- Don't stop Material Maker with `pkill -f material_maker...`: the pattern also matches your own
  shell's command line and kills it. Kill by PID (what `export.sh` does) or use a pattern like
  `pkill -f "[m]aterial_maker.x86_64"`.
- `xwd` screenshots from Xvfb are 24 bits per pixel, not 32; `xwd_to_png.py` handles both. Getting
  this wrong squashes the image and makes click coordinates look wrong.
- First launch takes ~30 s while shaders compile on the CPU, and the GUI runs at a few FPS. The
  waits in `export.sh` allow for that.
- The install lives outside the repo (`~/material_maker`, or the folder you pass to `setup.sh`;
  set `MM_DIR` to match when exporting). Never commit it.
