import AppKit

// Einstieg: CLI-Testmodi zuerst, dann Single-Instance-Prüfung, dann die Menüleisten-App.
MainActor.assumeIsolated {
    let args = CommandLine.arguments

    if args.contains("--dump") {
        CLI.dump()
    }
    if let i = args.firstIndex(of: "--render") {
        guard i + 1 < args.count, !args[i + 1].hasPrefix("--") else {
            CLI.fail("Aufruf: Pegli --render <pfad.png> [--expanded] [--dark]")
        }
        CLI.render(to: args[i + 1], expanded: args.contains("--expanded"), dark: args.contains("--dark"))
    }

    // Läuft schon eine Instanz (z. B. per LaunchAgent gestartet)? Dann still beenden.
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: LoginItem.label)
        .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    if !others.isEmpty {
        FileHandle.standardError.write(Data("Pegli läuft bereits (PID \(others[0].processIdentifier)).\n".utf8))
        exit(0)
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
