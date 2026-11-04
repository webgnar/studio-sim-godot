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
