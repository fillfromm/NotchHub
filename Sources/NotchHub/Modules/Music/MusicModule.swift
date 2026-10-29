import AppKit
import SwiftUI

/// The two supported players, controlled via AppleScript.
enum MusicPlayer: CaseIterable {
    case appleMusic
    case spotify

    var appName: String { self == .appleMusic ? "Music" : "Spotify" }
    var bundleID: String { self == .appleMusic ? "com.apple.Music" : "com.spotify.client" }

    /// Running check that does NOT launch the app (a bare `tell application` would).
    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// One line: `state|||title|||artist|||album|||duration(sec)|||position(sec)|||artworkURL`.
    var pollScript: String {
        switch self {
        case .appleMusic:
            return """
            tell application "Music"
                if player state is stopped then return "stopped"
                set st to "paused"
                if player state is playing then set st to "playing"
                set t to current track
                return st & "|||" & (name of t) & "|||" & (artist of t) & "|||" & (album of t) & "|||" & ((duration of t as integer) as string) & "|||" & ((player position as integer) as string) & "|||"
            end tell
            """
        case .spotify:
            return """
            tell application "Spotify"
                if player state is stopped then return "stopped"
                set st to "paused"
                if player state is playing then set st to "playing"
                set t to current track
                return st & "|||" & (name of t) & "|||" & (artist of t) & "|||" & (album of t) & "|||" & (((duration of t) / 1000) as integer as string) & "|||" & ((player position as integer) as string) & "|||" & (artwork url of t)
            end tell
            """
        }
    }
}

/// What one player is currently doing.
struct PlayerSnapshot: Equatable {
    var isPlaying: Bool
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var position: Double
    var artworkURL: String
}

/// Now-playing info and transport controls for Apple Music and Spotify.
final class MusicModule: NotchModule, ObservableObject {
    let id = "music"
    let title = "Music"
    let icon = "music.note"

    @Published private(set) var snapshot: PlayerSnapshot?
    @Published private(set) var activePlayer: MusicPlayer?
    @Published private(set) var artwork: NSImage?
    /// Players for which macOS denied the Automation permission.
    @Published private(set) var denied: Set<MusicPlayer> = []

    private var snapshots: [MusicPlayer: PlayerSnapshot] = [:]
    private var timer: Timer?
    private var artworkKey = ""

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        poll()
    }

    deinit { timer?.invalidate() }

    var compactInfo: CompactInfo? {
        guard let snapshot, snapshot.isPlaying else { return nil }
        return CompactInfo(icon: "music.note", text: snapshot.title, priority: 10)
    }

    func makeView() -> AnyView { AnyView(MusicView(module: self)) }

    // MARK: Polling

    private func poll() {
        for player in MusicPlayer.allCases {
            guard player.isRunning else {
                snapshots[player] = nil
                denied.remove(player)
                continue
            }
            AppleScriptRunner.shared.run(player.pollScript) { [weak self] result in
                self?.handle(result, for: player)
            }
        }
        reconcile()
    }

    private func handle(_ result: ScriptResult, for player: MusicPlayer) {
        switch result {
        case .success(let descriptor):
            denied.remove(player)
            snapshots[player] = Self.parse(descriptor.stringValue ?? "")
        case .failure(let code, _):
            snapshots[player] = nil
            if code == AppleScriptRunner.notAuthorized { denied.insert(player) }
        }
        reconcile()
    }

    static func parse(_ line: String) -> PlayerSnapshot? {
        let parts = line.components(separatedBy: "|||")
        guard parts.count >= 7 else { return nil }
        return PlayerSnapshot(
            isPlaying: parts[0] == "playing",
            title: parts[1], artist: parts[2], album: parts[3],
            duration: Double(parts[4]) ?? 0, position: Double(parts[5]) ?? 0,
            artworkURL: parts[6]
        )
    }

    /// Picks the player to show: one that is playing, otherwise any with a track.
    private func reconcile() {
        let playing = MusicPlayer.allCases.first { snapshots[$0]?.isPlaying == true }
        let any = MusicPlayer.allCases.first { snapshots[$0] != nil }
        let chosen = playing ?? any
        if chosen != activePlayer { activePlayer = chosen }
        let next = chosen.flatMap { snapshots[$0] }
        if next != snapshot { snapshot = next }
        if let chosen, let next { loadArtworkIfNeeded(player: chosen, snapshot: next) }
        else if artwork != nil { artwork = nil; artworkKey = "" }
    }

    // MARK: Artwork

    private func loadArtworkIfNeeded(player: MusicPlayer, snapshot: PlayerSnapshot) {
        let key = "\(player.appName)|\(snapshot.title)|\(snapshot.artist)|\(snapshot.album)"
        guard key != artworkKey else { return }
        artworkKey = key
        artwork = nil

        switch player {
        case .spotify:
            guard let url = URL(string: snapshot.artworkURL) else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let image = NSImage(data: data) else { return }
                DispatchQueue.main.async { if self?.artworkKey == key { self?.artwork = image } }
            }.resume()
        case .appleMusic:
            let script = "tell application \"Music\" to return data of artwork 1 of current track"
            AppleScriptRunner.shared.run(script) { [weak self] result in
                guard case .success(let descriptor) = result, self?.artworkKey == key,
                      let image = NSImage(data: descriptor.data) else { return }
                self?.artwork = image
            }
        }
    }

    // MARK: Controls

    func togglePlayPause() { send("playpause") }
    func next() { send("next track") }
    func previous() { send("previous track") }

    private func send(_ command: String) {
        guard let player = activePlayer else { return }
        AppleScriptRunner.shared.run("tell application \"\(player.appName)\" to \(command)") { [weak self] _ in
            self?.poll()
        }
    }

    func launch(_ player: MusicPlayer) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
