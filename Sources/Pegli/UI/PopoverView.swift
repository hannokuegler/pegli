import SwiftUI
import AppKit

/// Inhalt des Menüleisten-Panels. Ohne eigenen Hintergrund (NSPopover liefert Vibrancy).
struct PopoverView: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject var state: PanelState
    // @StateObject statt @State: @State ist im aktuellen SDK ein Makro, das mit den Command Line Tools fehlt.
    @StateObject private var layout = LayoutBox()

    static let width: CGFloat = 306

    var body: some View {
        Group {
            // ScrollView nur bei Überlänge – sonst passt sich die Höhe dem Inhalt an.
            if layout.inWindow && layout.contentHeight > maxHeight {
                ScrollView(.vertical, showsIndicators: true) { content }
                    .frame(height: maxHeight)
            } else {
                content
            }
        }
        .frame(width: Self.width)
        .background(WindowProbe { layout.inWindow = $0 }.frame(width: 0, height: 0))
        .modifier(PaletteProvider())
    }

    private var maxHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 900) - 80
    }

    private var content: some View {
        let s = monitor.snapshot
        return VStack(spacing: 6) {
            PanelHeader(monitor: monitor, state: state, interactive: layout.inWindow)
            if let battery = s.battery {
                BatterySection(battery: battery, state: state)
            }
            CPUSection(monitor: monitor, state: state)
            MemorySection(monitor: monitor, state: state)
            DiskSection(monitor: monitor, state: state)
            NetworkSection(monitor: monitor, state: state)
            ThermalSection(level: s.thermal, state: state)
            FooterSection(uptime: s.uptime, selfUsage: s.selfUsage)
                .padding(.top, 2)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 9)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
            if abs(layout.contentHeight - h) > 0.5 { layout.contentHeight = h }
        }
    }
}

/// Gemessene Inhaltshöhe (entscheidet über ScrollView) und ob ein Fenster existiert.
final class LayoutBox: ObservableObject {
    @Published var contentHeight: CGFloat = 0
    /// false beim Rendern per ImageRenderer → keine AppKit-Controls (ScrollView, Menu), die dort leer/als Platzhalter erscheinen.
    @Published var inWindow = false
}

/// Meldet, ob die View in einem Fenster hängt. Wird von ImageRenderer nie instanziiert.
private struct WindowProbe: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: ProbeView, context: Context) { view.onChange = onChange }

    final class ProbeView: NSView {
        var onChange: ((Bool) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let hasWindow = window != nil
            DispatchQueue.main.async { [weak self] in self?.onChange?(hasWindow) }
        }
    }
}

/// Kopfzeile: Mini-Icon mit Live-Balken, „Pegli" + Kurzstatus, rechts Pin/Zahnrad/X.
struct PanelHeader: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject var state: PanelState
    var interactive = true
    @Environment(\.palette) private var palette

    var body: some View {
        let s = monitor.snapshot
        let (text, color) = status(s)
        HStack(spacing: 8) {
            MiniMark(values: [s.cpu.usage, s.memory.fraction,
                              (s.disks.first(where: \.isBoot) ?? s.disks.first)?.usedFraction ?? 0],
                     tints: [palette.blue, palette.purple, palette.orange])
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Pegli").font(.system(size: 13, weight: .bold))
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 5, height: 5)
                    Text(verbatim: text).font(Fonts.small).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            PanelToolbar(monitor: monitor, state: state, interactive: interactive)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 1)
    }

    /// Wichtigster Hinweis zuerst, sonst Entwarnung.
    private func status(_ s: Snapshot) -> (String, Color) {
        if s.thermal.rawValue >= ThermalLevel.serious.rawValue { return ("Temperatur hoch – System drosselt", palette.red) }
        if s.memory.pressure == .critical { return ("Speicherdruck kritisch", palette.red) }
        if let b = s.battery, !b.isPluggedIn, b.level < 0.1 { return ("Akku fast leer", palette.red) }
        if s.memory.pressure == .warning { return ("Speicherdruck erhöht", palette.yellow) }
        if s.cpu.usage > 0.85 { return ("Hohe CPU-Last", palette.orange) }
        if s.thermal == .fair { return ("Temperatur leicht erhöht", palette.yellow) }
        return ("Alles im grünen Bereich", palette.green)
    }
}

/// Kleines App-Zeichen: dunkle Kachel mit drei Live-Balken (CPU, Speicher, Laufwerk).
struct MiniMark: View {
    let values: [Double]
    let tints: [Color]

    var body: some View {
        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
            .fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.11)], startPoint: .top, endPoint: .bottom))
            .frame(width: 24, height: 24)
            .overlay {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<min(values.count, tints.count), id: \.self) { i in
                        let v = values[i].isFinite ? min(1, max(0, values[i])) : 0
                        ZStack(alignment: .bottom) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(tints[i].gradient).frame(height: max(3.5, 14 * v))
                        }
                        .frame(width: 3.5, height: 14)
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6.5, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
            .animation(.easeOut(duration: 0.35), value: values)
    }
}

/// Pin, Zahnrad-Menü, Schließen – runde, dezente Buttons.
struct PanelToolbar: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject var state: PanelState
    /// false → Zahnrad als reines Bild (ImageRenderer kann kein Menu zeichnen).
    var interactive = true
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 5) {
            Button { state.onTogglePin() } label: {
                CircleIcon(systemName: state.isPinned ? "pin.fill" : "pin", size: 22, active: state.isPinned)
            }
            .help(state.isPinned ? "Lösen" : "Anheften")

            if interactive {
                settingsMenu
            } else {
                CircleIcon(systemName: "gearshape", size: 22)
            }

            Button { state.onClose() } label: {
                CircleIcon(systemName: "xmark", size: 22)
            }
            .help("Schließen")
        }
        .buttonStyle(.plain)
    }

    private var settingsMenu: some View {
        Menu {
            Picker("Aktualisierung", selection: $monitor.interval) {
                Text(verbatim: "Jede Sekunde").tag(TimeInterval(1))
                Text(verbatim: "Alle 2 Sekunden").tag(TimeInterval(2))
                Text(verbatim: "Alle 5 Sekunden").tag(TimeInterval(5))
            }
            .pickerStyle(.inline)
            Divider()
            Toggle("Beim Anmelden starten", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.launchAtLogin = $0; state.onSetLaunchAtLogin($0) }
            ))
            Divider()
            Button("Pegli beenden") { state.onQuit() }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "gearshape")
        }
        // Borderless-Menü zeichnet nur das Symbol; Kreis kommt von außen (wie CircleIcon).
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .font(.system(size: 22 * 0.44, weight: .semibold))
        .foregroundStyle(.secondary)
        .fixedSize()
        .frame(width: 22, height: 22)
        .background(Circle().fill(palette.button))
        .contentShape(Circle())
        .help("Einstellungen")
    }
}
