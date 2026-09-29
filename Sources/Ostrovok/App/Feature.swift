import SwiftUI

/// A pluggable island module.
///
/// A feature contributes:
///  - an `expandedView`, shown when the island is open (one tab each);
///  - compact leading/trailing views, shown left/right of the notch when collapsed.
///
/// Conforming types are typically `ObservableObject`s so their views stay live.
/// This is the extension point: add a new feature by conforming and registering
/// it in `AppModel`.
@MainActor
protocol Feature: AnyObject, Identifiable {
    var id: String { get }
    /// Localization key for the feature title (see `L10n`).
    var titleKey: String { get }
    var symbolName: String { get }

    var expandedView: AnyView { get }
}
