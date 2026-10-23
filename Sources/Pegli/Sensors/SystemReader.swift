import Foundation

/// Laufzeit seit Boot und thermischer Zustand.
enum SystemReader {
    /// Wanduhr-Sekunden seit Boot (inkl. Ruhezustand).
    static func uptime() -> TimeInterval {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &boot, &size, nil, 0) == 0, boot.tv_sec > 0 else {
            return ProcessInfo.processInfo.systemUptime
        }
        var now = timeval()
        gettimeofday(&now, nil)
        let seconds = Double(now.tv_sec - boot.tv_sec) + Double(now.tv_usec - boot.tv_usec) / 1_000_000
        return max(0, seconds)
    }

    static func thermal() -> ThermalLevel {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}
