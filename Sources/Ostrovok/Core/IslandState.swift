import AppKit
import Combine

enum IslandMode: Equatable {
    case collapsed
    case expanded
    /// Transient volume/brightness HUD shown in place of the system one.
    case hud
}

/// Per-display island state (one instance per screen).
@MainActor
final class IslandState: ObservableObject {
    let geometry: IslandGeometry
    let app: AppModel

    @Published var mode: IslandMode = .collapsed
    @Published var isHovering = false
    /// True while a file drag is hovering the island (drop target active).
    @Published var isDropTargeted = false
    @Published private(set) var hud: HUDEvent?

    private var hudTask: Task<Void, Never>?

    init(geometry: IslandGeometry, app: AppModel) {
        self.geometry = geometry
        self.app = app
    }

    // MARK: - Sizes (read from Settings so they can be tuned live)

    var compactSideWidth: CGFloat { app.settings.compactSideWidth }
    var collapsedHeight: CGFloat { app.settings.collapsedHeight }
    var expandedWidth: CGFloat { app.settings.expandedWidth }
    var expandedContentHeight: CGFloat { app.settings.expandedContentHeight }

    /// Top inset that hides the island's top strip behind the physical notch.
    var contentTopInset: CGFloat {
        geometry.hasNotch ? geometry.notchSize.height + 2 : 8
    }

    /// Concave "wings" only in expanded mode — the collapsed pill hugs the notch
    /// exactly (no wider, no ears).
    var wingRadius: CGFloat {
        mode == .expanded ? Metrics.wingRadius : 0
    }

    var bottomRadius: CGFloat {
        switch mode {
        case .expanded: return Metrics.bottomRadiusExpanded
        case .hud: return Metrics.bottomRadiusHUD
        case .collapsed: return Metrics.bottomRadiusCollapsed
        }
    }

    /// Size of the drawn island body (the concave wings sit outside this).
    var bodySize: CGSize {
        switch mode {
        case .collapsed:
            return CGSize(
                width: geometry.notchSize.width,
                height: max(geometry.notchSize.height, collapsedHeight)
            )
        case .hud:
            return CGSize(
                width: geometry.notchSize.width + compactSideWidth * 2,
                height: max(geometry.notchSize.height, collapsedHeight)
            )
        case .expanded:
            return CGSize(
                width: expandedWidth,
                height: contentTopInset + expandedContentHeight
            )
        }
    }

    /// Mouse-sensitive area inside the window, in AppKit coordinates
    /// (origin bottom-left).
    var hitRect: CGRect {
        let body = bodySize
        let width = body.width + wingRadius * 2
        return CGRect(
            x: (Metrics.windowSize.width - width) / 2,
            y: Metrics.windowSize.height - body.height,
            width: width,
            height: body.height
        )
    }

    func toggle() {
        mode = mode == .expanded ? .collapsed : .expanded
    }

    /// Show volume/brightness for a moment, replacing the system HUD.
    func showHUD(_ event: HUDEvent) {
        guard app.settings.showSystemHUD else { return }
        guard mode == .collapsed || mode == .hud else { return }
        hud = event
        mode = .hud
        hudTask?.cancel()
        hudTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            await MainActor.run { self?.dismissHUD() }
        }
    }

    func dismissHUD() {
        hudTask?.cancel()
        hudTask = nil
        guard hud != nil else { return }
        hud = nil
        if mode == .hud { mode = .collapsed }
    }
}
