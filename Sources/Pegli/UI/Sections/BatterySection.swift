import SwiftUI

struct BatterySection: View {
    let battery: BatteryInfo
    @ObservedObject var state: PanelState
    @Environment(\.palette) private var palette

    var body: some View {
        let expanded = state.expanded.contains(.battery)
        SectionContainer(icon: icon, title: "Akku", subtitle: status, tint: tint, ring: battery.level,
                         expanded: expanded, onToggle: { state.animatedToggle(.battery) }) {
            BigValue(value: Format.percentNumber(battery.level), unit: "%")
        } content: {
            EmptyView()
        } details: {
            DetailRow(label: "Ladezyklen", value: battery.cycleCount.map { "\($0)" } ?? "–")
            DetailRow(label: "Zustand", value: battery.health.map { Format.percent($0) } ?? "–")
            DetailRow(label: "Temperatur", value: battery.temperatureC.map { Format.temperature($0) } ?? "–")
            DetailRow(label: "Netzteil", value: battery.adapterWatts.map { "\($0)\(Format.nbsp)W" }
                      ?? (battery.isPluggedIn ? "Angeschlossen" : "Nicht angeschlossen"))
            MoreInfoRow { state.onOpenExternal(.battery) }
        }
    }

    /// Grün, knapp → Orange, fast leer → Rot (nur ohne Netzteil).
    private var tint: Color {
        if battery.isPluggedIn { return palette.green }
        if battery.level < 0.1 { return palette.red }
        if battery.level < 0.2 { return palette.orange }
        return palette.green
    }

    private var icon: String {
        if battery.isCharging || battery.isPluggedIn { return "bolt.fill" }
        switch battery.level {
        case ..<0.13: return "battery.0percent"
        case ..<0.38: return "battery.25percent"
        case ..<0.63: return "battery.50percent"
        case ..<0.88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var status: String {
        if battery.isCharged || (battery.isPluggedIn && !battery.isCharging && battery.level >= 0.99) {
            return "Vollständig geladen"
        }
        if battery.isCharging {
            if let m = battery.minutesRemaining { return "Lädt – voll in \(Format.hoursMinutes(m))" }
            return "Wird geladen …"
        }
        if battery.isPluggedIn { return "Am Netzteil, lädt nicht" }
        if let m = battery.minutesRemaining { return "Akkubetrieb – noch \(Format.hoursMinutes(m))" }
        return "Restzeit wird berechnet …"
    }
}
