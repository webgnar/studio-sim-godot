#!/usr/bin/env bash
# Opens the paint-plotter simulator on a plotted job.
#
#   tools/plotter/run_simulator.sh /path/to/godot plotted.json [godot args...] [-- --speed=N --paused]
#
# plotted.json comes from tools/plotter/plot_bot_painting.sh. Runs in a bare
# throwaway project, so none of the game's autoloads start (no save, no
# marketplace). On a Mac the Godot binary is usually
# /Applications/Godot.app/Contents/MacOS/Godot
set -euo pipefail
GODOT="$1"; PLOT="$2"; shift 2
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts" "$TMP/scenes" "$TMP/job"
cp -R "$REPO/scripts/plotter" "$TMP/scripts/"
cp -R "$REPO/scenes/plotter" "$TMP/scenes/"
cp "$PLOT" "$TMP/job/plotted.json"
cat > "$TMP/project.godot" <<P
config_version=5

[application]
config/name="Paint plotter simulator"
run/main_scene="res://scenes/plotter/PlotterSim.tscn"

[display]
window/size/viewport_width=1600
window/size/viewport_height=900

[rendering]
renderer/rendering_method="gl_compatibility"
P
"$GODOT" --headless --editor --quit-after 100 --path "$TMP" >/dev/null 2>&1 || true
"$GODOT" --path "$TMP" "$@"
