import SwiftUI

struct CPUSection: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject var state: PanelState
    @Environment(\.palette) private var palette

    var body: some View {
        let cpu = monitor.snapshot.cpu
        let expanded = state.expanded.contains(.cpu)
        let subtitle = cpu.perCore.isEmpty ? tr("Auslastung", "Usage") : tr("\(cpu.perCore.count) Kerne", "\(cpu.perCore.count) cores")
        SectionContainer(icon: "cpu", title: tr("Prozessor", "CPU"), subtitle: subtitle, tint: palette.blue, ring: cpu.usage,
                         expanded: expanded, onToggle: { state.animatedToggle(.cpu) }) {
            BigValue(value: Format.percentNumber(cpu.usage), unit: "%")
        } content: {
            AreaGraph(values: monitor.cpuHistory, color: palette.blue).frame(height: 30)
        } details: {
            HStack(spacing: 6) {
                share(tr("Benutzer", "User"), cpu.user, color: palette.blue)
                share("System", cpu.system, color: palette.teal)
                share(tr("Leerlauf", "Idle"), max(0, 1 - cpu.usage), color: Color.secondary.opacity(0.5))
            }
            DetailRow(label: tr("Durchschnittslast", "Load average"), value: Format.loadAverage(cpu.loadAverage))
            if !cpu.perCore.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Caption(tr("Kerne (\(cpu.perCore.count))", "Cores (\(cpu.perCore.count))"))
                    CoreBars(values: cpu.perCore, tint: palette.blue, tint2: palette.teal)
                }
            }
            AppsHeader { state.onOpenExternal(.cpu) }
            AppList(apps: monitor.snapshot.topCPUApps, tint: palette.blue,
                    share: { min(1, $0.cpuPercent / 100) }) { Format.percentValue($0.cpuPercent) }
        }
    }

    /// Kleine Kachel: Punkt + Bezeichnung, darunter Wert.
    private func share(_ label: String, _ value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(verbatim: label).font(Fonts.small).foregroundStyle(.secondary)
            }
            Text(verbatim: Format.percentValue(value * 100))
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.track.opacity(0.6)))
    }
}
