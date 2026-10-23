import Foundation
import IOKit

/// Lese-/Schreibrate aller Blockgeräte aus den IOBlockStorageDriver-Statistiken.
/// Nur von einer seriellen Queue benutzen.
final class DiskIOSampler {
    /// Letzte Zähler je Treiber (Registry-ID), damit an-/abgesteckte Platten keine Sprünge erzeugen.
    private var previous: [UInt64: (read: UInt64, write: UInt64)] = [:]
    private var lastTime: UInt64 = 0

    init() {}

    func sample() -> DiskIO {
        let now = clock_gettime_nsec_np(CLOCK_MONOTONIC)
        let current = readCounters()

        var readDelta: UInt64 = 0
        var writeDelta: UInt64 = 0
        for (id, c) in current {
            guard let p = previous[id] else { continue }
            if c.read >= p.read { readDelta += c.read - p.read }
            if c.write >= p.write { writeDelta += c.write - p.write }
        }

        let elapsed = lastTime == 0 ? 0 : Double(now &- lastTime) / 1e9
        previous = current
        lastTime = now

        guard elapsed > 0.05 else { return DiskIO(readBytesPerSec: 0, writeBytesPerSec: 0) }
        return DiskIO(readBytesPerSec: Double(readDelta) / elapsed,
                      writeBytesPerSec: Double(writeDelta) / elapsed)
    }

    private func readCounters() -> [UInt64: (read: UInt64, write: UInt64)] {
        var result: [UInt64: (read: UInt64, write: UInt64)] = [:]
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"),
                                           &iterator) == KERN_SUCCESS else { return result }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var id: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(service, &id) == KERN_SUCCESS,
                  let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString,
                                                              kCFAllocatorDefault, 0)?
                      .takeRetainedValue() as? [String: Any] else { continue }
            let read = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            let write = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            result[id] = (read, write)
        }
        return result
    }
}
