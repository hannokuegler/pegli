import Foundation
import Combine

/// Sammelt alle Sensoren auf einer Hintergrund-Queue. Nicht auf dem MainActor.
final class Sampler {
    private let cpu = CPUSampler()
    private let net = NetworkSampler()
    private let diskIO = DiskIOSampler()
    private let selfUsage = SelfUsageSampler()
    private let processes = ProcessSampler()
    private var cachedDisks: [DiskInfo] = []
    private var tick = 0

    func sample(detailed: Bool) -> Snapshot {
        if tick % 10 == 0 { cachedDisks = DiskReader.volumes() }
        tick += 1
        let top = detailed ? processes.sample(limit: 5) : (cpu: [], memory: [])
        return Snapshot(
            cpu: cpu.sample(),
            memory: MemoryReader.read(),
            disks: cachedDisks,
            diskIO: diskIO.sample(),
            network: net.sample(),
            battery: BatteryReader.read(),
            thermal: SystemReader.thermal(),
            uptime: SystemReader.uptime(),
            selfUsage: selfUsage.sample(),
            topCPUApps: top.cpu,
            topMemoryApps: top.memory
        )
    }

    func refreshDisks() { cachedDisks = DiskReader.volumes() }

    /// Nur die Prozessliste, ohne CPU-/Netz-Deltas der anderen Sampler zu stören.
    func sampleProcesses() -> (cpu: [AppUsage], memory: [AppUsage]) {
        processes.sample(limit: 5)
    }
}

@MainActor
final class Monitor: ObservableObject {
    static let historyLength = 90

    @Published private(set) var snapshot: Snapshot = .empty
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var pressureHistory: [Double] = []
    @Published private(set) var downHistory: [Double] = []
    @Published private(set) var upHistory: [Double] = []

    /// Abtastintervall in Sekunden (1, 2 oder 5). Wird gespeichert.
    @Published var interval: TimeInterval {
        didSet {
            UserDefaults.standard.set(interval, forKey: "interval")
            start()
        }
    }

    /// true, solange das Panel offen ist → Prozessliste wird mitgemessen.
    var detailed = false {
        didSet {
            detailedFlag.set(detailed)
            if detailed && !oldValue { sampleNow() }
        }
    }
    private let detailedFlag = Flag()

    private let queue = DispatchQueue(label: "pegli.sampler", qos: .utility)
    private let sampler = Sampler()
    private var timer: DispatchSourceTimer?

    init() {
        let stored = UserDefaults.standard.double(forKey: "interval")
        interval = [1, 2, 5].contains(stored) ? stored : 2
    }

    func start() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(100))
        let sampler = sampler
        let flag = detailedFlag
        t.setEventHandler { [weak self] in
            let s = sampler.sample(detailed: flag.get())
            Task { @MainActor [weak self] in self?.apply(s) }
        }
        t.resume()
        timer = t
    }

    func sampleNow() {
        let sampler = sampler
        queue.async { [weak self] in
            let top = sampler.sampleProcesses()
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.snapshot.topCPUApps = top.cpu
                self.snapshot.topMemoryApps = top.memory
            }
        }
    }

    /// Nach Mount/Unmount aufrufen.
    func refreshDisks() {
        let sampler = sampler
        queue.async { sampler.refreshDisks() }
    }

    private func apply(_ s: Snapshot) {
        var s = s
        // Prozessliste behalten, wenn dieser Tick ohne Details lief, das Panel aber offen ist.
        if detailed && s.topCPUApps.isEmpty && s.topMemoryApps.isEmpty {
            s.topCPUApps = snapshot.topCPUApps
            s.topMemoryApps = snapshot.topMemoryApps
        }
        snapshot = s
        push(&cpuHistory, s.cpu.usage)
        push(&pressureHistory, s.memory.pressureFraction)
        push(&downHistory, s.network.downBytesPerSec)
        push(&upHistory, s.network.upBytesPerSec)
    }

    private func push(_ array: inout [Double], _ value: Double) {
        array.append(value)
        if array.count > Self.historyLength { array.removeFirst(array.count - Self.historyLength) }
    }
}

/// Thread-sicheres Bool für die Sampler-Queue.
final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set(_ v: Bool) { lock.lock(); value = v; lock.unlock() }
    func get() -> Bool { lock.lock(); defer { lock.unlock() }; return value }
}
