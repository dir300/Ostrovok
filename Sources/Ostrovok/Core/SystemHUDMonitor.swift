import AppKit
import Combine
import CoreAudio

struct HUDEvent: Equatable {
    enum Kind: Equatable { case volume, brightness }
    let kind: Kind
    /// 0...1
    let value: Double
    let muted: Bool
    /// Brightness is per display; volume is global.
    let displayID: CGDirectDisplayID?
}

/// System volume and brightness, so the island can replace the macOS HUD.
///
/// Volume comes from a CoreAudio listener (fires only on real change).
/// Brightness has no public notification, so it is sampled — piggybacking on the
/// mouse timer in `DisplayManager` rather than opening its own timer.
@MainActor
final class SystemHUDMonitor {
    let events = PassthroughSubject<HUDEvent, Never>()

    private var deviceID = AudioDeviceID(0)
    private var volumeBlock: AudioObjectPropertyListenerBlock?
    private var muteBlock: AudioObjectPropertyListenerBlock?
    private var deviceBlock: AudioObjectPropertyListenerBlock?

    private var brightnessGetter: BrightnessGetter?
    private var lastBrightness: [CGDirectDisplayID: Double] = [:]
    private var brightnessTick = 0

    private static let brightnessThreshold = 0.02
    private static let ticksAtRest = 6     // ~5 Hz
    private static let ticksAccelerated = 2 // ~15 Hz
    private static let accelerationTicks = 60 // ~2 s
    private var accelerationRemaining = 0

    init() {
        setupBrightness()
        attachToDefaultDevice()
        observeDefaultDeviceChanges()
    }

    // MARK: - Volume (CoreAudio)

    private func attachToDefaultDevice() {
        detachDeviceListeners()
        deviceID = Self.defaultOutputDevice()
        guard deviceID != 0 else { return }

        var volumeAddr = Self.volumeAddress
        if AudioObjectHasProperty(deviceID, &volumeAddr) {
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emitVolume() }
            }
            volumeBlock = block
            AudioObjectAddPropertyListenerBlock(deviceID, &volumeAddr, DispatchQueue.main, block)
        }

        var muteAddr = Self.muteAddress
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emitVolume() }
            }
            muteBlock = block
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, DispatchQueue.main, block)
        }
    }

    private func observeDefaultDeviceChanges() {
        var addr = Self.defaultDeviceAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.attachToDefaultDevice() }
        }
        deviceBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, block)
    }

    private func detachDeviceListeners() {
        guard deviceID != 0 else { return }
        if let volumeBlock {
            var addr = Self.volumeAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &addr, DispatchQueue.main, volumeBlock)
        }
        if let muteBlock {
            var addr = Self.muteAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &addr, DispatchQueue.main, muteBlock)
        }
        volumeBlock = nil
        muteBlock = nil
    }

    private func emitVolume() {
        guard let volume = Self.currentVolume(deviceID) else { return }
        events.send(HUDEvent(
            kind: .volume,
            value: Double(volume),
            muted: Self.isMuted(deviceID),
            displayID: nil
        ))
    }

    // MARK: - Brightness (private DisplayServices, no entitlement needed)

    private typealias BrightnessGetter = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private func setupBrightness() {
        // There is no public API to read brightness. DisplayServices is private
        // but still callable without an entitlement (unlike MediaRemote).
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        ), let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return }
        brightnessGetter = unsafeBitCast(symbol, to: BrightnessGetter.self)
        sampleBrightness(emit: false)
    }

    /// Called by the DisplayManager mouse timer (~30 Hz).
    func tick() {
        brightnessTick += 1
        let interval = accelerationRemaining > 0 ? Self.ticksAccelerated : Self.ticksAtRest
        if accelerationRemaining > 0 { accelerationRemaining -= 1 }
        guard brightnessTick % interval == 0 else { return }
        sampleBrightness(emit: true)
    }

    private func sampleBrightness(emit: Bool) {
        guard let getter = brightnessGetter else { return }
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[.init("NSScreenNumber")] as? NSNumber else { continue }
            let id = CGDirectDisplayID(number.uint32Value)
            var value: Float = 0
            guard getter(id, &value) == 0 else { continue } // external displays often fail; skip
            let newValue = Double(value)
            defer { lastBrightness[id] = newValue }
            guard emit, let previous = lastBrightness[id] else { continue }
            guard abs(newValue - previous) >= Self.brightnessThreshold else { continue }
            accelerationRemaining = Self.accelerationTicks
            events.send(HUDEvent(kind: .brightness, value: newValue, muted: false, displayID: id))
        }
    }

    /// Emit brightness immediately — used when we change it ourselves (media keys),
    /// so the HUD bar doesn't wait for the next sample.
    func emitBrightness(value: Double, displayID: CGDirectDisplayID) {
        lastBrightness[displayID] = value
        accelerationRemaining = Self.accelerationTicks
        events.send(HUDEvent(kind: .brightness, value: value, muted: false, displayID: displayID))
    }

    // MARK: - Raw CoreAudio

    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    private static var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    private static func defaultOutputDevice() -> AudioDeviceID {
        var addr = defaultDeviceAddress
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    private static func currentVolume(_ device: AudioDeviceID) -> Float? {
        guard device != 0 else { return nil }
        var addr = volumeAddress
        guard AudioObjectHasProperty(device, &addr) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func isMuted(_ device: AudioDeviceID) -> Bool {
        var addr = muteAddress
        guard AudioObjectHasProperty(device, &addr) else { return false }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }
}
