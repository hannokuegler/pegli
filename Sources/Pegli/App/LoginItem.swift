import Foundation

/// Autostart über einen eigenen LaunchAgent (~/Library/LaunchAgents/local.hanno.pegli.plist).
/// isEnabled = Datei existiert. enable() schreibt nur die Datei; launchd lädt sie beim nächsten Login.
/// Kein `launchctl bootstrap` aus der App heraus — das würde eine zweite Instanz starten.
/// scripts/install.sh schreibt dieselbe Plist (Inhalt synchron halten).
enum LoginItem {
    static let label = "local.hanno.pegli"

    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    static var plistURL: URL {
        home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var logPath: String {
        home.appendingPathComponent("Library/Logs/Pegli.log").path
    }

    /// Bevorzugt die installierte Binary, sonst die gerade laufende.
    static var executablePath: String {
        let installed = home.appendingPathComponent("Applications/Pegli.app/Contents/MacOS/Pegli").path
        if FileManager.default.isExecutableFile(atPath: installed) { return installed }
        return Bundle.main.executablePath ?? CommandLine.arguments[0]
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func plist() -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            // Neustart nur nach Absturz, nicht nach „Beenden" (exit 0).
            "KeepAlive": ["SuccessfulExit": false],
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
            // Zeigt in Systemeinstellungen › Anmeldeobjekte den App-Namen statt eines anonymen Eintrags.
            "AssociatedBundleIdentifiers": [label],
            "StandardOutPath": logPath,
            "StandardErrorPath": logPath,
        ]
    }

    static func enable() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(atPath: (logPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: plist(), format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    static func disable() throws {
        if isEnabled { try FileManager.default.removeItem(at: plistURL) }
    }
}
