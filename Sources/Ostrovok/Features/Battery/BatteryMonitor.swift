import Foundation
import Combine
import SwiftUI
import IOKit.ps

/// Reads battery state via IOKit and publishes changes.
@MainActor
final class BatteryMonitor: ObservableObject, Feature {
    let id = "battery"
    let titleKey = "feature.battery"
    let symbolName = "battery.100"

    @Published private(set) var percentage: Int = 100
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isPluggedIn: Bool = false
    @Published private(set) var hasBattery: Bool = false

    private var source: CFRunLoopSource?

    init() {
        refresh()
        startObserving()
    }

    deinit {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    private func startObserving() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { pointer in
            guard let pointer else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(pointer).takeUnretainedValue()
            DispatchQueue.main.async {
                MainActor.assumeIsolated { monitor.refresh() }
            }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            return
        }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func refresh() {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for item in list {
            guard let description = IOPSGetPowerSourceDescription(blob, item)?.takeUnretainedValue()
                    as? [String: Any] else { continue }
            guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }

            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let percent = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : 0
            let charging = description[kIOPSIsChargingKey] as? Bool ?? false
            let plugged = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue

            if percentage != percent { percentage = percent }
            if isCharging != charging { isCharging = charging }
            if isPluggedIn != plugged { isPluggedIn = plugged }
            if !hasBattery { hasBattery = true }
            return
        }

        // Desktop Mac: no internal battery.
        if hasBattery { hasBattery = false }
    }

    // MARK: - Feature

    var expandedView: AnyView { AnyView(BatteryView(model: self)) }
}
