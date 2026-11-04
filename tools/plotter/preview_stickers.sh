#!/usr/bin/env bash
# Vectorizes stickers and draws an original | traced | painted contact sheet.
#
#   tools/plotter/preview_stickers.sh /path/to/godot out.png 1,2,3 5 [detail=600 ...]
#
# Runs in a bare throwaway project (no game autoloads). Needs python3 + Pillow.
set -euo pipefail
GODOT="$1"; OUT="$2"; IDS="$3"; MARKER="$4"; shift 4
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts" "$TMP/tools"
cp -R "$REPO/scripts/plotter" "$TMP/scripts/"
cp -R "$REPO/tools/plotter" "$TMP/tools/"
printf 'config_version=5\n\n[application]\nconfig/name="sticker-preview"\n' > "$TMP/project.godot"
"$GODOT" --headless --editor --quit-after 100 --path "$TMP" >/dev/null 2>&1 || true
STICKER_REPO="$REPO" "$GODOT" --headless --path "$TMP" -s res://tools/plotter/vectorize_stickers.gd -- "$TMP/out.json" "$IDS" "$MARKER" "$@"
STICKER_REPO="$REPO" python3 "$REPO/tools/plotter/sticker_preview.py" "$TMP/out.json" "$OUT" "Stickers $IDS, ${MARKER} mm marker $*" "$MARKER"
