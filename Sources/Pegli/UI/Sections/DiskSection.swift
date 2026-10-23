import SwiftUI

struct DiskSection: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject var state: PanelState
    @AppStorage("showOtherDisks") private var showOthers = true
    @Environment(\.palette) private var palette

    var body: some View {
        let disks = monitor.snapshot.disks
        let boot = disks.first(where: \.isBoot) ?? disks.first
        let others = disks.filter { $0.id != boot?.id }
        let expanded = state.expanded.contains(.disk)
        SectionContainer(icon: "internaldrive", title: tr("Laufwerk", "Disk"),
                         subtitle: boot.map(availability) ?? tr("Kein Laufwerk gefunden", "No disk found"),
                         tint: palette.orange, ring: boot?.usedFraction ?? 0,
                         expanded: expanded, onToggle: { state.animatedToggle(.disk) }) {
            if let boot { BigValue(value: Format.percentNumber(boot.usedFraction), unit: "%") }
        } content: {
            if let boot { UsageBar(value: boot.usedFraction, tint: palette.orange) }
            if !others.isEmpty {
                othersHeader(count: others.count)
                if showOthers {
                    VStack(spacing: 8) {
                        ForEach(others) { row($0) }
                    }
                    .transition(.opacity)
                }
            }
        } details: {
            let io = monitor.snapshot.diskIO
            DetailRow(label: tr("Lesen", "Read"), value: Format.byteRate(io.readBytesPerSec), dot: palette.orange)
            DetailRow(label: tr("Schreiben", "Write"), value: Format.byteRate(io.writeBytesPerSec), dot: palette.yellow)
            MoreInfoRow { state.onOpenExternal(.disk) }
        }
    }

    /// „376,0 GB von 494,3 GB frei"
    private func availability(_ d: DiskInfo) -> String {
        tr("\(Format.bytes(d.available)) von \(Format.bytes(d.total)) frei",
           "\(Format.bytes(d.available)) of \(Format.bytes(d.total)) free")
    }

    private func othersHeader(count: Int) -> some View {
        HStack(spacing: 6) {
            Caption(tr("Andere Laufwerke (\(count))", "Other disks (\(count))"))
            ExpandButton(expanded: showOthers, size: 16) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { showOthers.toggle() }
            }
        }
        .padding(.top, 1)
    }

    /// Weiteres Volume: Name + Prozent, Balken, frei.
    private func row(_ d: DiskInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.orange)
                Text(verbatim: d.name).font(Fonts.bodyBold).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 6)
                Text(verbatim: availability(d)).font(Fonts.small).foregroundStyle(.secondary).lineLimit(1)
                Text(verbatim: Format.percent(d.usedFraction))
                    .font(Fonts.bodyBold.monospacedDigit())
            }
            UsageBar(value: d.usedFraction, height: 3.5, tint: palette.orange)
        }
    }
}
