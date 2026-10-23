# Entwicklung

## Voraussetzungen

- macOS 14+ auf Apple Silicon
- Command Line Tools (`xcode-select --install`) — Xcode ist **nicht** nötig
- Keine Abhängigkeiten außer Apple-Frameworks (AppKit, SwiftUI, IOKit, SystemConfiguration)

## Bauen, testen, installieren

```sh
./scripts/build.sh                                  # Release-Build → build/Pegli.app (ad-hoc signiert)
build/Pegli.app/Contents/MacOS/Pegli --dump         # alle Messwerte als Text
build/Pegli.app/Contents/MacOS/Pegli --render p.png --expanded --dark
./scripts/install.sh                                # nach ~/Applications + LaunchAgent, startet neu
```

`--render` wartet sechs echte Messungen ab (Intervall dabei kurz auf 1 s, danach wird die Einstellung zurückgesetzt) und speichert das Panel per `ImageRenderer` mit Scale 2. Das Bild hat einen festen Hintergrund statt Glas.

`--expanded` schreibt den Aufklapp-Zustand kurz in die echten Einstellungen (`local.hanno.pegli`) und stellt ihn danach wieder her. Für unbeeinflusste Renders das Binary ohne Bundle nehmen (`.build/release/Pegli`) — das nutzt die Defaults-Domain `Pegli`, danach `defaults delete Pegli`.

## Architektur

```
             ┌──────────── Hintergrund-Queue ────────────┐
Timer ──▶ Sampler ──▶ CPUSampler, MemoryReader, DiskReader, DiskIOSampler,
             │        NetworkSampler, BatteryReader, SystemReader,
             │        SelfUsageSampler, ProcessSampler (nur bei offenem Panel)
             └──▶ Snapshot (reine Werte, Sendable)
                        │  MainActor
                        ▼
                    Monitor (ObservableObject: snapshot + Verläufe à 90 Punkte)
                     │                     │
        StatusIconRenderer            PopoverView (SwiftUI, in NSPopover)
        (NSImage, Template)                │
                                       PanelState (Pin, Aufklappen, Aktionen → AppDelegate)
```

- **Model/** ist der Vertrag zwischen Sensoren, UI und App. Sensoren kennen keine UI, die UI kennt keine Sensoren.
- **Monitor** misst immer (Menüleisten-Icon), die Prozessliste aber nur, solange das Panel offen ist (`monitor.detailed`). Beim Öffnen wird sie sofort einmal nachgeladen, ohne die CPU-/Netz-Deltas zu stören.
- **AppDelegate** erzeugt den `NSHostingController` bei jedem Öffnen neu und verwirft ihn beim Schließen → bei geschlossenem Panel läuft kein SwiftUI-Update.
- Das Icon wird nur neu gezeichnet, wenn sich ein Balken sichtbar ändert (20 Stufen ≈ 1 pt); die CPU fürs Icon ist geglättet (Zeitkonstante 6 s). Jedes Icon-Update kostet ≈ 20 ms, das Messen aller Sensoren nur ≈ 0,1 % CPU — Icon-Updates sind der Haupthebel.
- Ressourcen messen: `scripts/measure.sh [sekunden]` (Durchschnitts-CPU aus der CPU-Zeit, Footprint, Energiebedarf).

## Stolpersteine mit den Command Line Tools

- **`@State` geht nicht.** Es ist im aktuellen SDK ein Makro, das Plugin fehlt ohne Xcode („SwiftUIMacros not found"). Stattdessen `@StateObject` mit kleinem `ObservableObject`, `@AppStorage` oder `PanelState`.
- **`ImageRenderer` zeichnet kein `Menu`, keine `ScrollView`, keine Materials.** Eine unsichtbare `WindowProbe` schaltet im echten Fenster auf `Menu`/`ScrollView` um, im Render bleibt alles statisch.
- **System-App-Icons** ließen `ImageRenderer` in 16-Bit-HDR rendern (blasse PNGs) → der Icon-Cache rastert Icons in 8-Bit-sRGB.
- Sprachmodus Swift 5 (`swift-tools-version:5.10`), damit die strikte Concurrency-Prüfung von Swift 6 nicht jede C-API blockiert.

## Code-Stil

- Kommentare knapp, auf Deutsch; Texte in der UI auf Deutsch, Zahlen in `de_DE` (zentral in `UI/Format.swift`).
- Speicher binär (GiB, wie Aktivitätsanzeige), Laufwerke dezimal (GB, wie Finder), Netzwerk in Bit/s.
- Neue Sensoren: Wert in `Snapshot` ergänzen → Reader/Sampler in `Sensors/` → in `Sampler.sample` eintragen → UI. Teuer? Nur bei `detailed` messen oder wie `DiskReader` nur jeden n-ten Tick.

## Release

1. Version in `Resources/Info.plist` hochziehen (`CFBundleShortVersionString`, `CFBundleVersion`) und `CHANGELOG.md` ergänzen (Überschrift `## <Version> — <Datum>`).
2. Committen, Tag `v<Version>` pushen (`git tag v1.2 && git push --tags`).
3. `.github/workflows/release.yml` baut die App, prüft Tag gegen Info.plist und veröffentlicht `Pegli-macOS.zip` + `SHA256SUMS` mit dem Changelog-Abschnitt als Release-Notiz. `install.sh` lädt immer das neueste Release.

Lokal geht weiterhin `./scripts/export.sh` (ZIPs nach `~/Downloads`).
