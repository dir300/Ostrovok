import AppKit
import ApplicationServices
import IOKit.hid

enum MediaKey: Int32, CaseIterable {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
}

struct MediaKeyPress {
    let key: MediaKey
    let isDown: Bool
    let isRepeat: Bool
    /// Shift+Option: fine step, like the system.
    let fineStep: Bool
}

/// Intercepts the volume/brightness media keys before the system sees them.
///
/// This is the only known way to hide the native HUD on modern macOS: the popover
/// is drawn by Control Center and there is no defaults/API to disable it, but if
/// the key never reaches the system there is nothing for it to draw. In exchange
/// the app becomes responsible for actually changing volume/brightness.
///
/// Requires Accessibility permission (escalating to Input Monitoring only if the
/// tap is still refused).
@MainActor
final class MediaKeyTap {
    /// Return true to swallow the key.
    var handler: ((MediaKeyPress) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static var hasInputMonitoring: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static var hasPermission: Bool { hasAccessibility }

    static func requestPermission() {
        guard !hasAccessibility else {
            if !hasInputMonitoring {
                _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            }
            return
        }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        // 14 = NSEventTypeSystemDefined, where the media keys live.
        let mask = CGEventMask(1 << 14)
        let context = Unmanaged.passUnretained(self).toOpaque()

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<MediaKeyTap>.fromOpaque(context).takeUnretainedValue()
                return MainActor.assumeIsolated { tap.process(type: type, event: event) }
            },
            userInfo: context
        ) else {
            return false
        }

        let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)

        tap = newTap
        source = newSource
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables the tap if the callback is slow; re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard type.rawValue == 14,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }

        let data = nsEvent.data1
        let code = Int32((data & 0xFFFF_0000) >> 16)
        guard let key = MediaKey(rawValue: code) else {
            return Unmanaged.passUnretained(event)
        }

        let flags = data & 0x0000_FFFF
        let isDown = ((flags & 0xFF00) >> 8) == 0x0A
        let isRepeat = (flags & 0x1) == 1
        let fineStep = nsEvent.modifierFlags.isSuperset(of: [.shift, .option])

        let press = MediaKeyPress(key: key, isDown: isDown, isRepeat: isRepeat, fineStep: fineStep)
        return handler?(press) == true ? nil : Unmanaged.passUnretained(event)
    }
}
