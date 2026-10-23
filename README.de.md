<div align="center">

<img src="docs/hero-de.png" alt="Pegli: Menüleisten-Icon mit CPU-, Speicher- und Laufwerksbalken, darunter das Panel hell und dunkel" width="100%">

# Pegli

**Dein Mac auf einen Blick — schlanker Systemmonitor für die macOS-Menüleiste.**<br>
Reines Swift, null Abhängigkeiten, ≈ 0,6 % CPU und ≈ 13 MB Speicher.

[![Release](https://img.shields.io/github/v/release/hannokuegler/pegli?label=Release)](https://github.com/hannokuegler/pegli/releases/latest)
[![CI](https://github.com/hannokuegler/pegli/actions/workflows/ci.yml/badge.svg)](https://github.com/hannokuegler/pegli/actions/workflows/ci.yml)
[![Lizenz: MIT](https://img.shields.io/github/license/hannokuegler/pegli?label=Lizenz)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-555?logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-555)
![Swift](https://img.shields.io/badge/Swift-SwiftUI%20%2B%20AppKit-F05138?logo=swift&logoColor=white)

[English](README.md) · **Deutsch**

</div>

```bash
curl -fsSL https://raw.githubusercontent.com/hannokuegler/pegli/main/install.sh | bash
```

<sub>Ein Befehl im Terminal: lädt die neueste Version, prüft die SHA-256-Prüfsumme, installiert nach `~/Applications`, richtet den Autostart ein und startet Pegli. Andere Wege: [Installation](#installation).</sub>

## Was Pegli kann

Das Icon in der Menüleiste zeigt **CPU, Speicher und Startvolume** als drei Mini-Balken. Ein Klick öffnet das Panel, jeder Bereich klappt per Pfeil seine Details auf:

| Bereich | Übersicht | Aufgeklappt |
|---|---|---|
| 🔋 **Akku** | Stand, Laden/Akkubetrieb, Restzeit | Ladezyklen, Zustand, Temperatur, Netzteil-Watt |
| 🧠 **Prozessor** | Gesamtlast, Verlauf | Benutzer/System/Leerlauf, Load Average, Last je Kern, Top-5-Apps |
| 🧩 **Speicher** | Belegt, Aufteilung Apps/Fixiert/Komprimiert | Speicherdruck mit Verlauf, Aktiv, Swap, Top-5-Apps |
| 💾 **Laufwerk** | Startvolume, weitere Volumes (einklappbar) | Lese-/Schreibrate |
| 🌐 **Netzwerk** | Empfangen/Gesendet | Verlauf, Interface, lokale IP, Summen seit Start |
| 🌡️ **Temperatur** | Thermischer Zustand in 4 Stufen | Erklärung zu den Stufen |

Dazu Uptime und Eigenlast im Fußbereich, „Weitere Informationen ↗" öffnet die passende System-App (Aktivitätsanzeige, Festplattendienstprogramm, Batterie-Einstellungen). Top-Apps werden wie in der Aktivitätsanzeige gruppiert — Helper und Safari-Tabs zählen zur App.

<p align="center">
  <img src="docs/panel-hell-aufgeklappt.png" width="300" alt="Panel aufgeklappt, hell">
  &nbsp;&nbsp;
  <img src="docs/panel-dunkel-aufgeklappt.png" width="300" alt="Panel aufgeklappt, dunkel">
</p>

Pegli spricht **Deutsch und Englisch** und folgt der Systemsprache (oder der App-Sprache unter Systemeinstellungen › Allgemein › Sprache & Region).

**Bedienung**

- **Pin** — Panel bleibt offen, auch wenn man daneben klickt.
- **Zahnrad** — Messintervall (1 / 2 / 5 s), „Beim Anmelden starten", Beenden.
- **X** oder **Esc** — schließen. **Rechtsklick** aufs Icon — Kurzmenü.
- Aufgeklappte Bereiche und Intervall werden gespeichert.

Was genau gemessen wird, woher die Werte kommen und wo die Grenzen liegen: [docs/MESSWERTE.md](docs/MESSWERTE.md).

## 🪶 Leichtgewicht

Ein Systemmonitor, der selbst Last erzeugt, misst vor allem sich selbst. Pegli ist darauf gebaut, im Hintergrund nicht aufzufallen:

| | Pegli |
|---|---|
| **CPU** im Schnitt | **≈ 0,6 %** eines Kerns |
| **Speicher** (Footprint, wie in der Aktivitätsanzeige) | **≈ 13 MB** |
| **App-Größe** | 1,7 MB (Download 0,8 MB) |
| **Abhängigkeiten** | keine, nur Apple-Frameworks |

<sub>Gemessen über 5 Minuten mit [`scripts/measure.sh`](scripts/measure.sh) auf einem MacBook Pro M1 (16 GB), Panel geschlossen, 2-s-Intervall. CPU aus der tatsächlich verbrauchten CPU-Zeit, nicht aus Momentwerten.</sub>

**So kommt Pegli auf die Werte**

- **Messen ist billig, Zeichnen teuer.** Alle Sensoren zusammen kosten nur ≈ 0,1 % CPU. Den Rest braucht macOS, um das Icon in der Menüleiste zu aktualisieren — rund 20 ms pro Update. Darum zeichnet Pegli das Icon nur neu, wenn sich ein Balken **sichtbar** ändert (≈ 1 pt), und glättet die CPU-Last fürs Icon über ein paar Sekunden. Das Panel zeigt weiter die exakten Werte. Ergebnis: halb so viel CPU wie vorher (1,3 % → 0,6 %), dazu ein ruhiges Icon ohne Geflacker.
- **Prozessliste nur bei offenem Panel.** Die Top-Apps (teuerste Messung) laufen nur, solange du hinschaust.
- **Kein SwiftUI im Leerlauf.** Das Panel wird beim Öffnen gebaut und beim Schließen verworfen.
- **Volumes nur jeden 10. Takt**, alles andere direkt über Mach, IOKit und `sysctl` — ohne Hilfsprozesse und ohne Polling von Kommandozeilen-Tools.

Pegli zeigt seine Eigenlast unten im Panel selbst an. Nachmessen auf deinem Mac:

```bash
git clone https://github.com/hannokuegler/pegli.git && pegli/scripts/measure.sh
```

## Installation

**Voraussetzungen:** Mac mit Apple Silicon, macOS 14 (Sonoma) oder neuer.

**1. Per Terminal (empfohlen)** — der Befehl oben. Erneut ausführen = Update.

**2. Aus dem Quellcode** — braucht nur die Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/hannokuegler/pegli.git
cd pegli
./scripts/install.sh
```

Baut im Release-Modus, legt `~/Applications/Pegli.app` an, richtet den Autostart ein und startet Pegli sofort.

**3. Von Hand** — `Pegli-macOS.zip` aus dem [neuesten Release](https://github.com/hannokuegler/pegli/releases/latest) laden, `Pegli.app` nach `~/Applications` ziehen. Pegli ist ad-hoc signiert, nicht notarisiert: Beim ersten Start blockiert macOS die App, dann unter **Systemeinstellungen › Datenschutz & Sicherheit** auf **„Dennoch öffnen"** klicken. Autostart danach im Zahnrad-Menü einschalten.

## Deinstallation

```bash
curl -fsSL https://raw.githubusercontent.com/hannokuegler/pegli/main/scripts/uninstall.sh | bash
```

Oder im geklonten Ordner `./scripts/uninstall.sh`. Stoppt den Autostart und löscht `~/Applications/Pegli.app` sowie den LaunchAgent. Einstellungen bleiben, entfernen mit `defaults delete local.hanno.pegli`.

## Autostart

Ein eigener LaunchAgent `~/Library/LaunchAgents/local.hanno.pegli.plist` (kein `SMAppService`, das bräuchte eine echte Signatur):

- `RunAtLoad` → startet beim Login
- `KeepAlive.SuccessfulExit = false` → Neustart nach Absturz, „Beenden" bleibt beendet
- `LimitLoadToSessionType Aqua`, `ProcessType Interactive`
- Eine zweite Instanz beendet sich beim Start selbst.

Status: `launchctl print gui/$(id -u)/local.hanno.pegli` · Log: `~/Library/Logs/Pegli.log`

## Aufbau

```
Package.swift
Sources/Pegli/
  Model/    Vertrag: Snapshot (Messwerte), Monitor (Timer, Verläufe), PanelState (Panel-Zustand, Aktionen)
  Sensors/  Messung: CPU, Speicher, Volumes, Disk-I/O, Netzwerk, Akku, Thermik, Prozesse, Eigenlast
  UI/       SwiftUI-Panel (PopoverView, Sections/, Components, Format) und Menüleisten-Icon
  App/      AppKit-Gerüst: main, AppDelegate (Statusleiste, Popover, Menü), LoginItem, CLI
Resources/  Info.plist, AppIcon.icns
scripts/    build, install, uninstall, export, launch-agent-plist, make-icon
install.sh  Installer per curl (lädt das Release)
docs/       MESSWERTE.md, ENTWICKLUNG.md, Bilder
```

Bauen, Test-Flags (`--dump`, `--render`), Architektur, Release und Stolpersteine mit den Command Line Tools: [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md). Änderungen: [CHANGELOG.md](CHANGELOG.md).

## Lizenz

[MIT](LICENSE) © 2026 Hanno Kügler — nimm's, bau's um, teil's weiter.
