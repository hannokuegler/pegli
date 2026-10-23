#!/usr/bin/env bash
# Schreibt die LaunchAgent-Plist für Pegli. Inhalt identisch zu LoginItem.plist() in Sources/Pegli/App/LoginItem.swift.
# Aufruf: scripts/launch-agent-plist.sh <ziel.plist> <pfad-zur-binary>
set -euo pipefail

TARGET="${1:?Ziel-Plist fehlt}"
BIN="${2:?Pfad zur Binary fehlt}"
LABEL="local.hanno.pegli"
LOG="$HOME/Library/Logs/Pegli.log"

mkdir -p "$(dirname "$TARGET")" "$(dirname "$LOG")"
TMP="$(mktemp "${TARGET}.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

plutil -create xml1 "$TMP"
plutil -insert Label -string "$LABEL" "$TMP"
plutil -insert ProgramArguments -array "$TMP"
plutil -insert ProgramArguments.0 -string "$BIN" "$TMP"
plutil -insert RunAtLoad -bool YES "$TMP"
# Neustart nur nach Absturz, nicht nach „Beenden" (exit 0).
plutil -insert KeepAlive -dictionary "$TMP"
plutil -insert KeepAlive.SuccessfulExit -bool NO "$TMP"
plutil -insert ProcessType -string Interactive "$TMP"
plutil -insert LimitLoadToSessionType -string Aqua "$TMP"
plutil -insert AssociatedBundleIdentifiers -array "$TMP"
plutil -insert AssociatedBundleIdentifiers.0 -string "$LABEL" "$TMP"
plutil -insert StandardOutPath -string "$LOG" "$TMP"
plutil -insert StandardErrorPath -string "$LOG" "$TMP"

plutil -lint -s "$TMP"
mv -f "$TMP" "$TARGET"
trap - EXIT
