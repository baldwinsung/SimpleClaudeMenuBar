#!/usr/bin/env bash
# Build an UNSIGNED (ad-hoc signed) release zip — no Developer ID required.
# Users will get a one-time Gatekeeper prompt; see README "Unsigned builds".
# Usage: scripts/release-unsigned.sh <version>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release-unsigned.sh <version>}"
APP_NAME="SimpleClaudeMenuBar"
APP="build/$APP_NAME.app"
ZIP="build/$APP_NAME-$VERSION.zip"

scripts/build-app.sh "$VERSION"

echo "==> Ad-hoc signing (lets the arm64 slice launch; not notarized)"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose=2 "$APP" || true

echo "==> Zipping"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "==> Done: $ZIP"
echo "    sha256: $SHA"
