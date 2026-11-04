#!/usr/bin/env bash
# Runs the plotter unit tests in a bare throwaway project, so none of the
# game's autoloads start (the sticker marketplace would claim sale credits).
#
#   tools/plotter/run_tests.sh [path/to/godot]
#
# Exit code 0 = all tests passed.
set -euo pipefail
GODOT="${1:-${GODOT:-godot}}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts" "$TMP/tests"
cp -R "$REPO/scripts/plotter" "$TMP/scripts/"
cp -R "$REPO/tests/plotter" "$TMP/tests/"
cat > "$TMP/project.godot" <<'PROJ'
config_version=5

[application]
config/name="plotter-tests"
run/main_scene="res://tests/plotter/PlotterTests.tscn"
PROJ
# Build the class_name cache, then run
"$GODOT" --headless --editor --quit-after 100 --path "$TMP" >/dev/null 2>&1 || true
"$GODOT" --headless --path "$TMP" res://tests/plotter/PlotterTests.tscn
