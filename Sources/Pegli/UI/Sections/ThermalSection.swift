import SwiftUI

struct ThermalSection: View {
    let level: ThermalLevel
    @ObservedObject var state: PanelState
    @Environment(\.palette) private var palette

    var body: some View {
        let expanded = state.expanded.contains(.thermal)
        SectionContainer(icon: "thermometer.medium", title: "Temperatur", subtitle: subtitle, tint: color,
                         ring: Double(level.rawValue + 1) / Double(ThermalLevel.allCases.count),
                         expanded: expanded, onToggle: { state.animatedToggle(.thermal) }) {
            Text(verbatim: label)
                .font(Fonts.bodyBold)
                .foregroundStyle(level == .fair ? palette.yellowText : color)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(color.opacity(0.15)))
        } content: {
            SegmentBar(filled: level.rawValue + 1, color: color)
                .animation(.easeOut(duration: 0.3), value: level)
        } details: {
            Text(verbatim: "Auf Apple Silicon gibt macOS keine Sensorwerte frei, sondern nur den thermischen Zustand (normal, leicht erhöht, hoch, kritisch). Ab „hoch“ drosselt das System die Leistung.")
                .font(Fonts.small)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var color: Color {
        switch level {
        case .nominal: return palette.green
        case .fair: return palette.yellow
        case .serious: return palette.orange
        case .critical: return palette.red
        }
    }

    private var label: String {
        switch level {
        case .nominal: return "Normal"
        case .fair: return "Erhöht"
        case .serious: return "Hoch"
        case .critical: return "Kritisch"
        }
    }

    private var subtitle: String {
        level.rawValue >= ThermalLevel.serious.rawValue ? "System drosselt die Leistung" : "Thermischer Zustand"
    }
}
