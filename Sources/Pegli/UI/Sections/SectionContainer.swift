import SwiftUI

/// Karte eines Abschnitts: Kopfzeile (Ring/Symbol, Titel, Untertitel, große Zahl, Pfeil),
/// Inhalt, aufklappbare Details.
struct SectionContainer<Trailing: View, Content: View, Details: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let tint: Color
    /// Ringwert 0...1; nil → getönter Kreis ohne Ring.
    var ring: Double? = nil
    let expanded: Bool
    let onToggle: () -> Void
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content
    @ViewBuilder var details: () -> Details

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    RingBadge(icon: icon, tint: tint, value: ring)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: title).font(Fonts.title)
                        if let subtitle {
                            Text(verbatim: subtitle)
                                .font(Fonts.small)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 4)
                    trailing()
                    ExpandButton(expanded: expanded, action: onToggle)
                }
                content()
                if expanded {
                    VStack(alignment: .leading, spacing: 7) {
                        Hairline().padding(.bottom, 1)
                        details()
                    }
                    .transition(.opacity.combined(with: .offset(y: -4)))
                }
            }
        }
    }
}

/// Feine Linie innerhalb einer Karte (trennt Übersicht und Details).
struct Hairline: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Rectangle().fill(palette.hairline).frame(height: 0.5)
    }
}

extension PanelState {
    /// Auf-/Zuklappen mit sanfter Feder.
    func animatedToggle(_ section: PanelSection) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { toggle(section) }
    }
}
