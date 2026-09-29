import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Strong references keep the root objects alive for the app's lifetime.
    private var appModel: AppModel?
    private var displayManager: DisplayManager?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            let model = AppModel()
            appModel = model
            displayManager = DisplayManager(app: model)
            statusItem = StatusItemController(app: model)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
