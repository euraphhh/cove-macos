import AppKit
import SwiftUI
import Observation

struct NowPlaying: Equatable {
    var title: String
    var artist: String
    var isPlaying: Bool
    var artworkURL: URL?
    var player: MediaPlayer
}

enum MediaPlayer: String {
    case spotify = "Spotify", music = "Music"
    var bundleID: String { self == .spotify ? "com.spotify.client" : "com.apple.Music" }
    var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty }
}

/// Now playing via AppleScript (Spotify / Music). Never launches a player that isn't running.
@Observable
final class MediaModule: NotchModule {
    let id = "media"
    var nowPlaying: NowPlaying?
    var isAvailable: Bool { nowPlaying != nil }
    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        let player = [MediaPlayer.spotify, .music].first { $0.isRunning }
        guard let player else { nowPlaying = nil; return }
        let artwork = player == .spotify ? " & \"||\" & (artwork url of current track)" : " & \"||\""
        let script = """
        tell application "\(player.rawValue)"
          if player state is stopped then return ""
          return (name of current track) & "||" & (artist of current track) & "||" & (player state as string)\(artwork)
        end tell
        """
        guard let out = run(script), !out.isEmpty else { nowPlaying = nil; return }
        let parts = out.components(separatedBy: "||")
        guard parts.count >= 3 else { return }
        let new = NowPlaying(title: parts[0], artist: parts[1], isPlaying: parts[2] == "playing",
                             artworkURL: parts.count > 3 ? URL(string: parts[3]) : nil, player: player)
        if new != nowPlaying { nowPlaying = new }
    }

    func send(_ command: String) {
        guard let p = nowPlaying?.player else { return }
        _ = run("tell application \"\(p.rawValue)\" to \(command)")
        refresh()
    }

    private func run(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { Log.media.error("AppleScript error: \(error)") }
        return result?.stringValue
    }

    var compactView: some View { MediaCompactView(media: self) }
    var expandedView: some View { MediaExpandedView(media: self) }
}
