import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu-bar-only app: no Dock icon, no main menu. Controlled from the status item.
app.setActivationPolicy(.accessory)
app.run()
