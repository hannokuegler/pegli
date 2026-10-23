import SwiftUI

struct MemorySection: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject var state: PanelState
    @Environment(\.palette) private var palette

    var body: some View {
        let mem = monitor.snapshot.memory
        let expanded = state.expanded.contains(.memory)
        // Belegt = App-Speicher + fixiert + komprimiert (wie Aktivitätsanzeige).
        let app = mem.used > mem.wired + mem.compressed ? mem.used - mem.wired - mem.compressed : 0
        let total = Double(max(1, mem.total))
        SectionContainer(icon: "memorychip", title: tr("Speicher", "Memory"),
                         subtitle: tr("\(Format.gigabytes(mem.used)) von \(Format.totalGigabytes(mem.total))\(Format.nbsp)GB belegt",
                                       "\(Format.gigabytes(mem.used)) of \(Format.totalGigabytes(mem.total))\(Format.nbsp)GB used"),
                         tint: palette.purple, ring: mem.fraction,
                         expanded: expanded, onToggle: { state.animatedToggle(.memory) }) {
            BigValue(value: Format.percentNumber(mem.fraction), unit: "%")
        } content: {
            VStack(alignment: .leading, spacing: 5) {
                StackedBar(segments: [
                    (Double(app) / total, palette.purple),
                    (Double(mem.wired) / total, palette.purple.opacity(0.62)),
                    (Double(mem.compressed) / total, palette.purple.opacity(0.34)),
                ])
                HStack(spacing: 0) {
                    legend("Apps", app, palette.purple)
                    Spacer(minLength: 6)
                    legend(tr("Fixiert", "Wired"), mem.wired, palette.purple.opacity(0.62))
                    Spacer(minLength: 6)
                    legend(tr("Komprimiert", "Compressed"), mem.compressed, palette.purple.opacity(0.34))
                }
            }
        } details: {
            let (label, color, text) = pressureLabel(mem.pressure)
            Caption(text: tr("Speicherdruck", "Memory pressure")) {
                Text(verbatim: label).font(Fonts.smallBold).foregroundStyle(text)
            }
            BarGraph(values: monitor.pressureHistory, color: color).frame(height: 16)
            DetailRow(label: tr("Aktiv", "Active"), value: Format.gigabytes(mem.active) + Format.nbsp + "GB")
            DetailRow(label: tr("Auslagerung (Swap)", "Swap used"), value: Format.gigabytes(mem.swapUsed) + Format.nbsp + "GB")
            AppsHeader { state.onOpenExternal(.memory) }
            AppList(apps: monitor.snapshot.topMemoryApps, tint: palette.purple,
                    share: { Double($0.memoryBytes) / total }) { Format.appMemory($0.memoryBytes) }
        }
    }

    /// Legende unter dem Balken: Punkt, Bezeichnung, GB.
    private func legend(_ label: String, _ bytes: UInt64, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(verbatim: label).foregroundStyle(.secondary)
            Text(verbatim: Format.gigabytes(bytes, digits: 1)).fontWeight(.semibold).monospacedDigit()
        }
        .font(Fonts.small)
        .lineLimit(1)
        .fixedSize()
    }

    /// Bezeichnung, Balkenfarbe, Textfarbe.
    private func pressureLabel(_ p: MemoryPressure) -> (String, Color, Color) {
        switch p {
        case .normal: return ("Normal", palette.green, palette.green)
        case .warning: return (tr("Erhöht", "Elevated"), palette.yellow, palette.yellowText)
        case .critical: return (tr("Kritisch", "Critical"), palette.red, palette.red)
        }
    }
}
