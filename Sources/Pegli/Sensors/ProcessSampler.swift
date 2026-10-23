import Foundation
import Darwin

/// Top-Apps nach CPU und Speicher (Helper-Prozesse zur äußersten .app zusammengefasst).
/// Nicht thread-sicher — nur von einer seriellen Queue benutzen.
final class ProcessSampler {
    /// Pro PID gemerkte Zuordnung und CPU-Zeit des letzten Aufrufs.
    private struct Entry {
        /// ri_proc_start_abstime — erkennt wiederverwendete PIDs.
        var start: UInt64
        /// user + system in Mach-Ticks.
        var cpuTicks: UInt64
        let key: String
        let name: String
        let bundlePath: String?
    }

    private struct Group {
        let name: String
        let bundlePath: String?
        var cpuTicks: UInt64 = 0
        var memory: UInt64 = 0
    }

    private var cache: [pid_t: Entry] = [:]
    /// Bundle-Pfad → Anzeigename.
    private var bundleNames: [String: String] = [:]
    private var pids: [pid_t] = []
    /// mach_absolute_time des letzten Aufrufs; 0 = noch keiner.
    private var lastTime: UInt64 = 0
    private var pathBuffer = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))

    init() {}

    func sample(limit: Int) -> (cpu: [AppUsage], memory: [AppUsage]) {
        let now = mach_absolute_time()
        let first = lastTime == 0
        let elapsedTicks = first ? 0 : now &- lastTime
        let previousTime = lastTime
        lastTime = now

        listPIDs()

        var newCache: [pid_t: Entry] = [:]
        newCache.reserveCapacity(pids.count)
        var groups: [String: Group] = [:]
        groups.reserveCapacity(pids.count / 2)
        var info = rusage_info_v4()

        let ownPID = getpid() // Pegli selbst steht im Fußbereich
        for pid in pids where pid > 0 && pid != ownPID {
            let ok = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) == 0
                }
            }
            guard ok else { continue } // fremd/geschützt/beendet → still überspringen

            let cpuTicks = info.ri_user_time &+ info.ri_system_time
            let start = info.ri_proc_start_abstime

            var entry: Entry
            var deltaTicks: UInt64 = 0
            if let old = cache[pid], old.start == start {
                entry = old
                deltaTicks = cpuTicks >= old.cpuTicks ? cpuTicks - old.cpuTicks : 0
            } else {
                entry = makeEntry(pid: pid, start: start)
                // Seit dem letzten Aufruf gestartet → gesamte CPU-Zeit zählt.
                if !first && start >= previousTime { deltaTicks = cpuTicks }
            }
            entry.cpuTicks = cpuTicks
            newCache[pid] = entry

            if var g = groups[entry.key] {
                g.cpuTicks &+= deltaTicks
                g.memory &+= info.ri_phys_footprint
                groups[entry.key] = g
            } else {
                groups[entry.key] = Group(name: entry.name, bundlePath: entry.bundlePath,
                                          cpuTicks: deltaTicks, memory: info.ri_phys_footprint)
            }
        }
        cache = newCache // beendete PIDs fallen raus

        // ri_user/system_time sind auf Apple Silicon Mach-Ticks, Wandzeit ist mach_absolute_time —
        // gleiche Einheit, also kürzt sich mach_timebase_info im Verhältnis heraus.
        let wall = Double(elapsedTicks)
        let apps = groups.map { key, g in
            AppUsage(id: key, name: g.name, bundlePath: g.bundlePath,
                     cpuPercent: wall > 0 ? Double(g.cpuTicks) / wall * 100 : 0,
                     memoryBytes: g.memory)
        }

        let cpu = first ? [] : top(apps.filter { $0.cpuPercent > 0 }, limit) { $0.cpuPercent > $1.cpuPercent }
        let memory = top(apps, limit) { $0.memoryBytes > $1.memoryBytes }
        return (cpu, memory)
    }

    // MARK: - Hilfen

    private func top(_ apps: [AppUsage], _ limit: Int, by order: (AppUsage, AppUsage) -> Bool) -> [AppUsage] {
        guard limit > 0 else { return [] }
        return Array(apps.sorted(by: order).prefix(limit))
    }

    private func listPIDs() {
        let estimate = proc_listallpids(nil, 0)
        let capacity = max(Int(estimate), 0) + 64
        if pids.count < capacity { pids = [pid_t](repeating: 0, count: capacity) }
        let n = pids.withUnsafeMutableBytes { buf in
            proc_listallpids(buf.baseAddress, Int32(buf.count))
        }
        // Puffer behalten, nur die gültigen PIDs nutzen.
        if n <= 0 { pids.removeAll(keepingCapacity: true); return }
        if Int(n) < pids.count { pids.removeSubrange(Int(n)...) }
    }

    private func makeEntry(pid: pid_t, start: UInt64) -> Entry {
        let path = pidPath(pid)

        if let bundle = path.flatMap(Self.outerBundle) {
            return Entry(start: start, cpuTicks: 0, key: bundle, name: bundleName(bundle), bundlePath: bundle)
        }
        // Ohne eigene .app (XPC-Dienste o. ä.) → der verantwortlichen App zuordnen.
        if let responsible = Self.responsiblePID, case let r = responsible(pid), r > 1, r != pid,
           let bundle = pidPath(r).flatMap(Self.outerBundle) {
            return Entry(start: start, cpuTicks: 0, key: bundle, name: bundleName(bundle), bundlePath: bundle)
        }

        let name: String
        if let path, let last = path.split(separator: "/").last {
            name = String(last)
        } else {
            name = processName(pid) ?? "pid \(pid)"
        }
        // Gleiche Binary (z. B. mehrere mdworker_shared) → eine Zeile.
        return Entry(start: start, cpuTicks: 0, key: "proc:\(path ?? name)", name: name, bundlePath: nil)
    }

    private func pidPath(_ pid: pid_t) -> String? {
        pathBuffer.withUnsafeMutableBufferPointer { buf in
            let len = proc_pidpath(pid, buf.baseAddress, UInt32(buf.count))
            return len > 0 ? String(cString: buf.baseAddress!) : nil
        }
    }

    /// Erstes ".app/" im Pfad = äußerstes Bundle.
    private static func outerBundle(_ path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        return String(path[..<path.index(range.lowerBound, offsetBy: 4)])
    }

    /// Private API aus libquarantine; fehlt das Symbol → nil, dann keine Zuordnung.
    private typealias ResponsibleFn = @convention(c) (pid_t) -> pid_t
    private static let responsiblePID: ResponsibleFn? = {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else { return nil }
        return unsafeBitCast(sym, to: ResponsibleFn.self)
    }()

    private func bundleName(_ bundlePath: String) -> String {
        if let cached = bundleNames[bundlePath] { return cached }
        let fallback = ((bundlePath as NSString).lastPathComponent as NSString).deletingPathExtension
        var name = fallback
        if let bundle = Bundle(path: bundlePath) {
            for key in ["CFBundleDisplayName", "CFBundleName"] {
                if let s = bundle.object(forInfoDictionaryKey: key) as? String, !s.isEmpty {
                    name = s
                    break
                }
            }
        }
        bundleNames[bundlePath] = name
        return name
    }

    private func processName(_ pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: 2 * Int(MAXCOMLEN) + 1)
        let len = proc_name(pid, &buf, UInt32(buf.count))
        return len > 0 ? String(cString: buf) : nil
    }
}
