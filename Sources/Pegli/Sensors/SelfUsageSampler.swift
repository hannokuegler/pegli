import Darwin

/// CPU und Speicher des eigenen Prozesses.
final class SelfUsageSampler {
    private var lastCPUNanos: UInt64 = 0
    private var lastWallNanos: UInt64 = 0
    /// ri_user_time/ri_system_time sind Mach-Ticks (auf Apple Silicon ≠ ns).
    private let numer: UInt64
    private let denom: UInt64

    init() {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        numer = UInt64(max(tb.numer, 1))
        denom = UInt64(max(tb.denom, 1))
    }

    func sample() -> SelfUsage {
        var info = rusage_info_v4()
        let ok = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
            }
        } == 0
        guard ok else { return SelfUsage(cpuPercent: 0, memoryBytes: 0) }

        let ticks = info.ri_user_time + info.ri_system_time
        let cpuNanos = ticks / denom * numer + ticks % denom * numer / denom
        let wallNanos = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)

        var percent = 0.0
        if lastWallNanos != 0, wallNanos > lastWallNanos, cpuNanos >= lastCPUNanos {
            percent = Double(cpuNanos - lastCPUNanos) / Double(wallNanos - lastWallNanos) * 100
        }
        lastCPUNanos = cpuNanos
        lastWallNanos = wallNanos
        return SelfUsage(cpuPercent: percent, memoryBytes: info.ri_phys_footprint)
    }
}
