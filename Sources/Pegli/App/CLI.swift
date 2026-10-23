import AppKit
import Combine
import SwiftUI

/// Testmodi ohne Menüleiste: `--dump` und `--render`. Beide beenden den Prozess.
enum CLI {
    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }

    // MARK: - --dump

    /// Zwei Messungen im Abstand von 1 s (Raten brauchen eine Differenz), die zweite ausgeben.
    static func dump() -> Never {
        let sampler = Sampler()
        _ = sampler.sample(detailed: true)
        Thread.sleep(forTimeInterval: 1)
        print(describe(sampler.sample(detailed: true)))
        exit(0)
    }

    static func describe(_ s: Snapshot) -> String {
        var out: [String] = []
        func line(_ text: String) { out.append(text) }

        line("CPU")
        line("  Gesamt     \(pct(s.cpu.usage))  (User \(pct(s.cpu.user)), System \(pct(s.cpu.system)))")
        line("  Kerne      \(s.cpu.perCore.map { pct($0) }.joined(separator: " "))")
        line("  Load       \(s.cpu.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " / "))")

        let m = s.memory
        line("Speicher")
        line("  Belegt     \(bytes(m.used)) von \(bytes(m.total)) (\(pct(m.fraction)))")
        line("  Aktiv      \(bytes(m.active)), Wired \(bytes(m.wired)), Komprimiert \(bytes(m.compressed))")
        line("  Swap       \(bytes(m.swapUsed))")
        line("  Druck      \(m.pressure) (\(pct(m.pressureFraction)))")

        line("Festplatten")
        if s.disks.isEmpty { line("  (keine)") }
        for d in s.disks {
            line("  \(d.isBoot ? "*" : " ") \(d.name) [\(d.id)]  \(bytes(d.used)) von \(bytes(d.total)) belegt (\(pct(d.usedFraction))), frei \(bytes(d.available))")
        }
        line("  I/O        lesen \(rate(s.diskIO.readBytesPerSec)), schreiben \(rate(s.diskIO.writeBytesPerSec))")

        let n = s.network
        line("Netzwerk")
        line("  Interface  \(n.interfaceName ?? "–"), IP \(n.localIP ?? "–")")
        line("  Rate       ↓ \(rate(n.downBytesPerSec))  ↑ \(rate(n.upBytesPerSec))")
        line("  Gesamt     ↓ \(bytes(n.totalDown))  ↑ \(bytes(n.totalUp))")

        line("Akku")
        if let b = s.battery {
            line("  Stand      \(pct(b.level))  laden=\(b.isCharging) angesteckt=\(b.isPluggedIn) voll=\(b.isCharged)")
            line("  Restzeit   \(b.minutesRemaining.map { "\($0 / 60) h \($0 % 60) min" } ?? "–")")
            line("  Zyklen     \(b.cycleCount.map(String.init) ?? "–"), Zustand \(b.health.map { pct($0) } ?? "–")")
            line("  Temperatur \(b.temperatureC.map { String(format: "%.1f °C", $0) } ?? "–"), Netzteil \(b.adapterWatts.map { "\($0) W" } ?? "–")")
        } else {
            line("  (kein Akku)")
        }

        line("System")
        line("  Thermik    \(s.thermal)")
        line("  Laufzeit   \(duration(s.uptime))")
        line("  Pegli      CPU \(String(format: "%.1f %%", s.selfUsage.cpuPercent)), Speicher \(bytes(s.selfUsage.memoryBytes))")

        line("Top-Apps CPU")
        appLines(s.topCPUApps).forEach(line)
        line("Top-Apps Speicher")
        appLines(s.topMemoryApps).forEach(line)

        return out.joined(separator: "\n")
    }

    private static func appLines(_ apps: [AppUsage]) -> [String] {
        if apps.isEmpty { return ["  (keine)"] }
        return apps.map {
            let name = $0.name.padding(toLength: 28, withPad: " ", startingAt: 0)
            return "  \(name) \(String(format: "%6.1f %%", $0.cpuPercent))  \(bytes($0.memoryBytes))  \($0.bundlePath ?? $0.id)"
        }
    }

    private static func pct(_ v: Double) -> String { String(format: "%.0f %%", v * 100) }

    private static func bytes(_ v: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: v), countStyle: .memory)
    }

    private static func rate(_ v: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(max(0, v)), countStyle: .file) + "/s"
    }

    private static func duration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        return "\(m / 1440) d \(m / 60 % 24) h \(m % 60) min"
    }

    // MARK: - --render

    /// Echter Monitor, warten bis echte Messwerte da sind, dann PopoverView als PNG (Scale 2).
    @MainActor
    static func render(to path: String, expanded: Bool, dark: Bool) -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        app.appearance = appearance

        let monitor = Monitor()
        let state = PanelState()
        let previousExpanded = state.expanded
        if expanded { state.expanded = Set(PanelSection.allCases) }

        // Echte Messungen zählen (jede landet in cpuHistory), ein paar für die Graphen abwarten.
        monitor.detailed = true
        let previousInterval = monitor.interval
        monitor.interval = 1
        monitor.start()
        let deadline = Date().addingTimeInterval(12)
        while monitor.cpuHistory.count < 6 && Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        let updates = monitor.cpuHistory.count + 1

        let background = dark ? Color(red: 0.16, green: 0.16, blue: 0.17) : Color(red: 0.93, green: 0.93, blue: 0.94)
        let content = PopoverView(monitor: monitor, state: state)
            .background(background)
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        var image: CGImage?
        appearance?.performAsCurrentDrawingAppearance { image = renderer.cgImage }

        if expanded { state.expanded = previousExpanded }
        UserDefaults.standard.set(previousInterval, forKey: "interval")

        guard let cg = image,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
        else { fail("Rendern fehlgeschlagen") }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            fail("Schreiben fehlgeschlagen: \(error.localizedDescription)")
        }
        print("\(path) (\(cg.width)×\(cg.height) px, \(updates - 1) Messungen)")
        exit(0)
    }
}
