#!/usr/bin/env bash
set -euo pipefail

# Build AppIcon.icns for macOS from the 1024 source PNG.
# Usage: bash scripts/build_icns.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/audioscrap/Assets.xcassets/AppIcon.appiconset/audioscrap-iOS-Default-1024@1x.png"
APPICONSET_DIR="$REPO_ROOT/audioscrap/Assets.xcassets/AppIcon.appiconset"
ICONSET_DIR="$APPICONSET_DIR/AppIcon.iconset"
OUT_ICNS="$APPICONSET_DIR/AppIcon.icns"

if [ ! -f "$SRC" ]; then
  echo "Source icon not found: $SRC"
  exit 1
fi

# Generate raster PNGs if not already present
if [ ! -f "$APPICONSET_DIR/icon_512x512@2x.png" ]; then
  echo "Generating PNG sizes..."
  if ! command -v sips >/dev/null 2>&1; then
    echo "sips not found; cannot generate resized PNGs. Please run this on macOS with sips installed."
    exit 2
  fi

  # macOS ships with bash 3.x which lacks associative arrays; use explicit commands
  echo "Generating $APPICONSET_DIR/icon_16x16.png (16x16)"
  sips -Z 16 "$SRC" --out "$APPICONSET_DIR/icon_16x16.png" >/dev/null
  echo "Generating $APPICONSET_DIR/icon_16x16@2x.png (32x32)"
  sips -Z 32 "$SRC" --out "$APPICONSET_DIR/icon_16x16@2x.png" >/dev/null
  echo "Generating $APPICONSET_DIR/icon_32x32.png (32x32)"
  sips -Z 32 "$SRC" --out "$APPICONSET_DIR/icon_32x32.png" >/dev/null
  echo "Generating $APPICONSET_DIR/icon_32x32@2x.png (64x64)"
  sips -Z 64 "$SRC" --out "$APPICONSET_DIR/icon_32x32@2x.png" >/dev/null
  echo "Generating $APPICONSET_DIR/icon_128x128.png (128x128)"
  sips -Z 128 "$SRC" --out "$APPICONSET_DIR/icon_128x128.png" >/dev/null
  echo "Generating $APPICONSET_DIR/icon_128x128@2x.png (256x256)"
  sips -Z 256 "$SRC" --out "$APPICONSET_DIR/icon_128x128@2x.png" >/dev/null
  echo "Generating $APPICONSET_DIR/icon_256x256.png (256x256)"
  sips -Z 256 "$SRC" --out "$APPICONSET_DIR/icon_256x256.png" >/dev/null
  echo "Generating $APPICONSET_DIR/icon_256x256@2x.png (512x512)"
  sips -Z 512 "$SRC" --out "$APPICONSET_DIR/icon_256x256@2x.png" >/dev/null
  echo "Generating $APPICONSET_DIR/icon_512x512.png (512x512)"
  sips -Z 512 "$SRC" --out "$APPICONSET_DIR/icon_512x512.png" >/dev/null
  echo "Generating $APPICONSET_DIR/icon_512x512@2x.png (1024x1024)"
  sips -Z 1024 "$SRC" --out "$APPICONSET_DIR/icon_512x512@2x.png" >/dev/null
else
  echo "PNG sizes already present, skipping generation."
fi

# Prepare iconset directory
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Copy expected icon filenames into iconset
cp "$APPICONSET_DIR/icon_16x16.png" "$ICONSET_DIR/icon_16x16.png"
cp "$APPICONSET_DIR/icon_16x16@2x.png" "$ICONSET_DIR/icon_16x16@2x.png"
cp "$APPICONSET_DIR/icon_32x32.png" "$ICONSET_DIR/icon_32x32.png"
cp "$APPICONSET_DIR/icon_32x32@2x.png" "$ICONSET_DIR/icon_32x32@2x.png"
cp "$APPICONSET_DIR/icon_128x128.png" "$ICONSET_DIR/icon_128x128.png"
cp "$APPICONSET_DIR/icon_128x128@2x.png" "$ICONSET_DIR/icon_128x128@2x.png"
cp "$APPICONSET_DIR/icon_256x256.png" "$ICONSET_DIR/icon_256x256.png"
cp "$APPICONSET_DIR/icon_256x256@2x.png" "$ICONSET_DIR/icon_256x256@2x.png"
cp "$APPICONSET_DIR/icon_512x512.png" "$ICONSET_DIR/icon_512x512.png"
cp "$APPICONSET_DIR/icon_512x512@2x.png" "$ICONSET_DIR/icon_512x512@2x.png"

# Require iconutil for .icns packaging
if ! command -v iconutil >/dev/null 2>&1; then
  echo "iconutil not found; cannot create .icns. Please run this on macOS with iconutil installed."
  exit 2
fi

# Build .icns
rm -f "$OUT_ICNS"
iconutil -c icns "$ICONSET_DIR" -o "$OUT_ICNS"

if [ -f "$OUT_ICNS" ]; then
  echo "Created $OUT_ICNS"
  # Optionally clean up: keep iconset for debugging
  # rm -rf "$ICONSET_DIR"
  exit 0
else
  echo "Failed to create $OUT_ICNS"
  exit 3
fi
