#!/usr/bin/env bash
#
# Packs the app built by build-app.sh into dist/PingMate-<version>.dmg.
#
#   ./scripts/make-dmg.sh <version>
#
# hdiutil only, no create-dmg dependency: a release that always builds beats a
# release with a decorated Finder window, which needs a GUI session that CI
# runners do not reliably have.
set -euo pipefail

VERSION="${1:?usage: make-dmg.sh <version>}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/Build/Products/Release/PingMate.app"
[ -d "$APP" ] || { echo "error: no app at $APP — run scripts/build-app.sh first" >&2; exit 1; }

DMG="$ROOT/dist/PingMate-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$ROOT/dist"
rm -f "$DMG"

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "PingMate" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$DMG" >/dev/null

echo "$DMG"
shasum -a 256 "$DMG"
