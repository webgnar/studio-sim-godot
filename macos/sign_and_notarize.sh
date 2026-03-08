#!/bin/bash
# Usage: ./sign_and_notarize.sh /path/to/exported.dmg
# Extracts .app from Godot-exported DMG, signs it, notarizes, and staples.

set -e

INPUT_DMG="${1:-$HOME/Desktop/sdk/tools/ContentBuilder/content_mac/studio_sim.dmg}"
OUTPUT_DMG="$HOME/Desktop/studio_sim_signed.dmg"
CERT="Developer ID Application: Zachary Goulet (DV39Q2679M)"
APPLE_ID="zackgoolay@gmail.com"
APP_PASSWORD="dici-sken-ncxq-qfar"
TEAM_ID="DV39Q2679M"
ENTITLEMENTS="$HOME/Godot/studio-sim-godot/macos/studio_sim.entitlements"
WORK_DIR="$HOME/Desktop/_signing_tmp"

echo "=== Cleaning up work dir ==="
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "=== Mounting DMG ==="
hdiutil attach "$INPUT_DMG" -mountpoint "$WORK_DIR/mnt" -nobrowse -quiet

echo "=== Copying .app ==="
APP_NAME=$(ls "$WORK_DIR/mnt" | grep ".app")
cp -R "$WORK_DIR/mnt/$APP_NAME" "$WORK_DIR/$APP_NAME"
hdiutil detach "$WORK_DIR/mnt" -quiet

APP="$WORK_DIR/$APP_NAME"
echo "=== Signing: $APP ==="

# Sign dylibs first (inside-out)
for DYLIB in "$APP/Contents/Frameworks/"*.dylib; do
  echo "  Signing $DYLIB"
  codesign --force --verify --verbose --sign "$CERT" --timestamp "$DYLIB"
done

# Sign executable
echo "  Signing executable"
codesign --force --verify --verbose --sign "$CERT" --timestamp \
  --options runtime --entitlements "$ENTITLEMENTS" \
  "$APP/Contents/MacOS/"*

# Sign .app bundle
echo "  Signing .app"
codesign --force --verify --verbose --sign "$CERT" --timestamp \
  --options runtime --entitlements "$ENTITLEMENTS" \
  "$APP"

echo "=== Verifying signature ==="
codesign --verify --deep --strict --verbose=2 "$APP"

echo "=== Creating DMG ==="
hdiutil create -volname "Studio Sim" -srcfolder "$APP" -ov -format UDZO "$OUTPUT_DMG"

echo "=== Notarizing ==="
xcrun notarytool submit "$OUTPUT_DMG" \
  --apple-id "$APPLE_ID" \
  --password "$APP_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait

echo "=== Stapling ==="
xcrun stapler staple "$OUTPUT_DMG"
xcrun stapler validate "$OUTPUT_DMG"

echo "=== Cleaning up ==="
rm -rf "$WORK_DIR"

echo ""
echo "Done! Signed DMG at: $OUTPUT_DMG"
