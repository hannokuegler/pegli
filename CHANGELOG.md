# Changelog

## 1.3 — 2026-10-23

- Pegli spricht Englisch: Oberfläche auf Deutsch oder Englisch je nach Systemsprache (auch pro App einstellbar), Zahlen im passenden Format.
- README auf Englisch als Hauptseite, deutsche Fassung in `README.de.md`; Preview-Bilder in beiden Sprachen.

## 1.2 — 2026-10-23

- Halb so viel CPU: ≈ 0,6 % statt ≈ 1,3 % (gemessen über 5 min, M1). Das Menüleisten-Icon wird nur noch neu gezeichnet, wenn sich ein Balken sichtbar ändert, und die CPU-Last fürs Icon ist geglättet — ruhigeres Icon, das Panel zeigt weiter exakte Werte.
- `scripts/measure.sh`: misst Durchschnitts-CPU, Speicher-Footprint und Energiebedarf des laufenden Pegli.

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
