#!/bin/bash
# Exportiert Pegli nach ~/Downloads (oder $1): fertige App als Zip + Quellcode-Zip aus Git (HEAD).
set -euo pipefail

cd "$(dirname "$0")/.."
ZIEL="${1:-$HOME/Downloads}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)

./scripts/build.sh

APP_ZIP="$ZIEL/Pegli-$VERSION.zip"
SRC_ZIP="$ZIEL/Pegli-$VERSION-Quellcode.zip"
rm -f "$APP_ZIP" "$SRC_ZIP"

# App: ditto erhält Signatur und Bundle-Struktur
ditto -c -k --sequesterRsrc --keepParent build/Pegli.app "$APP_ZIP"
# Quellcode: nur versionierte Dateien, ohne .build/ und build/
git archive --format=zip --prefix="Pegli-$VERSION/" -o "$SRC_ZIP" HEAD

echo "Export:"
ls -lh "$APP_ZIP" "$SRC_ZIP" | awk '{print "  " $5 "\t" $9}'
