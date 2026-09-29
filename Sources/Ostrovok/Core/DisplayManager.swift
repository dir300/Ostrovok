import AppKit
import Combine

/// Creates one island per display and keeps it in sync when the monitor layout
/// changes. Also drives the shared mouse timer (hover, brightness, clipboard).
@MainActor
final class DisplayManager {
    private let app: AppModel
    private var controllers: [IslandController] = []
    private var mouseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(app: AppModel) {
        self.app = app

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }

        app.settings.$simulateOnExternal
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)

        app.settings.$showOnNotchedScreen
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)

        rebuild()
        startMouseTracking()
    }

    func rebuild() {
        controllers.forEach { $0.close() }
        controllers = NSScreen.screens.compactMap { screen in
            guard let geometry = IslandGeometry(screen: screen, settings: app.settings) else { return nil }
            return IslandController(geometry: geometry, app: app)
        }
    }

    /// Instead of tracking areas (which would need the big window and steal
    /// clicks), poll the cursor position. Also works during a file drag.
    private func startMouseTracking() {
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let location = NSEvent.mouseLocation
                for controller in self.controllers {
                    controller.updateHover(mouseLocation: location)
                }
                // Brightness and clipboard piggyback here instead of opening
                // their own timers.
                self.app.hud.tick()
                self.app.clipboard.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        mouseTimer = timer
    }
}
