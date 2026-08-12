#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/SpotifyControl.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SIGNING_IDENTITY="${SPOTIFYCONTROL_SIGNING_IDENTITY:--}"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Usage: $0 [debug|release]" >&2
    exit 64
    ;;
esac

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION" >/dev/null
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE="$BIN_DIR/SpotifyControl"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Built executable not found: $EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/SpotifyControl"
cp "$ROOT_DIR/Supporting/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Supporting/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/SpotifyControl"

if [[ "$CONFIGURATION" == "release" ]]; then
  /usr/bin/strip -S "$MACOS_DIR/SpotifyControl"
fi

/usr/bin/plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  /usr/bin/codesign --force --deep --sign - "$APP_DIR"
else
  /usr/bin/codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --entitlements "$ROOT_DIR/Supporting/SpotifyControl.entitlements" \
    --sign "$SIGNING_IDENTITY" \
    "$APP_DIR"
fi
/usr/bin/codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
