import AppKit

/// Brightness via the private DisplayServices framework (callable without an
/// entitlement, unlike MediaRemote).
enum DisplayBrightness {
    private typealias Getter = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias Notifier = @convention(c) (CGDirectDisplayID, Double) -> Void

    private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)

    private static let getter: Getter? = symbol("DisplayServicesGetBrightness")
    private static let setter: Setter? = symbol("DisplayServicesSetBrightness")
    private static let notifier: Notifier? = symbol("DisplayServicesBrightnessChanged")

    private static func symbol<T>(_ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[.init("NSScreenNumber")] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }

    /// nil when the display doesn't respond (common on external monitors).
    static func current(_ display: CGDirectDisplayID) -> Float? {
        guard let getter else { return nil }
        var value: Float = 0
        guard getter(display, &value) == 0 else { return nil }
        return value
    }

    @discardableResult
    static func set(_ value: Float, on display: CGDirectDisplayID) -> Bool {
        guard let setter else { return false }
        let target = min(1, max(0, value))
        guard setter(display, target) == 0 else { return false }
        notifier?(display, Double(target))
        return true
    }

    /// The first display that responds — in practice, the built-in one.
    static func controllableDisplay() -> CGDirectDisplayID? {
        for screen in NSScreen.screens {
            guard let id = displayID(of: screen), current(id) != nil else { continue }
            return id
        }
        return nil
    }
}
