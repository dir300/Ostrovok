import AppKit
import Combine
import SwiftUI

/// What's playing right now. The source of truth is AppleScript to each player,
/// with distributed notifications as the instant-update trigger.
@MainActor
final class NowPlayingMonitor: ObservableObject, Feature {
    let id = "now-playing"
    let titleKey = "feature.nowPlaying"
    let symbolName = "music.note"

    @Published private(set) var snapshot: MediaSnapshot?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var position: Double = 0
    @Published private(set) var automationDenied = false

    var isPlaying: Bool { snapshot?.isPlaying ?? false }
    var source: MediaSource? { snapshot?.source }

    private var anchorPosition: Double = 0
    private var anchorDate = Date()
    private var heartbeat: Timer?
    private var lastRefresh = Date.distantPast
    private var pendingRefresh: Task<Void, Never>?
    private var artworkCache: [String: NSImage] = [:]
    private var artworkTrackID: String?

    init() {
        observeNotifications()
        startTimers()
        refresh()
    }

    private func observeNotifications() {
        let center = DistributedNotificationCenter.default()
        let names = [
            "com.spotify.client.PlaybackStateChanged",
            "com.apple.Music.playerInfo",
            "com.apple.iTunes.playerInfo",
        ]
        for name in names {
            center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRefresh() }
            }
        }
    }

    /// Each AppleScript call costs tens of ms (a round-trip Apple Event), so the
    /// poll interval scales with visibility. Notifications cover play/pause and
    /// track changes instantly; polling only catches seek and external control.
    private var pollInterval: TimeInterval { snapshot?.isPlaying == true ? 2 : 5 }

    private func startTimers() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.interpolate()
                if Date().timeIntervalSince(self.lastRefresh) >= self.pollInterval {
                    self.refresh()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        heartbeat = timer
    }

    /// The notification arrives a bit before the player updates its own state.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    func refresh() {
        lastRefresh = Date()
        MediaScripting.shared.snapshot { [weak self] snap in
            guard let self else { return }
            self.automationDenied = MediaScripting.shared.permissionDenied
            self.apply(snap)
        }
    }

    private func apply(_ snap: MediaSnapshot?) {
        guard let snap else {
            if snapshot != nil {
                snapshot = nil
                artwork = nil
                artworkTrackID = nil
                position = 0
            }
            return
        }

        let trackChanged = snapshot?.trackID != snap.trackID
        if snapshot != snap { snapshot = snap }
        anchorPosition = snap.position
        anchorDate = Date()
        position = snap.position
        if trackChanged { loadArtwork(for: snap) }
    }

    private func interpolate() {
        guard let snap = snapshot, snap.isPlaying else { return }
        let elapsed = Date().timeIntervalSince(anchorDate)
        position = min(snap.duration, anchorPosition + elapsed)
    }

    // MARK: - Artwork

    private func loadArtwork(for snap: MediaSnapshot) {
        artworkTrackID = snap.trackID
        if let cached = artworkCache[snap.trackID] {
            artwork = cached
            return
        }
        artwork = nil

        if let urlString = snap.artworkURL, let url = URL(string: urlString) {
            Task { [weak self] in
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = NSImage(data: data) else { return }
                await MainActor.run {
                    guard let self, self.artworkTrackID == snap.trackID else { return }
                    self.store(image, for: snap.trackID)
                }
            }
        } else {
            MediaScripting.shared.localArtwork(for: snap.source) { [weak self] image in
                guard let self, let image, self.artworkTrackID == snap.trackID else { return }
                self.store(image, for: snap.trackID)
            }
        }
    }

    private func store(_ image: NSImage, for trackID: String) {
        if artworkCache.count > 24 { artworkCache.removeAll() }
        artworkCache[trackID] = image
        artwork = image
    }

    // MARK: - Controls

    func togglePlayPause() {
        guard let source else { return }
        MediaScripting.shared.playPause(source)
        scheduleRefresh()
    }

    func next() {
        guard let source else { return }
        MediaScripting.shared.next(source)
        scheduleRefresh()
    }

    func previous() {
        guard let source else { return }
        MediaScripting.shared.previous(source)
        scheduleRefresh()
    }

    func toggleShuffle() {
        guard let source, let snapshot else { return }
        MediaScripting.shared.setShuffle(!snapshot.shuffling, on: source)
        scheduleRefresh()
    }

    func seek(toFraction fraction: Double) {
        guard let source, let snapshot else { return }
        let target = max(0, min(snapshot.duration, snapshot.duration * fraction))
        position = target
        anchorPosition = target
        anchorDate = Date()
        MediaScripting.shared.setPosition(target, on: source)
        scheduleRefresh()
    }

    // MARK: - Feature

    var expandedView: AnyView { AnyView(NowPlayingView(model: self)) }
}
