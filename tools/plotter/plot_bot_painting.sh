#!/usr/bin/env bash
# Has the bot plan a painting, then plots it on the real canvas.
#
#   tools/plotter/plot_bot_painting.sh /path/to/godot out_dir [seed] [style] [marker_mm]
#
# style: what the bot's painting style must start with ("studio", "layered",
# "meticulous", "aerial"); empty = whatever the bot picks.
# Writes out_dir/job.json (the stamps, in order), plotted.json (every stroke)
# painting.png and painting.svg (the painting as one vector file).
# Runs in a bare throwaway project: no game autoloads, so
# nothing touches the save or the marketplace.
set -euo pipefail
GODOT="$1"; OUT="$2"; SEED="${3:-1}"; STYLE="${4:-}"; MARKER="${5:-2}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts/autoplay" "$TMP/scripts/painting" "$TMP/tools"
cp -R "$REPO/scripts/plotter" "$TMP/scripts/"
cp "$REPO/scripts/autoplay/AutoplayPainter.gd" "$TMP/scripts/autoplay/"
cp "$REPO/scripts/painting/PaintingLayerDefinition.gd" "$TMP/scripts/painting/"
cp -R "$REPO/tools/plotter" "$TMP/tools/"
cat > "$TMP/project.godot" <<P
config_version=5

[application]
config/name="plot-bot-painting"
run/main_scene="res://tools/plotter/bot/plan_job.tscn"

[autoload]
StickerLibrary="*res://tools/plotter/bot/StickerLibraryStub.gd"
P
"$GODOT" --headless --editor --quit-after 100 --path "$TMP" >/dev/null 2>&1 || true
STICKER_REPO="$REPO" JOB_OUT="$OUT/job.json" JOB_SEED="$SEED" JOB_STYLE="$STYLE" \
	"$GODOT" --headless --path "$TMP" 2>&1 | grep -v "^Godot Engine\|^$" || true
STICKER_REPO="$REPO" "$GODOT" --headless --path "$TMP" -s res://tools/plotter/plot_job.gd -- "$OUT/job.json" "$OUT/plotted.json" "$MARKER" 60 "$OUT/painting.svg"
python3 "$REPO/tools/plotter/render_job.py" "$OUT/plotted.json" "$OUT/painting.png" 2
