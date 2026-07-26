#!/usr/bin/env bash
#
# Builds PingMate.app as a universal (arm64 + x86_64) Release binary.
#
#   ./scripts/build-app.sh <version> [build-number]
#
# The app is ad-hoc signed, not Developer ID signed — see README for what that
# means for anyone downloading it. Ad-hoc rather than unsigned because an arm64
# binary with no signature at all will not launch.
set -euo pipefail

VERSION="${1:?usage: build-app.sh <version> [build-number]}"
BUILD_NUMBER="${2:-1}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

xcodebuild \
  -project PingMate/PingMate.xcodeproj \
  -scheme PingMate \
  -configuration Release \
  -derivedDataPath build \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM="" \
  build

APP="$ROOT/build/Build/Products/Release/PingMate.app"
[ -d "$APP" ] || { echo "error: $APP was not produced" >&2; exit 1; }

echo
echo "Built $APP"
lipo -archs "$APP/Contents/MacOS/PingMate"
codesign -dv "$APP" 2>&1 | grep -E "Signature|Identifier" || true
