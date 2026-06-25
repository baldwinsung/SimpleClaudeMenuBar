#!/usr/bin/env bash
# Build a universal SimpleClaudeMenuBar.app bundle (unsigned).
# Usage: scripts/build-app.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
APP_NAME="SimpleClaudeMenuBar"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

echo "==> Building universal release binary (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64

BIN=".build/apple/Products/Release/$APP_NAME"
if [[ ! -f "$BIN" ]]; then
  # Single-arch fallback (e.g. when only one slice is available locally)
  BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

# App icon (optional): drop Resources/AppIcon.icns to include one.
if [[ -f "Resources/AppIcon.icns" ]]; then
  cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
fi

echo "==> Built $APP (version $VERSION)"
file "$APP/Contents/MacOS/$APP_NAME"
