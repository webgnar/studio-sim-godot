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
3. merge close shades that are mingled (brush texture, blended edges:
   `mingle_tolerance`, `mingle_contact`), except colours laid down as straight
   stripes (`stripe_share`, `stripe_elongation`), which always stay
4. majority-filter speckle (`smooth_passes`), and fold patches smaller than
   `min_region` into the neighbour they touch most (no gaps)
5. trace each colour along pixel edges (outer rings positive area, holes
   negative), simplify (`simplify` px) and round off (`smooth_outline`)

Hue guard: shades of clearly different hue (`hue_guard_degrees`,
`hue_guard_saturation`) never merge, so greens and reds can't sink into a grey.

Per-sticker settings live in `resources/plotter/sticker_vector_settings.json`:
named presets (`soft` squints at painterly/photographic stickers with
`squint_mix` and `saturation_boost`; `rich` keeps close shades apart in busy
line work) and a sticker id → preset (or its own settings) map.

`paint_strokes(polygons, tool_width)` turns a placed layer into strokes: each
region is shrunk by half the tool width, outlined and hatched, and parts too
thin for the tool are painted along their own long axis.

Tuning contact sheet (original | traced | painted):

    tools/plotter/preview_stickers.sh /path/to/godot out.png 1,2,3 5 detail=600 merge_tolerance=0.07

## Plotting a whole bot painting

`tools/plotter/plot_bot_painting.sh /path/to/godot out_dir [seed] [style] [marker_mm]`

1. `tools/plotter/bot/plan_job.tscn` has AutoplayPainter plan a painting
   (style must start with `style`, e.g. `studio`), plays out every stroke
   with its mistakes, fixes, impulses and final looks, and saves what ends up
   on the canvas, back to front, as `job.json` (sticker id, centre mm,
   rotation, longest side mm). Runs in a bare project with a stub
   StickerLibrary that reads the PNGs directly: no game autoloads.
2. `tools/plotter/plot_job.gd` vectorizes each sticker once, places every
   stamp, paints its colours light to dark with `paint_strokes`, plans each
   colour with PathPlanner and times it with `MotionEstimator`
   (trapezoidal speed, corner slow-down, pen lift/drop time). Writes
   `plotted.json` (every stroke, in order) and prints the job's numbers.
3. With a 5th arg, `plot_job.gd` also writes the painting as one SVG
   (`SvgExporter`): filled colour shapes in canvas mm, one group per
   sticker, back to front, clipped to the canvas; plus `<name>_toolpaths.svg`
   with the machine's strokes as a hidden layer. Hatching is joined into
   zig-zags wherever the step between rows stays inside the shape.
4. `tools/plotter/render_job.py` draws the strokes at the marker's width;
   `tools/plotter/render_stamps.py job.json out.png` composites the sticker
   PNGs for comparison.

## Simulator: watch a job paint

`tools/plotter/run_simulator.sh /path/to/godot out_dir/plotted.json [godot args] [-- --speed=N --paused]`

Opens `scenes/plotter/PlotterSim.tscn` in a bare throwaway project (no game
autoloads). Shows the beam, motors, both cords and the gondola over the
canvas; paint goes down stroke by stroke in machine time.

- `PlotPlayer` (pure) turns a plotted job into timed moves (MotionEstimator,
  pen lifts/drops, `colour_change_s` per colour change) and hands out the ink
  laid since the last frame.
- `StrokeRenderer` is a SubViewport that's never cleared, so each frame only
  draws new ink at the marker's width.
- Panel: machine time and percent done, sticker n of N, paint layer, colour
  changes, pen lifts + drops, ink laid. Speed 1× (real time) to 100000×.
- Keys: space play/pause, up/down speed ×2, R restart, S save the canvas.
- Timelapse: add `--write-movie out.avi --fixed-fps 30` before `--`, and
  `--quit-when-done` after it.
- On a Mac the Godot binary is `/Applications/Godot.app/Contents/MacOS/Godot`.
