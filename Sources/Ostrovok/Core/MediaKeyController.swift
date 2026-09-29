import AppKit
import Combine

/// Applies volume/brightness when we take over the media keys (to hide the native HUD).
@MainActor
final class MediaKeyController {
    /// Same steps as the system: 1/16, or 1/64 with Shift+Option.
    private static let step: Float = 1.0 / 16.0
    private static let fineStep: Float = 1.0 / 64.0

    private let tap = MediaKeyTap()
    private let hud: SystemHUDMonitor
    private let settings: Settings
    private var cancellables = Set<AnyCancellable>()
    private var waitingForPermission: Timer?
    /// Keys whose "down" we swallowed — the "up" must be swallowed too.
    private var swallowed = Set<MediaKey>()

    init(hud: SystemHUDMonitor, settings: Settings) {
        self.hud = hud
        self.settings = settings

        tap.handler = { [weak self] press in
            self?.handle(press) ?? false
        }

        settings.$interceptMediaKeys
            .receive(on: RunLoop.main)
            .sink { [weak self] on in self?.setEnabled(on) }
            .store(in: &cancellables)
    }

    func setEnabled(_ on: Bool) {
        guard on else {
            waitingForPermission?.invalidate()
            waitingForPermission = nil
            tap.stop()
            return
        }
        if tap.start() { return }

        // No Accessibility permission: ask and keep retrying so it works as soon
        // as the user grants it, without reopening the app.
        MediaKeyTap.requestPermission()
        guard waitingForPermission == nil else { return }
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, self.settings.interceptMediaKeys else {
                    timer.invalidate()
                    return
                }
                if self.tap.start() {
                    timer.invalidate()
                    self.waitingForPermission = nil
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        waitingForPermission = timer
    }

    /// Opens the relevant Privacy pane.
    func openPermissionSettings() {
        let pane = MediaKeyTap.hasAccessibility ? "Privacy_ListenEvent" : "Privacy_Accessibility"
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Handling

    private func handle(_ press: MediaKeyPress) -> Bool {
        guard press.isDown else {
            // Swallow the "up" of keys whose "down" we swallowed.
            return swallowed.remove(press.key) != nil
        }

        let applied: Bool
        switch press.key {
        case .soundUp: applied = adjustVolume(steps: 1, fine: press.fineStep)
        case .soundDown: applied = adjustVolume(steps: -1, fine: press.fineStep)
        case .mute: applied = toggleMute()
        case .brightnessUp: applied = adjustBrightness(steps: 1, fine: press.fineStep)
        case .brightnessDown: applied = adjustBrightness(steps: -1, fine: press.fineStep)
        }

        if applied { swallowed.insert(press.key) }
        return applied
    }

    private func adjustVolume(steps: Float, fine: Bool) -> Bool {
        let device = AudioVolume.defaultDevice()
        guard let current = AudioVolume.current(device) else { return false }

        let increment = fine ? Self.fineStep : Self.step
        let target = ((current / increment).rounded() + steps) * increment

        // Raising the volume unmutes, like the system does.
        if steps > 0, AudioVolume.isMuted(device) {
            AudioVolume.setMuted(false, on: device)
        }
        return AudioVolume.set(target, on: device)
    }

    private func toggleMute() -> Bool {
        let device = AudioVolume.defaultDevice()
        guard AudioVolume.current(device) != nil else { return false }
        return AudioVolume.setMuted(!AudioVolume.isMuted(device), on: device)
    }

    private func adjustBrightness(steps: Float, fine: Bool) -> Bool {
        guard let display = DisplayBrightness.controllableDisplay(),
              let current = DisplayBrightness.current(display) else { return false }

        let increment = fine ? Self.fineStep : Self.step
        let target = min(1, max(0, ((current / increment).rounded() + steps) * increment))
        guard DisplayBrightness.set(target, on: display) else { return false }

        // Brightness has no notification: tell the HUD immediately so the bar
        // doesn't lag behind the key press.
        hud.emitBrightness(value: Double(target), displayID: display)
        return true
    }
}
