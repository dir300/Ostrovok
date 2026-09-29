import SwiftUI
import Combine
import Sparkle

/// Root object. Owns every feature and shared service, and exposes the ordered
/// feature list that the island tab bar renders.
@MainActor
final class AppModel: ObservableObject {
    /// Keep in sync with `features` below.
    static let featureIDs = ["now-playing", "clipboard", "battery", "timer", "shelf"]

    let settings: Settings

    // Features (each doubles as its own data source + views).
    let nowPlaying = NowPlayingMonitor()
    let clipboard = ClipboardStore()
    let battery = BatteryMonitor()
    let timer = TimerModel()
    let shelf = ShelfStore()

    // Non-tab shared services.
    let hud = SystemHUDMonitor()
    let mediaKeys: MediaKeyController
    let updaterController: SPUStandardUpdaterController

    /// The feature whose expanded view is currently selected.
    @Published var selectedFeatureID: String

    lazy var features: [any Feature] = [
        nowPlaying,
        clipboard,
        battery,
        timer,
        shelf,
    ]

    /// Features the user has enabled in Settings, in tab order.
    var enabledFeatures: [any Feature] {
        features.filter { settings.isEnabled($0.id) }
    }

    var selectedFeature: (any Feature)? {
        enabledFeatures.first { $0.id == selectedFeatureID } ?? enabledFeatures.first
    }

    private var settingsWindow: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()

    init() {
        settings = Settings(defaultEnabledFeatures: Set(Self.featureIDs))
        selectedFeatureID = nowPlaying.id
        mediaKeys = MediaKeyController(hud: hud, settings: settings)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Forward settings changes so SwiftUI views observing `app` re-render
        // when sizes / feature visibility change (Settings is a nested object).
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func setFeatureEnabled(_ id: String, _ enabled: Bool) {
        settings.setEnabled(id, enabled)
        // If the selected tab was just hidden, fall back to the first enabled one.
        if !enabled, selectedFeatureID == id {
            selectedFeatureID = enabledFeatures.first?.id ?? selectedFeatureID
        }
    }

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(app: self)
        }
        settingsWindow?.show()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
