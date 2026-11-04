# Paint-plotter simulator

A simulator for a hanging two-cord plotter (polargraph) that paints the game's
vector art on a 6 × 4 ft canvas. The math lives in plain GDScript classes with
no node dependencies, so the same code can later drive G-code for the real
machine.

All coordinates are canvas millimetres, origin at the canvas's top-left, +y down.

## Classes (scripts/plotter/)

- `Polargraph`: machine geometry and kinematics. `xy_to_lengths`, `lengths_to_xy`,
  `cord_angle`, `quality` (1 at 90°, 0 at/after 20° and 160°), `quality_grid` for
  shading, and step conversion (GT2 pulley or spool).
- `StickerVectorizer`: sticker PNG → colour layers of polygons, plus hatching/outline strokes for a given tool width (see below).
- `PathPlanner`: polylines in, moves out: `{x, y, tool_down, feed, flagged}`.
  Cleans, clips to the canvas, splits at the low-quality boundary (skip / flag /
  keep), merges endpoints within `merge_distance`, and orders strokes greedily by
  nearest neighbour. `report` has counts and lengths after each `plan()`.

With the default machine (motors 2440 mm apart, 450 mm above the canvas) the
cord angle over the whole canvas runs from 62° (bottom corners) to 139.5° (top
centre), so nothing is out of band.

## Tests

    tools/plotter/run_tests.sh /path/to/godot

Runs `tests/plotter/PlotterTests.tscn` in a bare temporary project. Don't run
that scene from the editor: the game's autoloads would start, and the sticker
marketplace claims pending sale credits on startup.

## Sticker vectors (scripts/plotter/StickerVectorizer.gd)

The game's stickers are PNGs, so before anything can be plotted each one is
turned into flat colour regions:

1. shrink to `detail` px (600) with premultiplied alpha, so edges don't pick up
   a dark or light rim
2. k-means up to `max_colors` (24), then merge colours closer than
   `merge_tolerance` (0.07), so brush texture stays one paint colour
3. majority-filter speckle (`smooth_passes`), and fold patches smaller than
   `min_region` into the neighbour they touch most (no gaps)
4. trace each colour along pixel edges (outer rings positive area, holes
   negative), simplify (`simplify` px) and round off (`smooth_outline`)

`paint_strokes(polygons, tool_width)` turns a placed layer into strokes: each
region is shrunk by half the tool width, outlined and hatched, and parts too
thin for the tool are painted along their own long axis.

Tuning contact sheet (original | traced | painted):

    tools/plotter/preview_stickers.sh /path/to/godot out.png 1,2,3 5 detail=600 merge_tolerance=0.07
