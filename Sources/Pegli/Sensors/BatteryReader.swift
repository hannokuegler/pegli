import Foundation
import IOKit
import IOKit.ps

/// Akkustand über IOPowerSources, Details (Zyklen, Zustand, Temperatur) aus AppleSmartBattery.
enum BatteryReader {
    static func read() -> BatteryInfo? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }

        var desc: [String: Any]?
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  d[kIOPSIsPresentKey] as? Bool ?? true else { continue }
            desc = d
            break
        }
        guard let desc else { return nil }

        let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let capacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let level = capacity > 0 ? min(1, max(0, Double(current) / Double(capacity))) : 0
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let isPluggedIn = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        let isCharged = desc[kIOPSIsChargedKey] as? Bool ?? false

        // −1 = wird noch berechnet, 0 = nichts Sinnvolles.
        let minutesKey = isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
        var minutes = desc[minutesKey] as? Int
        if let m = minutes, m <= 0 { minutes = nil }
        if isPluggedIn && !isCharging { minutes = nil }

        let details = smartBatteryDetails()
        return BatteryInfo(
            level: level,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            isCharged: isCharged,
            minutesRemaining: minutes,
            cycleCount: details.cycles,
            health: details.health,
            temperatureC: details.temperature,
            adapterWatts: isPluggedIn ? adapterWatts() : nil
        )
    }

    // MARK: - AppleSmartBattery

    private static func smartBatteryDetails() -> (cycles: Int?, health: Double?, temperature: Double?) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return (nil, nil, nil) }
        defer { IOObjectRelease(service) }

        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        func int(_ key: String) -> Int? { (property(key) as? NSNumber)?.intValue }

        // Neuere macOS-Versionen legen einige Werte nur noch in „BatteryData" ab.
        let batteryData = property("BatteryData") as? [String: Any] ?? [:]
        func value(_ key: String) -> Int? { int(key) ?? (batteryData[key] as? NSNumber)?.intValue }

        let cycles = value("CycleCount")

        var health: Double?
        if let design = value("DesignCapacity"), design > 0,
           let maxCap = value("AppleRawMaxCapacity") ?? value("NominalChargeCapacity"), maxCap > 0 {
            // Neue Akkus liegen oft leicht über Design → wie Systemeinstellungen auf 100 % kappen.
            health = min(1, Double(maxCap) / Double(design))
        }

        var temperature: Double?
        if let raw = value("Temperature") ?? value("VirtualTemperature") {
            let celsius = Double(raw) / 100            // 1/100 °C
            let fromDeciKelvin = Double(raw) / 10 - 273.15
            if (-20...90).contains(celsius) {
                temperature = celsius
            } else if (-20...90).contains(fromDeciKelvin) {
                temperature = fromDeciKelvin
            }
        }
        return (cycles, health, temperature)
    }

    private static func adapterWatts() -> Int? {
        guard let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any],
              let watts = (details[kIOPSPowerAdapterWattsKey] as? NSNumber)?.intValue, watts > 0 else { return nil }
        return watts
    }
}
