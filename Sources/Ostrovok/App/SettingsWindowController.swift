import AppKit
import SwiftUI
import Combine

/// Hosts the SwiftUI settings view in a real window.
@MainActor
final class SettingsWindowController {
    private let app: AppModel
    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    init(app: AppModel) {
        self.app = app

        app.settings.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] lang in
                self?.window?.title = L10n.text("settings.windowTitle", lang)
            }
            .store(in: &cancellables)
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(app: app))
            let window = NSWindow(contentViewController: hosting)
            window.title = L10n.text("settings.windowTitle", app.settings.language)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 440, height: 620))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
