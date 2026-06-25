#!/usr/bin/env bash
# Build, sign, notarize, staple, and zip SimpleClaudeMenuBar for a GitHub release.
#
# Required environment:
#   SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE  notarytool keychain profile name (see below)
#
# One-time notarytool credential setup:
#   xcrun notarytool store-credentials NOTARY_PROFILE \
#     --apple-id "you@example.com" --team-id TEAMID --password <app-specific-password>
#
# Usage: scripts/release.sh <version>
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version>}"
APP_NAME="SimpleClaudeMenuBar"
APP="build/$APP_NAME.app"
ZIP="build/$APP_NAME-$VERSION.zip"

: "${SIGN_IDENTITY:?set SIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE to your notarytool keychain profile}"

scripts/build-app.sh "$VERSION"

echo "==> Code signing (hardened runtime)"
codesign --force --deep --options runtime --timestamp \
  --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Zipping for notarization"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple notary service"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling ticket"
xcrun stapler staple "$APP"

echo "==> Re-zipping stapled app"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done: $ZIP"
echo "    sha256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
