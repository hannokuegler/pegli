#!/bin/bash
# Pegli — Installer ohne Build / installer without building
#
#   curl -fsSL https://raw.githubusercontent.com/hannokuegler/pegli/main/install.sh | bash
#
# Lädt die neueste Release-ZIP von GitHub, prüft deren SHA-256 gegen SHA256SUMS,
# installiert nach ~/Applications/Pegli.app, richtet den Autostart ein und startet Pegli.
# Bestimmte Version: PEGLI_VERSION=v1.1 bash install.sh
# Aus dem Quellcode bauen statt laden: scripts/install.sh
#
# Alles steckt in main(), damit ein abgebrochener Download nie halb ausgeführt wird.

main() {
  set -euo pipefail

  local repo="hannokuegler/pegli"
  local zip_name="Pegli-macOS.zip"
  local label="local.hanno.pegli"
  local version="${PEGLI_VERSION:-latest}"
  local dest="$HOME/Applications/Pegli.app"
  local plist="$HOME/Library/LaunchAgents/$label.plist"
  local log="$HOME/Library/Logs/Pegli.log"
  local domain="gui/$(id -u)"

  local german=false
  case "$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2p')" in *de*) german=true ;; esac
  say() { if $german; then echo "$1"; else echo "$2"; fi; }
  step() { printf '\n\033[1m▸ %s\033[0m\n' "$(say "$1" "$2")"; }
  fail() {
    printf '\n\033[31m✖ %s\033[0m\n' "$(say "$1" "$2")" >&2
    exit 1
  }

  # PEGLI_VERSION landet in der Download-URL → nur latest oder vX.Y[.Z]
  if [ "$version" != "latest" ] && ! [[ "$version" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    fail "Ungültige Version: $version (erwartet z. B. v1.1)" "Invalid version: $version (expected e.g. v1.1)"
  fi

  # ── System ───────────────────────────────────────────────────────────────
  [ "$(uname -s)" = "Darwin" ] || fail "Pegli läuft nur auf macOS." "Pegli only runs on macOS."
  [ "$(uname -m)" = "arm64" ] || fail "Pegli braucht einen Mac mit Apple Silicon." "Pegli needs an Apple Silicon Mac."
  local macos_version
  macos_version=$(sw_vers -productVersion)
  [ "${macos_version%%.*}" -ge 14 ] \
    || fail "macOS $macos_version ist zu alt – Pegli braucht macOS 14 oder neuer." \
      "macOS $macos_version is too old – Pegli needs macOS 14 or newer."
  [ "$(id -u)" != 0 ] || fail "Bitte ohne sudo ausführen." "Please run without sudo."

  # ── Release laden und prüfen ─────────────────────────────────────────────
  step "Pegli herunterladen" "Downloading Pegli"
  local base_url
  if [ "$version" = "latest" ]; then
    base_url="https://github.com/$repo/releases/latest/download"
  else
    base_url="https://github.com/$repo/releases/download/$version"
  fi
  # global, damit der EXIT-Trap ihn nach main noch kennt
  work_dir=$(mktemp -d "${TMPDIR:-/tmp}/pegli-install.XXXXXX")
  trap 'rm -rf "${work_dir:-}"' EXIT
  curl -fsSL --proto '=https' --tlsv1.2 -o "$work_dir/$zip_name" "$base_url/$zip_name" \
    || fail "Download fehlgeschlagen: $base_url/$zip_name" "Download failed: $base_url/$zip_name"
  curl -fsSL --proto '=https' --tlsv1.2 -o "$work_dir/SHA256SUMS" "$base_url/SHA256SUMS" \
    || fail "Download fehlgeschlagen: $base_url/SHA256SUMS" "Download failed: $base_url/SHA256SUMS"

  step "Prüfsumme (SHA-256) prüfen" "Verifying checksum (SHA-256)"
  local expected actual
  expected=$(awk -v name="$zip_name" '$2 == name || $2 == "*" name { print $1 }' "$work_dir/SHA256SUMS")
  actual=$(shasum -a 256 "$work_dir/$zip_name" | awk '{ print $1 }')
  [ -n "$expected" ] || fail "SHA256SUMS enthält keinen Eintrag für $zip_name." "SHA256SUMS has no entry for $zip_name."
  [ "$expected" = "$actual" ] || fail "Prüfsumme stimmt nicht – Download beschädigt oder manipuliert. Abbruch." \
    "Checksum mismatch – download damaged or tampered with. Aborting."
  echo "  $actual ✓"

  ditto -x -k "$work_dir/$zip_name" "$work_dir/unpacked"
  local new_app="$work_dir/unpacked/Pegli.app"
  [ -d "$new_app" ] || fail "Die ZIP enthält keine Pegli.app." "The ZIP contains no Pegli.app."
  codesign --verify --strict "$new_app" 2>/dev/null \
    || fail "Die Signatur der App ist ungültig. Abbruch." "The app's signature is invalid. Aborting."

  # ── Installieren ─────────────────────────────────────────────────────────
  step "Nach ~/Applications installieren" "Installing to ~/Applications"
  launchctl bootout "$domain/$label" 2>/dev/null || true
  pkill -x Pegli 2>/dev/null || true
  for _ in {1..20}; do
    pgrep -x Pegli >/dev/null || break
    sleep 0.25
  done
  mkdir -p "$HOME/Applications"
  rm -rf "$dest"
  ditto "$new_app" "$dest"
  echo "  $dest"

  # ── Autostart ────────────────────────────────────────────────────────────
  # Inhalt identisch zu scripts/launch-agent-plist.sh und LoginItem.plist().
  step "Autostart einrichten" "Setting up autostart"
  mkdir -p "$(dirname "$plist")" "$(dirname "$log")"
  local tmp="$work_dir/agent.plist"
  plutil -create xml1 "$tmp"
  plutil -insert Label -string "$label" "$tmp"
  plutil -insert ProgramArguments -array "$tmp"
  plutil -insert ProgramArguments.0 -string "$dest/Contents/MacOS/Pegli" "$tmp"
  plutil -insert RunAtLoad -bool YES "$tmp"
  plutil -insert KeepAlive -dictionary "$tmp"
  plutil -insert KeepAlive.SuccessfulExit -bool NO "$tmp"
  plutil -insert ProcessType -string Interactive "$tmp"
  plutil -insert LimitLoadToSessionType -string Aqua "$tmp"
  plutil -insert AssociatedBundleIdentifiers -array "$tmp"
  plutil -insert AssociatedBundleIdentifiers.0 -string "$label" "$tmp"
  plutil -insert StandardOutPath -string "$log" "$tmp"
  plutil -insert StandardErrorPath -string "$log" "$tmp"
  plutil -lint -s "$tmp"
  mv -f "$tmp" "$plist"
  launchctl enable "$domain/$label" 2>/dev/null || true
  launchctl bootstrap "$domain" "$plist"
  echo "  $plist"

  sleep 1
  local pid
  if pid="$(pgrep -x Pegli)"; then
    printf '\n\033[32m✔ %s\033[0m\n' "$(say "Pegli läuft (PID $pid) – schau oben rechts in die Menüleiste." \
      "Pegli is running (PID $pid) – look at the top right of your menu bar.")"
  else
    fail "Pegli läuft nicht – Log: $log" "Pegli is not running – log: $log"
  fi
  say "Entfernen: curl -fsSL https://raw.githubusercontent.com/$repo/main/scripts/uninstall.sh | bash" \
    "Uninstall: curl -fsSL https://raw.githubusercontent.com/$repo/main/scripts/uninstall.sh | bash"
}

main "$@"
