#!/bin/bash
# Install Material Maker 1.7 plus what it needs to run headless in a Linux container
# (virtual X display, software Vulkan, GUI automation). Safe to re-run.
#   tools/material_maker/setup.sh [install dir]   (default: ~/material_maker)
set -e
DEST="${1:-$HOME/material_maker}"
URL=https://github.com/RodZill4/material-maker/releases/download/1.7/material_maker_1_7_linux.tar.gz

if ! command -v Xvfb >/dev/null || ! command -v xdotool >/dev/null || ! command -v xwd >/dev/null \
		|| [ ! -f /usr/share/vulkan/icd.d/lvp_icd.json ]; then
	apt-get update -q
	apt-get install -y -q xvfb xdotool x11-apps mesa-vulkan-drivers libvulkan1
fi

if [ ! -x "$DEST/material_maker_1_7_linux/material_maker.x86_64" ]; then
	mkdir -p "$DEST"
	curl -fL --retry 3 -o "$DEST/mm17.tar.gz" "$URL"
	tar -xzf "$DEST/mm17.tar.gz" -C "$DEST"
	rm "$DEST/mm17.tar.gz"
fi
echo "Material Maker: $DEST/material_maker_1_7_linux/material_maker.x86_64"
