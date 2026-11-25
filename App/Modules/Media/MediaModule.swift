import AppKit
import SwiftUI
import Observation

struct NowPlaying: Equatable {
    var title: String
    var artist: String
    var isPlaying: Bool
    var position: TimeInterval
    var duration: TimeInterval
    var artworkURL: URL?
    var player: MediaPlayer
    /// When `position` was read, so progress can be interpolated between polls.
    var sampledAt: Date

    var trackID: String { "\(player.rawValue)|\(title)|\(artist)" }

    func elapsed(at date: Date) -> TimeInterval {
        guard isPlaying else { return position }
        return min(position + date.timeIntervalSince(sampledAt), duration)
    }

    static func == (a: NowPlaying, b: NowPlaying) -> Bool {
        a.trackID == b.trackID && a.isPlaying == b.isPlaying && a.artworkURL == b.artworkURL
            && abs(a.elapsed(at: .now) - b.elapsed(at: .now)) < 1.5 && a.duration == b.duration
    }
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
    private(set) var artwork: NSImage?
    /// Accent taken from the artwork, like the iPhone tints the island.
    private(set) var tint: Color = .white
    var isAvailable: Bool { nowPlaying != nil }
    private var timer: Timer?
    private var artworkTrackID: String?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        let player = [MediaPlayer.spotify, .music].first { $0.isRunning }
        guard let player else { clear(); return }
        let extra = player == .spotify
            ? " & \"||\" & ((duration of current track) / 1000) & \"||\" & (artwork url of current track)"
            : " & \"||\" & (duration of current track) & \"||\""
        let script = """
        tell application "\(player.rawValue)"
          if player state is stopped then return ""
          return (name of current track) & "||" & (artist of current track) & "||" & (player state as string) & "||" & (player position)\(extra)
        end tell
        """
        guard let out = run(script)?.stringValue, !out.isEmpty else { clear(); return }
        let p = out.components(separatedBy: "||")
        guard p.count >= 6 else { return }
        let new = NowPlaying(title: p[0], artist: p[1], isPlaying: p[2] == "playing",
                             position: Self.number(p[3]), duration: Self.number(p[4]),
                             artworkURL: URL(string: p[5]), player: player, sampledAt: .now)
        if new != nowPlaying { nowPlaying = new }
        if new.trackID != artworkTrackID { loadArtwork(for: new) }
    }

    func send(_ command: String) {
        guard let p = nowPlaying?.player else { return }
        _ = run("tell application \"\(p.rawValue)\" to \(command)")
        refresh()
    }

    private func clear() {
        nowPlaying = nil
        artworkTrackID = nil
    }

    private func loadArtwork(for track: NowPlaying) {
        artworkTrackID = track.trackID
        if track.player == .music {
            // Music has no artwork URL; ask for the raw image data instead.
            let data = run("tell application \"Music\" to get raw data of artwork 1 of current track")?.data
            setArtwork(data.flatMap(NSImage.init(data:)))
        } else if let url = track.artworkURL {
            Task { @MainActor [weak self] in
                let data = try? await URLSession.shared.data(from: url).0
                guard let self, self.artworkTrackID == track.trackID else { return }
                self.setArtwork(data.flatMap(NSImage.init(data:)))
            }
        } else {
            setArtwork(nil)
        }
    }

    private func setArtwork(_ image: NSImage?) {
        artwork = image
        tint = image?.islandTint ?? .white
    }

    private static func number(_ s: String) -> TimeInterval {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { Log.media.error("AppleScript error: \(error)") }
        return result
    }

    var compactView: some View { MediaCompactView(media: self) }
    var expandedView: some View { MediaExpandedView(media: self) }
}

private extension NSImage {
    /// Average artwork color, brightened so it reads on black.
    var islandTint: Color? {
        guard let tiff = tiffRepresentation, let ci = CIImage(data: tiff) else { return nil }
        let filter = CIFilter(name: "CIAreaAverage",
                              parameters: [kCIInputImageKey: ci, kCIInputExtentKey: CIVector(cgRect: ci.extent)])
        guard let output = filter?.outputImage else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        CIContext().render(output, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        let ns = NSColor(red: CGFloat(px[0]) / 255, green: CGFloat(px[1]) / 255, blue: CGFloat(px[2]) / 255, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if s < 0.15 { return .white } // greyscale covers: keep it neutral
        return Color(hue: h, saturation: min(s * 1.2, 0.85), brightness: max(b, 0.85))
    }
}
