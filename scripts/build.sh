#!/usr/bin/env bash
# Baut Pegli (Release, arm64) und packt es als build/Pegli.app (ad-hoc signiert).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

APP="$ROOT/build/Pegli.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/Pegli" "$APP/Contents/MacOS/Pegli"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

plutil -lint -s "$APP/Contents/Info.plist"
codesign --force --deep -s - --identifier local.hanno.pegli "$APP"
codesign --verify --strict "$APP"

echo "Gebaut: $APP ($(du -sh "$APP" | cut -f1))"
