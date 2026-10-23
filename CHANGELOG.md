# Changelog

## 1.1 — 2026-10-20

- Umbenannt von „Pegel" in **Pegli** (Bundle-ID `local.hanno.pegli`, LaunchAgent, Log, Repo).
- Open Source auf GitHub unter MIT-Lizenz, README auf Deutsch und Englisch mit neuer Preview.
- Installer per Einzeiler (`install.sh`): lädt das Release, prüft SHA-256, installiert samt Autostart.
- GitHub Actions: CI-Build mit `--dump`, Release-Workflow baut ZIP + `SHA256SUMS` bei jedem Tag.

## 1.0 — 2026-10-20

- Menüleisten-Icon mit CPU/MEM/HD-Balken, Panel als NSPopover.
- Bereiche Akku, Prozessor, Speicher (inkl. Speicherdruck, Swap), Laufwerke (inkl. externer Volumes, I/O), Netzwerk, Temperatur (thermischer Zustand), Uptime, Eigenlast.
- Aufklappbare Details je Bereich, Top-5-Apps nach CPU und Speicher mit App-Icons und Gruppierung wie in der Aktivitätsanzeige.
- Design: Karten mit Akzentfarbe je Bereich, Ringe, weiche Verlaufsgraphen, kompakte Schrift; hell und dunkel.
- Pin, Zahnrad-Menü (Intervall, Autostart, Beenden), Esc, Rechtsklick-Menü.
- Autostart per LaunchAgent mit Neustart nach Absturz; Skripte für Build, Installation, Deinstallation, Export.
- Test-Flags `--dump` und `--render`.
