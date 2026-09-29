import AppKit

/// Fixed layout metrics for the island drawing.
enum Metrics {
    /// The island window is always this size; only the clipped drawing inside it
    /// changes with mode.
    static let windowSize = CGSize(width: 620, height: 300)

    /// Radius of the concave corners that melt into the top screen edge.
    static let wingRadius: CGFloat = 10
    /// Bottom corner radii (macOS "squircle" continuous curvature).
    static let bottomRadiusCollapsed: CGFloat = 14
    static let bottomRadiusExpanded: CGFloat = 34
    static let bottomRadiusHUD: CGFloat = 16

    /// Width of the "ears" shown left/right of the notch when collapsed.
    static let compactSideWidth: CGFloat = 40
    /// Minimum collapsed pill height (physical notch is ~32pt).
    static let collapsedHeight: CGFloat = 36

    static let expandedWidth: CGFloat = 360
    static let expandedBottomPadding: CGFloat = 12
    /// Height of the content area below the notch gap in expanded mode.
    static let expandedContentHeight: CGFloat = 210

    /// Simulated pill size on displays without a notch.
    static let simulatedWidth: CGFloat = 160
    static let simulatedHeight: CGFloat = 32
}

/// Geometry of one display: the physical notch (or a simulated pill), plus the
/// window frame that hosts the island on that display.
struct IslandGeometry {
    let displayID: CGDirectDisplayID
    let hasNotch: Bool
    let notchSize: CGSize
    let windowFrame: CGRect

    init?(screen: NSScreen, settings: Settings) {
        guard let number = screen.deviceDescription[.init("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        displayID = CGDirectDisplayID(number.uint32Value)

        if let physical = IslandGeometry.physicalNotchSize(of: screen) {
            guard settings.showOnNotchedScreen else { return nil }
            hasNotch = true
            notchSize = physical
        } else {
            guard settings.simulateOnExternal else { return nil }
            hasNotch = false
            notchSize = CGSize(width: Metrics.simulatedWidth, height: Metrics.simulatedHeight)
        }

        let size = Metrics.windowSize
        windowFrame = CGRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Measures the real notch via the menu-bar auxiliary areas + safe area.
    /// This is the only reliable public way.
    static func physicalNotchSize(of screen: NSScreen) -> CGSize? {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }
        let width = screen.frame.width - left.width - right.width
        let height = screen.safeAreaInsets.top
        guard width > 1, height > 1 else { return nil }
        return CGSize(width: width, height: height)
    }
}
