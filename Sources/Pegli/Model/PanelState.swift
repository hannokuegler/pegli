import Foundation

enum PanelSection: String, CaseIterable, Sendable {
    case cpu, memory, disk, network, battery, thermal
}

/// Zustand und Aktionen des Panels. Die App (AppDelegate) setzt die Closures.
@MainActor
final class PanelState: ObservableObject {
    /// Angepinnt = Panel bleibt offen, auch wenn man daneben klickt.
    @Published var isPinned = false
    @Published var launchAtLogin = false
    /// Aufgeklappte Detailbereiche (Pfeil-Button je Abschnitt). Wird gespeichert.
    @Published var expanded: Set<PanelSection> {
        didSet { UserDefaults.standard.set(expanded.map(\.rawValue), forKey: "expanded") }
    }

    var onTogglePin: () -> Void = {}
    var onClose: () -> Void = {}
    var onQuit: () -> Void = {}
    var onSetLaunchAtLogin: (Bool) -> Void = { _ in }
    /// „Weitere Informationen ↗": öffnet passende System-App (Aktivitätsanzeige, Festplattendienstprogramm, Batterie-Einstellungen …).
    var onOpenExternal: (PanelSection) -> Void = { _ in }

    init() {
        let raw = UserDefaults.standard.stringArray(forKey: "expanded") ?? []
        expanded = Set(raw.compactMap(PanelSection.init(rawValue:)))
    }

    func toggle(_ section: PanelSection) {
        if expanded.contains(section) { expanded.remove(section) } else { expanded.insert(section) }
    }
}
