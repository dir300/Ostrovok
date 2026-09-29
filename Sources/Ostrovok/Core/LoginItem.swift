import ServiceManagement

/// Launch-at-login via SMAppService (macOS 13+). Requires a proper .app bundle;
/// when running via `swift run` the register/unregister calls throw and are ignored.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            // Not a valid app bundle — ignore (e.g. running the bare binary).
        }
    }
}
