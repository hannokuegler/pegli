import Foundation

/// Zentrale Formatierung (de_DE bzw. en_US, je nach Sprache). Alle Texte im Panel laufen hier durch.
enum Format {
    static let locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
    /// Geschütztes Leerzeichen zwischen Zahl und Einheit.
    static let nbsp = "\u{00A0}"

    private static let gib = 1_073_741_824.0
    private static let mib = 1_048_576.0

    static func number(_ value: Double, digits: Int) -> String {
        let v = value.isFinite ? value : 0
        return v.formatted(.number.precision(.fractionLength(digits)).locale(locale))
    }

    /// 0...1 → „61 %"
    static func percent(_ fraction: Double) -> String {
        let v = fraction.isFinite ? fraction : 0
        return "\(Int((min(1, max(0, v)) * 100).rounded()))\(nbsp)%"
    }

    /// 0...1 → „61" (ohne Einheit, für große Zahlen)
    static func percentNumber(_ fraction: Double) -> String {
        let v = fraction.isFinite ? fraction : 0
        return "\(Int((min(1, max(0, v)) * 100).rounded()))"
    }

    /// Prozentwert (schon ×100) → „12,3 %"
    static func percentValue(_ percent: Double, digits: Int = 1) -> String {
        number(percent, digits: digits) + nbsp + "%"
    }

    // MARK: Arbeitsspeicher (binär, wie Aktivitätsanzeige)

    /// Bytes → GB-Zahl ohne Einheit, z. B. „11,48"
    static func gigabytes(_ bytes: UInt64, digits: Int = 2) -> String {
        number(Double(bytes) / gib, digits: digits)
    }

    /// Gesamt-RAM ohne Nachkommastellen, wenn glatt: „16"
    static func totalGigabytes(_ bytes: UInt64) -> String {
        let g = Double(bytes) / gib
        return abs(g - g.rounded()) < 0.05 ? number(g.rounded(), digits: 0) : number(g, digits: 1)
    }

    /// App-Speicher: „1,5 GB" bzw. „390 MB"
    static func appMemory(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b >= gib { return number(b / gib, digits: 1) + nbsp + "GB" }
        return number(b / mib, digits: 0) + nbsp + "MB"
    }

    // MARK: Datenträger / Datenmengen (dezimal, wie Finder)

    /// „20,8 GB", „1,00 TB", „156,2 KB"
    static func bytes(_ value: UInt64) -> String {
        bytes(Double(value))
    }

    static func bytes(_ value: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var v = max(0, value.isFinite ? value : 0)
        var i = 0
        while v >= 1000 && i < units.count - 1 { v /= 1000; i += 1 }
        if i == 0 { return number(v, digits: 0) + nbsp + "B" }
        return number(v, digits: v < 10 ? 2 : 1) + nbsp + units[i]
    }

    /// Bytes/s → „1,2 MB/s"
    static func byteRate(_ bytesPerSec: Double) -> String {
        bytes(bytesPerSec) + "/s"
    }

    /// Bytes/s → Bits/s, getrennt in Zahl und Einheit: („11,8", "kb/s")
    static func bitRate(_ bytesPerSec: Double) -> (value: String, unit: String) {
        var v = max(0, bytesPerSec.isFinite ? bytesPerSec : 0) * 8
        let units = ["b/s", "kb/s", "Mb/s", "Gb/s"]
        var i = 0
        while v >= 1000 && i < units.count - 1 { v /= 1000; i += 1 }
        return (number(v, digits: v >= 100 ? 0 : 1), units[i])
    }

    // MARK: Sonstiges

    /// „1,23 · 1,10 · 0,98"
    static func loadAverage(_ values: [Double]) -> String {
        guard !values.isEmpty else { return "–" }
        return values.prefix(3).map { number($0, digits: 2) }.joined(separator: " · ")
    }

    /// „7 Tage, 14 Stunden und 48 Minuten"
    static func uptime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0)) / 60
        let d = total / 1440, h = total / 60 % 24, m = total % 60
        var parts: [String] = []
        if d > 0 { parts.append("\(d) \(d == 1 ? tr("Tag", "day") : tr("Tage", "days"))") }
        if h > 0 { parts.append("\(h) \(h == 1 ? tr("Stunde", "hour") : tr("Stunden", "hours"))") }
        if m > 0 || parts.isEmpty { parts.append("\(m) \(m == 1 ? tr("Minute", "minute") : tr("Minuten", "minutes"))") }
        if parts.count == 1 { return parts[0] }
        return parts.dropLast().joined(separator: ", ") + tr(" und ", " and ") + parts.last!
    }

    /// Minuten → „1:20 h"
    static func hoursMinutes(_ minutes: Int) -> String {
        let m = max(0, minutes)
        return String(format: "%d:%02d", m / 60, m % 60) + nbsp + "h"
    }

    /// „31,2 °C"
    static func temperature(_ celsius: Double) -> String {
        number(celsius, digits: 1) + nbsp + "°C"
    }
}
