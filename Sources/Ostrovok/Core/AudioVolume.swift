import CoreAudio

/// Default output volume via CoreAudio (public API).
enum AudioVolume {
    static func defaultDevice() -> AudioDeviceID {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    /// nil when the output has no volume control (some HDMI / external devices).
    static func current(_ device: AudioDeviceID = defaultDevice()) -> Float? {
        guard device != 0 else { return nil }
        var addr = volumeAddress
        guard AudioObjectHasProperty(device, &addr) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    @discardableResult
    static func set(_ value: Float, on device: AudioDeviceID = defaultDevice()) -> Bool {
        guard device != 0 else { return false }
        var addr = volumeAddress
        guard AudioObjectHasProperty(device, &addr) else { return false }
        var settable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(device, &addr, &settable) == noErr, settable.boolValue else { return false }
        var newValue = Float32(min(1, max(0, value)))
        let status = AudioObjectSetPropertyData(
            device, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &newValue)
        return status == noErr
    }

    static func isMuted(_ device: AudioDeviceID = defaultDevice()) -> Bool {
        var addr = muteAddress
        guard AudioObjectHasProperty(device, &addr) else { return false }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    @discardableResult
    static func setMuted(_ muted: Bool, on device: AudioDeviceID = defaultDevice()) -> Bool {
        var addr = muteAddress
        guard AudioObjectHasProperty(device, &addr) else { return false }
        var value = UInt32(muted ? 1 : 0)
        return AudioObjectSetPropertyData(
            device, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }
}
