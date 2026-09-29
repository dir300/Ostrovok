import SwiftUI

/// Expanded "Now Playing" view: artwork, track info, scrubber and controls.
struct NowPlayingView: View {
    @ObservedObject var model: NowPlayingMonitor
    @EnvironmentObject private var settings: Settings

    var body: some View {
        if let snapshot = model.snapshot {
            VStack(spacing: 12) {
                ArtworkView(image: model.artwork, size: 96)

                VStack(spacing: 3) {
                    Text(snapshot.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(snapshot.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                ProgressBar(value: model.position, duration: snapshot.duration) { fraction in
                    model.seek(toFraction: fraction)
                }

                controls(for: snapshot)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.automationDenied {
            EmptyState(
                L10n.text("nowplaying.automation", settings.language),
                symbol: "exclamationmark.triangle"
            )
        } else {
            EmptyState(L10n.text("nowplaying.nothing", settings.language), symbol: "music.note")
        }
    }

    private func controls(for snapshot: MediaSnapshot) -> some View {
        HStack(spacing: 22) {
            Button { model.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(snapshot.shuffling ? Color.green : Color.white.opacity(0.55))
            }
            .buttonStyle(.plain)

            Button { model.previous() } label: {
                Image(systemName: "backward.fill").font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)

            Button { model.togglePlayPause() } label: {
                Image(systemName: snapshot.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 34))
            }
            .buttonStyle(.plain)

            Button { model.next() } label: {
                Image(systemName: "forward.fill").font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)

            Button { model.togglePlayPause() } label: {
                Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Draggable progress bar.
struct ProgressBar: View {
    let value: Double
    let duration: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, geo.size.width * fraction))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in onSeek(Double(g.location.x / geo.size.width)) }
            )
        }
        .frame(height: 5)
    }

    private var fraction: Double {
        duration > 0 ? min(1, max(0, value / duration)) : 0
    }
}

struct ArtworkView: View {
    let image: NSImage?
    var size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(Color.white.opacity(0.08))
                    .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.3)))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
    }
}

struct EmptyState: View {
    let text: String
    let symbol: String

    init(_ text: String, symbol: String) {
        self.text = text
        self.symbol = symbol
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 18, weight: .light))
            Text(text)
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.35))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


