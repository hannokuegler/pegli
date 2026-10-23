import Foundation

/// Arbeitsspeicher wie in der Aktivitätsanzeige, plus Swap und Speicherdruck.
enum MemoryReader {
    static func read() -> MemoryInfo {
        let total = ProcessInfo.processInfo.physicalMemory
        let page = UInt64(vm_kernel_page_size)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        var used: UInt64 = 0, active: UInt64 = 0, compressed: UInt64 = 0, wired: UInt64 = 0
        if kr == KERN_SUCCESS {
            // App-Speicher = anonyme Seiten ohne purgeable.
            let anon = UInt64(stats.internal_page_count)
            let purgeable = UInt64(stats.purgeable_count)
            let app = anon > purgeable ? anon - purgeable : 0
            wired = UInt64(stats.wire_count) * page
            compressed = UInt64(stats.compressor_page_count) * page
            active = UInt64(stats.active_count) * page
            used = min(total, app * page + wired + compressed)
        }

        let (pressure, fraction) = pressureInfo()
        return MemoryInfo(
            used: used,
            total: total,
            active: active,
            compressed: compressed,
            wired: wired,
            swapUsed: swapUsed(),
            pressure: pressure,
            pressureFraction: fraction
        )
    }

    private static func swapUsed() -> UInt64 {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 else { return 0 }
        return swap.xsu_used
    }

    private static func pressureInfo() -> (MemoryPressure, Double) {
        let pressure: MemoryPressure
        switch sysctlInt32("kern.memorystatus_vm_pressure_level") {
        case 4: pressure = .critical
        case 2: pressure = .warning
        default: pressure = .normal
        }
        // memorystatus_level = Prozent frei.
        let fraction: Double
        if let level = sysctlInt32("kern.memorystatus_level") {
            fraction = min(1, max(0, Double(100 - level) / 100))
        } else {
            fraction = 0
        }
        return (pressure, fraction)
    }

    private static func sysctlInt32(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
    }
}
