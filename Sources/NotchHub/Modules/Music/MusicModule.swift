import AppKit
import SwiftUI

/// What Apple Music is currently doing.
struct TrackSnapshot: Equatable, Codable {
    var isPlaying: Bool
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var position: Double
}

/// Now-playing info and transport controls for Apple Music, via AppleScript.
///
/// The last known track is remembered (even across launches), so the notch can
/// always show it and the play button can resume it.
final class MusicModule: NotchModule, ObservableObject {
    let id = "music"
    let title = "Music"
    let icon = "music.note"

    private static let bundleID = "com.apple.Music"
    private static let lastTrackKey = "music.lastTrack"

    /// One line: `state|||title|||artist|||album|||duration(sec)|||position(sec)|||`.
    /// Note: avoid short variable names like `st` — they can clash with Music's dictionary terms.
    private static let pollScript = """
    tell application "Music"
        if player state is stopped then return "stopped"
        set stateText to "paused"
        if player state is playing then set stateText to "playing"
        set trk to current track
        return stateText & "|||" & (name of trk) & "|||" & (artist of trk) & "|||" & (album of trk) & "|||" & ((duration of trk as integer) as string) & "|||" & ((player position as integer) as string) & "|||"
    end tell
    """

    /// Live state from Music; nil when Music is closed or has nothing loaded.
    @Published private(set) var live: TrackSnapshot?
    /// Last track we saw, kept when Music stops or quits.
    @Published private(set) var last: TrackSnapshot?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var permissionDenied = false

    private var timer: Timer?
    private var artworkKey = ""

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.lastTrackKey),
           var saved = try? JSONDecoder().decode(TrackSnapshot.self, from: data) {
            saved.isPlaying = false
            last = saved
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        poll()
    }

    deinit { timer?.invalidate() }

    /// What the UI shows: live track, else the last one played.
    var display: TrackSnapshot? { live ?? last }
    var isPlaying: Bool { live?.isPlaying == true }

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    var compactInfo: CompactInfo? {
        guard let track = display else { return nil }
        return CompactInfo(icon: isPlaying ? "music.note" : "pause.fill", text: track.title, priority: 10)
    }

    func makeView() -> AnyView { AnyView(MusicView(module: self)) }

    // MARK: Polling

    private func poll() {
        // Checking first avoids launching Music: a bare `tell application` would start it.
        guard isRunning else {
            if live != nil { live = nil }
            permissionDenied = false
            return
        }
        AppleScriptRunner.shared.run(Self.pollScript) { [weak self] result in
            self?.handle(result)
        }
    }

    private func handle(_ result: ScriptResult) {
        switch result {
        case .success(let descriptor):
            permissionDenied = false
            guard let snapshot = Self.parse(descriptor.stringValue ?? "") else {
                live = nil // stopped / nothing loaded: keep showing `last`
                return
            }
            if snapshot != live { live = snapshot }
            remember(snapshot)
            loadArtworkIfNeeded(for: snapshot)
        case .failure(let code, let message):
            live = nil
            if code == AppleScriptRunner.notAuthorized {
                permissionDenied = true
            } else {
                NSLog("NotchHub: Music script failed (\(code)): \(message)")
            }
        }
    }

    static func parse(_ line: String) -> TrackSnapshot? {
        let parts = line.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        return TrackSnapshot(
            isPlaying: parts[0] == "playing",
            title: parts[1], artist: parts[2], album: parts[3],
            duration: Double(parts[4]) ?? 0, position: Double(parts[5]) ?? 0
        )
    }

    /// Persists the track (not the position) whenever it changes.
    private func remember(_ snapshot: TrackSnapshot) {
        var stored = snapshot
        stored.isPlaying = false
        stored.position = 0
        guard stored.title != last?.title || stored.artist != last?.artist else { return }
        last = stored
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.lastTrackKey)
        }
    }

    // MARK: Artwork

    private func loadArtworkIfNeeded(for snapshot: TrackSnapshot) {
        let key = "\(snapshot.title)|\(snapshot.artist)|\(snapshot.album)"
        guard key != artworkKey else { return }
        artworkKey = key
        artwork = nil
        let script = "tell application \"Music\" to return data of artwork 1 of current track"
        AppleScriptRunner.shared.run(script) { [weak self] result in
            guard case .success(let descriptor) = result, self?.artworkKey == key,
                  let image = NSImage(data: descriptor.data) else { return }
            self?.artwork = image
        }
    }

    // MARK: Controls

    func togglePlayPause() {
        if isRunning {
            send("playpause")
        } else {
            launchAndPlay()
        }
    }

    /// Jumps to `seconds` in the current track.
    func seek(to seconds: Double) {
        guard isRunning else { return }
        live?.position = seconds // optimistic update so the slider doesn't jump back
        AppleScriptRunner.shared.run("tell application \"Music\" to set player position to \(Int(seconds))") { [weak self] _ in
            self?.poll()
        }
    }

    func next() { send("next track") }
    func previous() { send("previous track") }

    private func send(_ command: String) {
        guard isRunning else { return }
        AppleScriptRunner.shared.run("tell application \"Music\" to \(command)") { [weak self] _ in
            self?.poll()
        }
    }

    /// Music is closed: open it, then resume playback.
    private func launchAndPlay() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.send("play") }
        }
    }

    func openApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
