import AppKit
import SwiftUI
import Combine

/// Ties one display to its window and state, and drives hover + click-through.
@MainActor
final class IslandController {
    let state: IslandState
    private let app: AppModel
    private let window: IslandWindow
    private var expandTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(geometry: IslandGeometry, app: AppModel) {
        self.app = app
        state = IslandState(geometry: geometry, app: app)
        window = IslandWindow(frame: geometry.windowFrame)

        let root = IslandView(state: state, app: app)
            .environmentObject(app.settings)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = CGRect(origin: .zero, size: geometry.windowFrame.size)
        hosting.autoresizingMask = [.width, .height]
        window.passthroughView?.addSubview(hosting)

        updateHitRect()
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()

        state.$mode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateHitRect() }
            .store(in: &cancellables)

        app.hud.events
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self else { return }
                // Brightness belongs to the display that changed; volume to all.
                if let display = event.displayID, display != geometry.displayID { return }
                self.state.showHUD(event)
            }
            .store(in: &cancellables)
    }

    /// The mouse-sensitive area tracks the current drawing size.
    private func updateHitRect() {
        window.passthroughView?.hitRect = state.hitRect
    }

    /// Island rect in global coordinates, used for hover detection.
    var triggerRect: CGRect {
        state.hitRect
            .offsetBy(dx: window.frame.origin.x, dy: window.frame.origin.y)
            .insetBy(dx: -4, dy: -4)
    }

    func updateHover(mouseLocation: CGPoint) {
        // Cheap to recompute here and avoids subscribing to everything that
        // changes the island size (media, mode, settings, …).
        updateHitRect()
        let inside = triggerRect.contains(mouseLocation)

        // Returning nil from hitTest only DISCARDS the event — it doesn't fall
        // through. For clicks to truly pass, the window must ignore the mouse
        // while the cursor is not over the island.
        if window.ignoresMouseEvents != !inside {
            window.ignoresMouseEvents = !inside
        }

        if inside {
            state.isHovering = true
            collapseTask?.cancel()
            collapseTask = nil
            if state.mode == .hud { state.dismissHUD() }
            if state.mode == .collapsed, app.settings.expandOnHover {
                scheduleExpand()
            }
        } else {
            state.isHovering = false
            expandTask?.cancel()
            expandTask = nil
            if state.mode == .expanded {
                scheduleCollapse()
            }
        }
    }

    /// A short pause before expanding: the collapsed pill fades in first, so the
    /// island doesn't jump straight to full size on the first hovered pixel.
    private func scheduleExpand() {
        guard expandTask == nil else { return }
        expandTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(160))
            await MainActor.run {
                guard let self else { return }
                self.expandTask = nil
                guard self.state.isHovering, self.state.mode == .collapsed else { return }
                self.state.mode = .expanded
            }
        }
    }

    private func scheduleCollapse() {
        guard collapseTask == nil, state.mode == .expanded else { return }
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            await MainActor.run {
                guard let self else { return }
                self.collapseTask = nil
                if !self.state.isHovering { self.state.mode = .collapsed }
            }
        }
    }

    func close() {
        expandTask?.cancel()
        collapseTask?.cancel()
        cancellables.removeAll()
        window.orderOut(nil)
        window.close()
    }
}
