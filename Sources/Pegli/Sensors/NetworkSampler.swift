import Foundation
import SystemConfiguration

/// Netzwerk-Durchsatz über physische Interfaces (en*), 64-bit-Zähler aus dem Interface-MIB.
/// Nur von einer seriellen Queue benutzen.
final class NetworkSampler {
    private var lastDown: UInt64 = 0
    private var lastUp: UInt64 = 0
    private var lastTime: UInt64 = 0
    private let store = SCDynamicStoreCreate(nil, "Pegli.Network" as CFString, nil, nil)

    init() {}

    func sample() -> NetworkInfo {
        let now = clock_gettime_nsec_np(CLOCK_MONOTONIC)
        let (down, up) = readCounters() ?? (lastDown, lastUp)

        var downRate = 0.0
        var upRate = 0.0
        if lastTime != 0 {
            let elapsed = Double(now &- lastTime) / 1e9
            // Zähler können bei Interface-Neustart zurückspringen → dann 0 statt Unsinn.
            if elapsed > 0.05 {
                if down >= lastDown { downRate = Double(down - lastDown) / elapsed }
                if up >= lastUp { upRate = Double(up - lastUp) / elapsed }
            }
        }
        lastDown = down
        lastUp = up
        lastTime = now

        let (name, ip) = primaryInterface()
        return NetworkInfo(downBytesPerSec: downRate, upBytesPerSec: upRate,
                           interfaceName: name, localIP: ip,
                           totalDown: down, totalUp: up)
    }

    // MARK: - Zähler

    private static func isPhysical(_ name: String) -> Bool {
        name.hasPrefix("en")
    }

    /// Summe ibytes/obytes über alle en*-Interfaces aus dem Interface-MIB (if_data64).
    /// Hinweis: NET_RT_IFLIST2 und getifaddrs liefern hier nur gekappte 32-bit-Werte.
    private func readCounters() -> (UInt64, UInt64)? {
        var countMib: [Int32] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT]
        var count: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctl(&countMib, UInt32(countMib.count), &count, &size, nil, 0) == 0, count > 0 else { return nil }

        var down: UInt64 = 0
        var up: UInt64 = 0
        var data = ifmibdata()
        for index in 1...count {
            var mib: [Int32] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, index, IFDATA_GENERAL]
            size = MemoryLayout<ifmibdata>.size
            // Lücken (abgemeldete Interfaces) schlagen fehl → überspringen.
            guard sysctl(&mib, UInt32(mib.count), &data, &size, nil, 0) == 0 else { continue }
            let name = withUnsafeBytes(of: data.ifmd_name) { raw in
                String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
            }
            guard Self.isPhysical(name) else { continue }
            down &+= data.ifmd_data.ifi_ibytes
            up &+= data.ifmd_data.ifi_obytes
        }
        return (down, up)
    }

    // MARK: - Primäres Interface

    /// Interface der Default-Route (falls en*), sonst erstes en* mit IPv4 und UP|RUNNING.
    private func primaryInterface() -> (String?, String?) {
        let addresses = ipv4Addresses()
        if let store,
           let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
           let primary = global["PrimaryInterface"] as? String,
           Self.isPhysical(primary),
           let ip = addresses.first(where: { $0.name == primary })?.ip {
            return (primary, ip)
        }
        if let first = addresses.first(where: { Self.isPhysical($0.name) }) {
            return (first.name, first.ip)
        }
        return (nil, nil)
    }

    /// IPv4-Adressen aller Interfaces mit UP|RUNNING, in getifaddrs-Reihenfolge.
    private func ipv4Addresses() -> [(name: String, ip: String)] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var result: [(name: String, ip: String)] = []
        let wanted = UInt32(IFF_UP | IFF_RUNNING)
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard ifa.ifa_flags & wanted == wanted,
                  let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            let ok = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin -> Bool in
                var a = sin.pointee.sin_addr
                return inet_ntop(AF_INET, &a, &text, socklen_t(INET_ADDRSTRLEN)) != nil
            }
            guard ok else { continue }
            result.append((String(cString: ifa.ifa_name), String(cString: text)))
        }
        return result
    }
}
