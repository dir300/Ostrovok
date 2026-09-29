import SwiftUI
import UniformTypeIdentifiers

struct IslandView: View {
    @ObservedObject var state: IslandState
    @ObservedObject var app: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            island
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// When enabled, the collapsed island is invisible until the cursor hovers.
    private var isIdleHidden: Bool {
        state.mode == .collapsed && app.settings.hideUntilHover && !state.isHovering
    }

    private var island: some View {
        let body = state.bodySize
        return NotchShape(wingRadius: state.wingRadius, bottomRadius: state.bottomRadius)
            .fill(Color.black)
            .frame(width: body.width + state.wingRadius * 2, height: body.height)
            .overlay {
                // Nothing is rendered at all while hidden — no shape, no symbols.
                if !isIdleHidden {
                    content
                        .frame(width: body.width, height: body.height)
                        .clipped()
                }
            }
            .shadow(color: .black.opacity(state.mode == .collapsed ? 0 : 0.55), radius: 16, y: 6)
            .opacity(isIdleHidden ? 0 : 1)
            .onDrop(of: [UTType.fileURL], isTargeted: $state.isDropTargeted) { providers in
                handleDrop(providers)
            }
            .onChange(of: state.isDropTargeted) { _, targeted in
                if targeted {
                    app.selectedFeatureID = "shelf"
                    state.mode = .expanded
                }
            }
            .animation(.easeOut(duration: 0.16), value: isIdleHidden)
            .animation(.spring(response: 0.36, dampingFraction: 0.78), value: state.mode)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: state.bodySize)
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch state.mode {
            case .collapsed:
                compact.transition(.opacity)
            case .expanded:
                expanded.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            case .hud:
                hud.transition(.opacity)
            }
        }
    }

    // MARK: - Collapsed

    /// Collapsed: an empty pill that hugs the notch exactly — no symbols, no ears.
    private var compact: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { state.toggle() }
    }

    // MARK: - Expanded

    private var expanded: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: state.contentTopInset)

            if let feature = app.selectedFeature {
                VStack(spacing: 10) {
                    header(feature)
                    feature.expandedView
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    tabBar
                }
                .padding(.horizontal, 16)
                .padding(.bottom, Metrics.expandedBottomPadding)
            } else {
                EmptyState(
                    L10n.text("island.noFeatures", app.settings.language),
                    symbol: "gearshape"
                )
            }
        }
        .clipped()
    }

    private func header(_ feature: any Feature) -> some View {
        HStack {
            Label(L10n.text(feature.titleKey, app.settings.language), systemImage: feature.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Button {
                app.openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(app.enabledFeatures, id: \.id) { feature in
                let selected = feature.id == app.selectedFeatureID
                Image(systemName: feature.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selected ? .white : .white.opacity(0.35))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(selected ? Color.white.opacity(0.18) : .clear))
                    .contentShape(Circle())
                    .onTapGesture { app.selectedFeatureID = feature.id }
            }
        }
        .padding(.top, 6)
    }

    // MARK: - HUD (volume / brightness)

    @ViewBuilder
    private var hud: some View {
        if let event = state.hud {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: Self.symbol(for: event))
                        .font(.system(size: 13, weight: .semibold))
                    Text(label(for: event))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(width: state.compactSideWidth + 40, alignment: .leading)

                if state.geometry.hasNotch {
                    Color.clear.frame(width: state.geometry.notchSize.width)
                }

                HStack(spacing: 8) {
                    HUDBar(value: event.muted ? 0 : event.value, tint: Self.tint(for: event))
                    if event.kind == .volume {
                        Text("\(Int((event.muted ? 0 : event.value) * 100))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }
                .frame(width: state.compactSideWidth + 40, alignment: .trailing)
            }
        }
    }

    private func label(for event: HUDEvent) -> String {
        switch event.kind {
        case .volume:
            return event.muted
                ? L10n.text("hud.muted", app.settings.language)
                : L10n.text("hud.sound", app.settings.language)
        case .brightness:
            return L10n.text("hud.display", app.settings.language)
        }
    }

    private static func tint(for event: HUDEvent) -> Color {
        event.kind == .volume ? .green : .white
    }

    private static func symbol(for event: HUDEvent) -> String {
        switch event.kind {
        case .brightness: return "sun.max.fill"
        case .volume:
            if event.muted { return "speaker.slash.fill" }
            switch event.value {
            case ..<0.01: return "speaker.fill"
            case ..<0.34: return "speaker.wave.1.fill"
            case ..<0.67: return "speaker.wave.2.fill"
            default: return "speaker.wave.3.fill"
            }
        }
    }

    // MARK: - Drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            accepted = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    app.shelf.add([url])
                }
            }
        }
        return accepted
    }
}

private struct HUDBar: View {
    let value: Double
    var tint: Color = .white

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.25))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 5)
        .animation(.easeOut(duration: 0.18), value: value)
    }
}
