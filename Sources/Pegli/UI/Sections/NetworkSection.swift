import SwiftUI

struct NetworkSection: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject var state: PanelState
    @Environment(\.palette) private var palette

    var body: some View {
        let net = monitor.snapshot.network
        let expanded = state.expanded.contains(.network)
        let subtitle = [net.interfaceName, net.localIP].compactMap { $0 }.joined(separator: " · ")
        SectionContainer(icon: "network", title: "Netzwerk",
                         subtitle: subtitle.isEmpty ? "Nicht verbunden" : subtitle,
                         tint: palette.cyan, ring: nil,
                         expanded: expanded, onToggle: { state.animatedToggle(.network) }) {
            EmptyView()
        } content: {
            HStack(spacing: 6) {
                rate("Empfangen", arrow: "arrow.down", net.downBytesPerSec, palette.cyan)
                rate("Gesendet", arrow: "arrow.up", net.upBytesPerSec, palette.indigo)
            }
        } details: {
            let top = max(1, (monitor.downHistory + monitor.upHistory).max() ?? 1)
            let peak = Format.bitRate(top)
            AreaGraph(values: monitor.downHistory, maxValue: top, color: palette.cyan,
                      secondary: monitor.upHistory, secondaryColor: palette.indigo)
                .frame(height: 32)
            HStack(spacing: 12) {
                legend(palette.cyan, "Empfangen")
                legend(palette.indigo, "Gesendet")
                Spacer()
                Text(verbatim: "Spitze \(peak.value)\(Format.nbsp)\(peak.unit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(Fonts.small)
            DetailRow(label: "Schnittstelle", value: net.interfaceName ?? "–")
            DetailRow(label: "Lokale IP", value: net.localIP ?? "–")
            DetailRow(label: "Seit Systemstart",
                      value: "↓ \(Format.bytes(net.totalDown)) · ↑ \(Format.bytes(net.totalUp))")
            MoreInfoRow { state.onOpenExternal(.network) }
        }
    }

    /// Kachel: Pfeil im Kreis, große Zahl + Einheit, Bezeichnung.
    private func rate(_ label: String, arrow: String, _ bytesPerSec: Double, _ color: Color) -> some View {
        let r = Format.bitRate(bytesPerSec)
        return HStack(spacing: 7) {
            Image(systemName: arrow)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .background(Circle().fill(color.opacity(0.16)))
            BigValue(value: r.value, unit: r.unit, font: Fonts.valueMedium)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.track.opacity(0.6)))
        .help(label)
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 10, height: 3)
            Text(verbatim: label).foregroundStyle(.secondary)
        }
    }
}
