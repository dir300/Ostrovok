import Foundation
import Combine

/// App settings, persisted to UserDefaults. `@Published` + `didSet` keeps the
/// UI reactive without pulling in an external defaults library.
///
/// Deliberately not `@MainActor`: `IslandGeometry` is a plain struct and needs
/// to read these from a nonisolated context.
final class Settings: ObservableObject {
    private let defaults = UserDefaults.standard

    // MARK: - Language

    /// UI language. Defaults to English.
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "language") }
    }

    // MARK: - Behavior

    /// Hide the island entirely until the cursor hovers over it.
    @Published var hideUntilHover: Bool {
        didSet { defaults.set(hideUntilHover, forKey: "hideUntilHover") }
    }
    /// Expand the island automatically after a short hover (otherwise hover only
    /// reveals the collapsed pill and a click expands it).
    @Published var expandOnHover: Bool {
        didSet { defaults.set(expandOnHover, forKey: "expandOnHover") }
    }
    /// Show volume/brightness as the island HUD (replaces the system one).
    @Published var showSystemHUD: Bool {
        didSet { defaults.set(showSystemHUD, forKey: "showSystemHUD") }
    }

    // MARK: - Displays

    /// Draw the island on the built-in display that has a physical notch.
    @Published var showOnNotchedScreen: Bool {
        didSet { defaults.set(showOnNotchedScreen, forKey: "showOnNotchedScreen") }
    }
    /// Draw a simulated pill on external displays without a notch.
    @Published var simulateOnExternal: Bool {
        didSet { defaults.set(simulateOnExternal, forKey: "simulateOnExternal") }
    }

    // MARK: - Sizes (pt)

    @Published var expandedWidth: Double {
        didSet { defaults.set(expandedWidth, forKey: "expandedWidth") }
    }
    @Published var expandedContentHeight: Double {
        didSet { defaults.set(expandedContentHeight, forKey: "expandedContentHeight") }
    }
    @Published var compactSideWidth: Double {
        didSet { defaults.set(compactSideWidth, forKey: "compactSideWidth") }
    }
    @Published var collapsedHeight: Double {
        didSet { defaults.set(collapsedHeight, forKey: "collapsedHeight") }
    }

    // MARK: - Feature visibility

    /// Ids of features that appear as tabs in the island.
    @Published var enabledFeatures: Set<String> {
        didSet { defaults.set(Array(enabledFeatures).sorted(), forKey: "enabledFeatures") }
    }

    init(defaultEnabledFeatures: Set<String>) {
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .english
        hideUntilHover = defaults.object(forKey: "hideUntilHover") as? Bool ?? true
        expandOnHover = defaults.object(forKey: "expandOnHover") as? Bool ?? true
        showSystemHUD = defaults.object(forKey: "showSystemHUD") as? Bool ?? true
        showOnNotchedScreen = defaults.object(forKey: "showOnNotchedScreen") as? Bool ?? true
        simulateOnExternal = defaults.object(forKey: "simulateOnExternal") as? Bool ?? true
        expandedWidth = defaults.object(forKey: "expandedWidth") as? Double ?? 360
        expandedContentHeight = defaults.object(forKey: "expandedContentHeight") as? Double ?? 210
        compactSideWidth = defaults.object(forKey: "compactSideWidth") as? Double ?? 40
        collapsedHeight = defaults.object(forKey: "collapsedHeight") as? Double ?? 36
        if let saved = defaults.array(forKey: "enabledFeatures") as? [String] {
            enabledFeatures = Set(saved)
        } else {
            enabledFeatures = defaultEnabledFeatures
        }
    }

    func isEnabled(_ id: String) -> Bool { enabledFeatures.contains(id) }

    func setEnabled(_ id: String, _ enabled: Bool) {
        if enabled {
            enabledFeatures.insert(id)
        } else {
            enabledFeatures.remove(id)
        }
    }
}
