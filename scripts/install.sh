#!/usr/bin/env bash
# Baut Pegli, installiert nach ~/Applications/Pegli.app und startet es per LaunchAgent
# (sofort und bei jedem Login, Neustart nur nach Absturz).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="local.hanno.pegli"
DEST="$HOME/Applications/Pegli.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

"$ROOT/scripts/build.sh"

# Laufende Instanz sauber beenden (LaunchAgent und ggf. von Hand gestartete).
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
pkill -x Pegli 2>/dev/null || true
for _ in {1..20}; do
  pgrep -x Pegli >/dev/null || break
  sleep 0.25
done

mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "$ROOT/build/Pegli.app" "$DEST"

"$ROOT/scripts/launch-agent-plist.sh" "$PLIST" "$DEST/Contents/MacOS/Pegli"
launchctl enable "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"

sleep 1
if PID="$(pgrep -x Pegli)"; then
  echo "Pegli läuft (PID $PID)."
else
  echo "Pegli läuft NICHT – Log: ~/Library/Logs/Pegli.log" >&2
  exit 1
fi
echo "App:        $DEST"
echo "Autostart:  $PLIST"
echo "Log:        ~/Library/Logs/Pegli.log"
