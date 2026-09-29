import AppKit

/// A view that only captures the mouse inside `hitRect`; everywhere else the
/// window is truly transparent and lets clicks fall through to the app below.
final class PassthroughView: NSView {
    var hitRect: CGRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard hitRect.contains(point) else { return nil }
        return super.hitTest(point)
    }
}

/// Borderless panel, always on top, present on every Space.
final class IslandWindow: NSPanel {
    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Above the menu bar, including over full-screen apps.
        level = NSWindow.Level(rawValue: Int(NSWindow.Level.mainMenu.rawValue) + 3)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        let container = PassthroughView(frame: CGRect(origin: .zero, size: frame.size))
        container.autoresizingMask = [.width, .height]
        contentView = container
    }

    /// Never become key/main: the island has no text fields, and stealing focus
    /// would take keyboard input away from the app the user is actually typing in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    var passthroughView: PassthroughView? { contentView as? PassthroughView }
}
