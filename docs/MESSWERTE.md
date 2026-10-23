# Messwerte — woher jede Zahl kommt

Alle Sensoren laufen auf einer seriellen Hintergrund-Queue (`pegli.sampler`), Standardintervall 2 s (einstellbar 1/2/5 s). Keine Shell-Aufrufe, keine privaten Frameworks, keine Root-Rechte. Eine komplette Messung kostet ohne Prozessliste < 2 ms, mit Prozessliste (nur bei offenem Panel) ca. 1,5 ms zusätzlich.

| Bereich | Wert | Quelle | Datei |
|---|---|---|---|
| CPU | Gesamt, User, System, je Kern | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)`, Tick-Delta zur letzten Messung (`nice` zählt zu User) | `Sensors/CPUSampler.swift` |
| CPU | Load Average 1/5/15 min | `getloadavg` | `Sensors/CPUSampler.swift` |
| Speicher | Belegt | wie Aktivitätsanzeige: (internal − purgeable) + wired + compressor, je × Seitengröße | `Sensors/MemoryReader.swift` |
| Speicher | Aktiv, Fixiert, Komprimiert | `host_statistics64(HOST_VM_INFO64)` | `Sensors/MemoryReader.swift` |
| Speicher | Auslagerung (Swap) | `sysctl vm.swapusage` | `Sensors/MemoryReader.swift` |
| Speicher | Speicherdruck (Stufe) | `sysctl kern.memorystatus_vm_pressure_level` (1/2/4 → Normal/Erhöht/Kritisch) | `Sensors/MemoryReader.swift` |
| Speicher | Speicherdruck (Verlauf) | `100 − sysctl kern.memorystatus_level` | `Sensors/MemoryReader.swift` |
| Laufwerk | Volumes, frei/gesamt | `FileManager.mountedVolumeURLs`, frei = `volumeAvailableCapacityForImportantUsage` (wie Finder, inkl. löschbarem Speicher) | `Sensors/DiskReader.swift` |
| Laufwerk | Lesen/Schreiben | IOKit `IOBlockStorageDriver` → `Statistics`, Delta je Registry-ID | `Sensors/DiskIOSampler.swift` |
| Netzwerk | Raten, Summen | Interface-MIB `net.link.generic.ifdata.<idx>` (64-Bit-Zähler), nur `en*` | `Sensors/NetworkSampler.swift` |
| Netzwerk | Interface, IP | `SCDynamicStore` (PrimaryInterface), `getifaddrs` | `Sensors/NetworkSampler.swift` |
| Akku | Stand, Laden, Restzeit | `IOPSCopyPowerSourcesInfo` | `Sensors/BatteryReader.swift` |
| Akku | Zyklen, Zustand, Temperatur | IORegistry `AppleSmartBattery` (inkl. Unter-Dictionary `BatteryData`) | `Sensors/BatteryReader.swift` |
| Akku | Netzteil-Watt | `IOPSCopyExternalPowerAdapterDetails` | `Sensors/BatteryReader.swift` |
| Temperatur | Thermischer Zustand | `ProcessInfo.thermalState` (4 Stufen) | `Sensors/SystemReader.swift` |
| System | Uptime | `sysctl kern.boottime` (Wanduhr, inkl. Ruhezustand) | `Sensors/SystemReader.swift` |
| Pegli | Eigenlast | `proc_pid_rusage(getpid())`: CPU-Delta, `ri_phys_footprint` | `Sensors/SelfUsageSampler.swift` |
| Apps | Top 5 nach CPU / Speicher | `proc_listallpids` + `proc_pid_rusage` je PID, gruppiert nach äußerstem `.app`-Bundle bzw. verantwortlicher App | `Sensors/ProcessSampler.swift` |

## Gruppierung der Top-Apps

1. Pfad enthält `.app/` → äußerstes Bundle (Helper wie „Claude Helper (Renderer)" zählen zu Claude).
2. Sonst verantwortliche App über `responsibility_get_pid_responsible_for_pid` (per `dlsym`, fehlt das Symbol → Schritt 3). So landen Safari-Tabs (`WebKit.WebContent`) bei Safari und aus einem Terminal gestartete Tools beim Terminal — wie in der Aktivitätsanzeige.
3. Sonst gleiche Binary → eine Zeile (z. B. alle `mdworker_shared`).

Pegli selbst steht nicht in der Liste, sondern im Fußbereich („Eigenlast").

## Bekannte Grenzen

- **Keine CPU-Temperatur in °C.** Apple Silicon liefert Sensorwerte nur über private HID-APIs. Pegli zeigt den thermischen Zustand (Normal / Leicht erhöht / Hoch / Kritisch) — ab „Hoch" drosselt macOS.
- **Akkutemperatur** liefert macOS 27 ohne Root nicht mehr → „–".
- **Fremde Prozesse** (root, andere Nutzer: WindowServer, mds, kernel_task) sind ohne Root nicht lesbar und fehlen in den Top-Apps.
- **`NET_RT_IFLIST2`** liefert auf macOS 27 gekappte 32-Bit-Zähler — deshalb die Interface-MIB.
- Die erste Messung nach dem Start hat keine Deltas (CPU, Netz, I/O = 0), ab der zweiten stimmen die Werte.
