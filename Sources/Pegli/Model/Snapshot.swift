import Foundation

/// Ein Messpunkt aller Sensoren. Reine Werte, keine Formatierung.
struct Snapshot: Sendable {
    var cpu: CPUInfo
    var memory: MemoryInfo
    /// Erstes Element = Startvolume (isBoot), danach weitere gemountete Volumes.
    var disks: [DiskInfo]
    var diskIO: DiskIO
    var network: NetworkInfo
    /// nil, wenn kein Akku vorhanden ist.
    var battery: BatteryInfo?
    var thermal: ThermalLevel
    /// Sekunden seit Boot.
    var uptime: TimeInterval
    var selfUsage: SelfUsage
    /// Nur gefüllt, solange das Panel offen ist (Monitor.detailed == true).
    var topCPUApps: [AppUsage]
    var topMemoryApps: [AppUsage]

    static let empty = Snapshot(
        cpu: CPUInfo(usage: 0, user: 0, system: 0, perCore: [], loadAverage: [0, 0, 0]),
        memory: MemoryInfo(used: 0, total: 0, active: 0, compressed: 0, wired: 0, swapUsed: 0, pressure: .normal, pressureFraction: 0),
        disks: [],
        diskIO: DiskIO(readBytesPerSec: 0, writeBytesPerSec: 0),
        network: NetworkInfo(downBytesPerSec: 0, upBytesPerSec: 0, interfaceName: nil, localIP: nil, totalDown: 0, totalUp: 0),
        battery: nil,
        thermal: .nominal,
        uptime: 0,
        selfUsage: SelfUsage(cpuPercent: 0, memoryBytes: 0),
        topCPUApps: [],
        topMemoryApps: []
    )
}

struct CPUInfo: Sendable {
    /// Gesamtlast 0...1 (user + system + nice über alle Kerne).
    var usage: Double
    var user: Double
    var system: Double
    /// Last je Kern 0...1.
    var perCore: [Double]
    /// 1, 5, 15 Minuten.
    var loadAverage: [Double]
}

enum MemoryPressure: Int, Sendable {
    case normal = 0, warning, critical
}

struct MemoryInfo: Sendable {
    /// Wie Aktivitätsanzeige „Belegter Speicher": App-Speicher + wired + komprimiert, in Bytes.
    var used: UInt64
    var total: UInt64
    var active: UInt64
    var compressed: UInt64
    var wired: UInt64
    var swapUsed: UInt64
    var pressure: MemoryPressure
    /// Speicherdruck 0...1 (für den Verlaufsgraphen).
    var pressureFraction: Double
    var fraction: Double { total == 0 ? 0 : min(1, Double(used) / Double(total)) }
}

struct DiskInfo: Sendable, Identifiable {
    /// Mount-Pfad, z. B. "/" oder "/Volumes/Backup".
    var id: String
    var name: String
    var total: UInt64
    var available: UInt64
    var isBoot: Bool
    var used: UInt64 { total > available ? total - available : 0 }
    var usedFraction: Double { total == 0 ? 0 : min(1, Double(used) / Double(total)) }
}

struct DiskIO: Sendable {
    var readBytesPerSec: Double
    var writeBytesPerSec: Double
}

struct NetworkInfo: Sendable {
    var downBytesPerSec: Double
    var upBytesPerSec: Double
    /// Primäres aktives Interface, z. B. "en0".
    var interfaceName: String?
    /// IPv4 des primären Interfaces.
    var localIP: String?
    /// Bytes seit Boot (Summe über physische Interfaces).
    var totalDown: UInt64
    var totalUp: UInt64
}

struct BatteryInfo: Sendable {
    /// 0...1
    var level: Double
    var isCharging: Bool
    var isPluggedIn: Bool
    var isCharged: Bool
    /// Restlaufzeit bzw. Zeit bis voll, in Minuten; nil = unbekannt/berechnet noch.
    var minutesRemaining: Int?
    var cycleCount: Int?
    /// Maximale Kapazität relativ zur Design-Kapazität, 0...1.
    var health: Double?
    /// Akkutemperatur in °C.
    var temperatureC: Double?
    /// Leistung des Netzteils in Watt, falls angeschlossen.
    var adapterWatts: Int?
}

enum ThermalLevel: Int, Sendable, CaseIterable {
    case nominal = 0, fair, serious, critical
}

struct SelfUsage: Sendable {
    /// Prozent eines Kerns (kann > 100 sein).
    var cpuPercent: Double
    var memoryBytes: UInt64
}

/// Eine App (Helper-Prozesse zur .app zusammengefasst) oder ein einzelner Prozess.
struct AppUsage: Sendable, Identifiable {
    /// Bundle-Pfad der äußersten .app, sonst "proc:<Pfad>".
    var id: String
    var name: String
    /// Pfad zur .app für das Icon (NSWorkspace.shared.icon(forFile:)); nil bei reinen Prozessen.
    var bundlePath: String?
    /// Prozent eines Kerns, summiert über alle Prozesse der App.
    var cpuPercent: Double
    /// Physischer Footprint (wie Aktivitätsanzeige „Speicher"), summiert.
    var memoryBytes: UInt64
}
