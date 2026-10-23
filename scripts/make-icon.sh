#!/usr/bin/env bash
# Erzeugt Resources/AppIcon.icns aus scripts/make-icon.swift. Nur nötig, wenn sich das Icon ändert.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swiftc -O -o "$TMP/make-icon" "$ROOT/scripts/make-icon.swift"
"$TMP/make-icon" "$TMP/AppIcon.iconset"
iconutil -c icns -o "$ROOT/Resources/AppIcon.icns" "$TMP/AppIcon.iconset"
echo "→ $ROOT/Resources/AppIcon.icns"
