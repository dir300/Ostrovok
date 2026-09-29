import AppKit

/// Which app the music comes from. Each has its own AppleScript dialect.
enum MediaSource: String, CaseIterable {
    case spotify
    case music

    var bundleID: String {
        switch self {
        case .spotify: return "com.spotify.client"
        case .music: return "com.apple.Music"
        }
    }

    var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .music: return "Music"
        }
    }

    /// Spotify reports duration in milliseconds; Music in seconds.
    var durationIsMilliseconds: Bool { self == .spotify }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

struct MediaSnapshot: Equatable {
    var source: MediaSource
    var trackID: String
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var position: Double
    var artworkURL: String?
    var isPlaying: Bool
    var shuffling: Bool
}

/// AppleScript bridge to the players. All access runs on a serial queue because
/// NSAppleScript must not be called from multiple threads.
///
/// Why AppleScript and not MediaRemote? The private `MRMediaRemoteGetNowPlayingInfo`
/// stopped answering for binaries without an Apple entitlement in macOS 15.4+,
/// so every notch app moved to per-player AppleScript with
/// `DistributedNotificationCenter` as the change trigger.
final class MediaScripting {
    static let shared = MediaScripting()

    /// Becomes true when macOS denies automation control (error -1743).
    private(set) var permissionDenied = false

    private let queue = DispatchQueue(label: "dev.local.ostrovok.applescript")
    private var compiled: [String: NSAppleScript] = [:]

    private init() {}

    // MARK: - Reading

    func snapshot(completion: @escaping (MediaSnapshot?) -> Void) {
        let candidates = MediaSource.allCases.filter { $0.isRunning }
        queue.async { [weak self] in
            guard let self else {
                return DispatchQueue.main.async { completion(nil) }
            }
            var paused: MediaSnapshot?
            for source in candidates {
                guard let snap = self.readSync(source) else { continue }
                if snap.isPlaying {
                    return DispatchQueue.main.async { completion(snap) }
                }
                if paused == nil { paused = snap }
            }
            DispatchQueue.main.async { completion(paused) }
        }
    }

    private func readSync(_ source: MediaSource) -> MediaSnapshot? {
        let script: String
        switch source {
        case .spotify:
            script = """
            tell application id "com.spotify.client"
                if player state is stopped then return {"stopped"}
                set t to current track
                return {(player state as text), (id of t) as text, (name of t) as text, ¬
                        (artist of t) as text, (album of t) as text, (duration of t), ¬
                        (player position), (artwork url of t) as text, (shuffling) as text}
            end tell
            """
        case .music:
            script = """
            tell application id "com.apple.Music"
                if player state is stopped then return {"stopped"}
                set t to current track
                return {(player state as text), (database ID of t) as text, (name of t) as text, ¬
                        (artist of t) as text, (album of t) as text, (duration of t), ¬
                        (player position), "", (shuffle enabled) as text}
            end tell
            """
        }

        guard let result = run(script, key: source.rawValue + ".read"), result.numberOfItems >= 9 else {
            return nil
        }

        func item(_ index: Int) -> String { result.atIndex(index)?.stringValue ?? "" }
        func number(_ index: Int) -> Double {
            guard let descriptor = result.atIndex(index) else { return 0 }
            let value = descriptor.doubleValue
            if value != 0 { return value }
            let text = (descriptor.stringValue ?? "").replacingOccurrences(of: ",", with: ".")
            return Double(text) ?? 0
        }

        let state = item(1)
        guard state != "stopped" else { return nil }

        let rawDuration = number(6)
        return MediaSnapshot(
            source: source,
            trackID: item(2),
            title: item(3),
            artist: item(4),
            album: item(5),
            duration: source.durationIsMilliseconds ? rawDuration / 1000 : rawDuration,
            position: number(7),
            artworkURL: item(8).isEmpty ? nil : item(8),
            isPlaying: state == "playing",
            shuffling: item(9) == "true"
        )
    }

    /// Music doesn't expose an artwork URL, only the embedded artwork bytes.
    func localArtwork(for source: MediaSource, completion: @escaping (NSImage?) -> Void) {
        guard source == .music, source.isRunning else { return completion(nil) }
        queue.async { [weak self] in
            let script = """
            tell application id "com.apple.Music"
                try
                    return raw data of artwork 1 of current track
                end try
            end tell
            """
            let data = self?.run(script, key: "music.artwork")?.data
            let image = data.flatMap { NSImage(data: $0) }
            DispatchQueue.main.async { completion(image) }
        }
    }

    // MARK: - Controls

    func playPause(_ source: MediaSource) { command("playpause", on: source) }
    func next(_ source: MediaSource) { command("next track", on: source) }
    func previous(_ source: MediaSource) { command("previous track", on: source) }

    func setShuffle(_ on: Bool, on source: MediaSource) {
        let property = source == .spotify ? "shuffling" : "shuffle enabled"
        command("set \(property) to \(on)", on: source)
    }

    func setPosition(_ seconds: Double, on source: MediaSource) {
        let value = String(format: "%.2f", seconds)
        command("set player position to \(value)", on: source, cache: false)
    }

    private func command(_ verb: String, on source: MediaSource, cache: Bool = true) {
        guard source.isRunning else { return }
        queue.async { [weak self] in
            _ = self?.run(
                "tell application id \"\(source.bundleID)\" to \(verb)",
                key: "\(source.rawValue).\(verb)",
                cache: cache
            )
        }
    }

    // MARK: - Execution

    private func run(_ source: String, key: String, cache: Bool = true) -> NSAppleEventDescriptor? {
        let script: NSAppleScript
        if cache, let existing = compiled[key] {
            script = existing
        } else {
            guard let fresh = NSAppleScript(source: source) else { return nil }
            if cache { compiled[key] = fresh }
            script = fresh
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            // -1743: automation denied. -600/-1728: app quit mid-call.
            if code == -1743 { permissionDenied = true }
            return nil
        }
        permissionDenied = false
        return result
    }
}
