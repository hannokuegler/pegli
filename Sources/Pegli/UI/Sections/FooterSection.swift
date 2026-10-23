import SwiftUI

/// Dezenter Fußbereich ohne Karte: Uptime + eigene Auslastung.
struct FooterSection: View {
    let uptime: TimeInterval
    let selfUsage: SelfUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            item(icon: "clock.arrow.circlepath", title: "Uptime") {
                Text(verbatim: Format.uptime(uptime))
            }
            item(icon: "gauge.with.dots.needle.33percent", title: "Eigenlast") {
                Text(verbatim: "\(Format.percentValue(selfUsage.cpuPercent)) CPU · \(Format.number(Double(selfUsage.memoryBytes) / 1_048_576, digits: 0))\(Format.nbsp)MB")
                    .monospacedDigit()
            }
        }
        .font(Fonts.small)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func item<V: View>(icon: String, title: String, @ViewBuilder value: () -> V) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 12)
            Text(verbatim: title).fontWeight(.semibold)
            Spacer(minLength: 8)
            value().lineLimit(1)
        }
    }
}
