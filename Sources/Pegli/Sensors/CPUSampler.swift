import Darwin

/// CPU-Last aus den Tick-Zählern des Kernels, als Delta zum letzten Aufruf.
final class CPUSampler {
    /// Letzte Ticks je Kern: user, system, idle, nice.
    private var previous: [[UInt32]] = []

    init() {}

    func sample() -> CPUInfo {
        let current = Self.readTicks()
        defer { previous = current }

        var perCore = [Double](repeating: 0, count: current.count)
        var sumUser: UInt64 = 0, sumSystem: UInt64 = 0, sumTotal: UInt64 = 0

        if previous.count == current.count {
            for i in current.indices {
                let now = current[i], old = previous[i]
                // &- fängt Überlauf der 32-Bit-Zähler ab.
                let user = UInt64(now[0] &- old[0])
                let system = UInt64(now[1] &- old[1])
                let idle = UInt64(now[2] &- old[2])
                let nice = UInt64(now[3] &- old[3])
                let busy = user + system + nice
                let total = busy + idle
                perCore[i] = total == 0 ? 0 : Double(busy) / Double(total)
                sumUser += user + nice
                sumSystem += system
                sumTotal += total
            }
        }

        let user = sumTotal == 0 ? 0 : Double(sumUser) / Double(sumTotal)
        let system = sumTotal == 0 ? 0 : Double(sumSystem) / Double(sumTotal)
        return CPUInfo(
            usage: min(1, user + system),
            user: user,
            system: system,
            perCore: perCore,
            loadAverage: Self.loadAverage()
        )
    }

    private static func readTicks() -> [[UInt32]] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard kr == KERN_SUCCESS, let info else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(cpuCount)).map { cpu in
            let base = cpu * stride
            return [
                UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]),
            ]
        }
    }

    private static func loadAverage() -> [Double] {
        var load = [Double](repeating: 0, count: 3)
        return getloadavg(&load, 3) == 3 ? load : [0, 0, 0]
    }
}
