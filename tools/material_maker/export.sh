#!/bin/bash
# Export a Material Maker graph (.ptex) as Godot 4 textures + a StandardMaterial3D .tres.
#   tools/material_maker/export.sh <graph.ptex> <output dir> <material name>
# Writes <name>_albedo.png, _normal.png, _orm.png, _heightmap.png and <name>.tres into <output dir>.
#
# Material Maker's command-line export crashes on software Vulkan, so this opens the GUI on a
# virtual display and clicks File > Export material > Godot > Godot 4 Standard with xdotool. The click
# coordinates assume Material Maker 1.7 in a 1600x900 window; if the save dialog never appears,
# take a screenshot (MM_SHOT=1) and adjust them.
set -e
[ $# -eq 3 ] || { echo "usage: $0 <graph.ptex> <output dir> <material name>"; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
PTEX="$(realpath "$1")"; OUT="$(realpath -m "$2")"; NAME="$3"
MM_DIR="${MM_DIR:-$HOME/material_maker}/material_maker_1_7_linux"
DISP="${MM_DISPLAY:-:77}"
[ -x "$MM_DIR/material_maker.x86_64" ] || { echo "Material Maker not found in $MM_DIR (run setup.sh)"; exit 1; }
mkdir -p "$OUT"

export DISPLAY=$DISP VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
if ! xdotool getdisplaygeometry >/dev/null 2>&1; then
	Xvfb "$DISP" -screen 0 1600x900x24 >/dev/null 2>&1 &
	sleep 2
fi

shot() { # MM_SHOT=1: save a PNG of the virtual screen for debugging clicks
	[ -n "$MM_SHOT" ] || return 0
	xwd -root -silent > /tmp/mm_shot.xwd && python3 "$HERE/xwd_to_png.py" /tmp/mm_shot.xwd "$OUT/_shot_$1.png"
}

cd "$MM_DIR"
./material_maker.x86_64 --audio-driver Dummy --rendering-method mobile "$PTEX" > "$OUT/_material_maker.log" 2>&1 &
MM_PID=$!
trap 'kill $MM_PID 2>/dev/null || true' EXIT
for i in $(seq 1 90); do xdotool search --name "Material Maker" >/dev/null 2>&1 && break; sleep 1; done
sleep 20 # let the graph load and compile its shaders
W=$(xdotool search --name "Material Maker" | head -1)
xdotool windowmove "$W" 0 0 windowsize "$W" 1600 900; sleep 8
shot 1_loaded

# File > Export material > Godot > Godot 4 Standard (hover through the submenus so they stay open)
xdotool mousemove 25 22 click 1; sleep 3
xdotool mousemove 85 264 click 1; sleep 3
for x in 200 300 400; do xdotool mousemove $x 264; sleep 0.7; done
xdotool mousemove 410 287; sleep 0.7; xdotool mousemove 410 310; sleep 3
for x in 500 600 660; do xdotool mousemove $x 310; sleep 0.7; done
xdotool mousemove 670 333; sleep 0.7; xdotool mousemove 680 356; sleep 1.5
shot 2_menu
xdotool click 1; sleep 5
if ! xdotool search --onlyvisible --name "Save a File" >/dev/null; then
	MM_SHOT=1 shot 3_no_dialog
	echo "Export dialog did not open; see $OUT/_shot_3_no_dialog.png"; exit 1
fi

# Save dialog: directory field, then file name, then Save.
xdotool mousemove 800 216 click 1; sleep 1; xdotool key ctrl+a; sleep 0.5
xdotool type --delay 40 "$OUT"; sleep 0.5; xdotool key Return; sleep 3
xdotool mousemove 760 640 click 1; sleep 1; xdotool key ctrl+a
xdotool type --delay 40 "$NAME"; sleep 1
xdotool mousemove 935 683 click 1

for i in $(seq 1 60); do
	sleep 5
	[ "$(ls "$OUT"/"$NAME"*.png 2>/dev/null | wc -l)" -ge 4 ] && [ -f "$OUT/$NAME.tres" ] && break
done
sleep 8 # last texture can still be flushing
ls -la "$OUT"
