#!/usr/bin/env bash
# Entfernt Pegli: LaunchAgent stoppen, Plist und ~/Applications/Pegli.app löschen. Einstellungen und Log bleiben.
set -euo pipefail

LABEL="local.hanno.pegli"
DEST="$HOME/Applications/Pegli.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x Pegli 2>/dev/null || true

rm -f "$PLIST"
rm -rf "$DEST"

echo "Pegli entfernt."
echo "Übrig (bei Bedarf selbst löschen): ~/Library/Logs/Pegli.log, Einstellungen (defaults delete $LABEL)"
