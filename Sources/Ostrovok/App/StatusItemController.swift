import AppKit
import Combine

/// Menu-bar control center for the app (it's `LSUIElement`, so this is the only
/// way to reach settings and quit when the island is hidden).
@MainActor
final class StatusItemController: NSObject {
    private let app: AppModel
    private let item: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    init(app: AppModel) {
        self.app = app
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "capsule.lefthalf.filled",
                accessibilityDescription: "Ostrovok"
            )
        }
        rebuildMenu()

        app.settings.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        let lang = app.settings.language
        let menu = NSMenu()

        let settings = NSMenuItem(title: L10n.text("menu.settings", lang), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let showHUD = NSMenuItem(
            title: L10n.text("settings.showHUD", lang),
            action: #selector(toggleShowHUD),
            keyEquivalent: ""
        )
        showHUD.target = self
        showHUD.state = app.settings.showSystemHUD ? .on : .off

        let simulate = NSMenuItem(
            title: L10n.text("settings.simulateOnExternal", lang),
            action: #selector(toggleSimulateOnExternal),
            keyEquivalent: ""
        )
        simulate.target = self
        simulate.state = app.settings.simulateOnExternal ? .on : .off

        let notched = NSMenuItem(
            title: L10n.text("settings.showOnNotched", lang),
            action: #selector(toggleShowOnNotchedScreen),
            keyEquivalent: ""
        )
        notched.target = self
        notched.state = app.settings.showOnNotchedScreen ? .on : .off

        menu.addItem(showHUD)
        menu.addItem(simulate)
        menu.addItem(notched)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: L10n.text("menu.quit", lang), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
    }

    @objc private func openSettings() {
        app.openSettings()
    }

    @objc private func toggleShowHUD() {
        app.settings.showSystemHUD.toggle()
        rebuildMenu()
    }

    @objc private func toggleSimulateOnExternal() {
        app.settings.simulateOnExternal.toggle()
        rebuildMenu()
    }

    @objc private func toggleShowOnNotchedScreen() {
        app.settings.showOnNotchedScreen.toggle()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
