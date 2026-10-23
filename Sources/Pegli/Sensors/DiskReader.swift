import Foundation

/// Gemountete Volumes mit Belegung. Teuer genug, dass der Sampler nur alle ~10 Ticks fragt.
enum DiskReader {
    private static let keys: [URLResourceKey] = [
        .volumeNameKey,
        .volumeLocalizedNameKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeIsBrowsableKey,
    ]

    /// Pfad-Präfixe von System-/APFS-Hilfsvolumes und Simulator-Runtimes.
    private static let hiddenPrefixes = [
        "/System/Volumes/",
        "/Library/Developer/CoreSimulator",
        "/private/var/vm",
        "/dev/",
    ]

    static func volumes() -> [DiskInfo] {
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        var boot: DiskInfo?
        var others: [DiskInfo] = []
        var seen = Set<String>()

        for url in urls {
            let path = url.path
            let isBoot = path == "/"
            if !isBoot && isHidden(path) { continue }
            guard seen.insert(path).inserted,
                  let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if !isBoot && values.volumeIsBrowsable == false { continue }

            guard let total = values.volumeTotalCapacity, total > 0 else { continue }
            // Wie Finder: „wichtige Nutzung" zählt löschbaren Speicher als frei.
            let available: Int64
            if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
                available = important
            } else {
                available = Int64(values.volumeAvailableCapacity ?? 0)
            }

            let name = values.volumeLocalizedName ?? values.volumeName ?? url.lastPathComponent
            let info = DiskInfo(
                id: path,
                name: name.isEmpty ? path : name,
                total: UInt64(total),
                available: UInt64(max(0, min(available, Int64(total)))),
                isBoot: isBoot
            )
            if isBoot { boot = info } else { others.append(info) }
        }

        others.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return (boot.map { [$0] } ?? []) + others
    }

    private static func isHidden(_ path: String) -> Bool {
        if path == "/dev" || hiddenPrefixes.contains(where: { path.hasPrefix($0) }) { return true }
        // Time-Machine-Snapshots und lokale Backups.
        if path.contains(".timemachine") || path.hasPrefix("/Volumes/com.apple.TimeMachine") { return true }
        return false
    }
}
