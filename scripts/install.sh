#!/usr/bin/env bash
# Build SimpleClaudeMenuBar and install it locally to /Applications.
# Ad-hoc signs and strips the quarantine attribute so it launches without
# a Gatekeeper prompt (app is unsigned/not notarized, see [[release-pipeline]]).
# Usage: scripts/install.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
APP_NAME="SimpleClaudeMenuBar"
APP="build/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"

scripts/build-app.sh "$VERSION"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"

if pgrep -qf "$DEST/Contents/MacOS/$APP_NAME"; then
  echo "==> Quitting running instance"
  osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || pkill -f "$DEST/Contents/MacOS/$APP_NAME" || true
  sleep 1
fi

echo "==> Installing to $DEST"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "==> Removing quarantine attribute"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "==> Installed $DEST"
