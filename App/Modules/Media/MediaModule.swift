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
    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains { !$0.isTerminated }
    }
}

extension NowPlaying {
    /// Parses the "||"-separated reply of the AppleScript query below. nil when it is incomplete.
    static func parse(_ out: String, player: MediaPlayer, sampledAt: Date = .now) -> NowPlaying? {
        let p = out.components(separatedBy: "||")
        guard p.count >= 6 else { return nil }
        let number: (String) -> TimeInterval = { Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        return NowPlaying(title: p[0], artist: p[1], isPlaying: p[2] == "playing",
                          position: number(p[3]), duration: number(p[4]),
                          artworkURL: URL(string: p[5]), player: player, sampledAt: sampledAt)
    }
}

/// Now playing via AppleScript (Spotify / Music). Never launches a player that isn't running.
///
/// Updates are event driven: Spotify and Music post a distributed notification on every change, and
/// NSWorkspace tells us when a player launches or quits. A slow timer only re-syncs the position.
/// All AppleScript runs on one serial background queue, never on the main thread.
@Observable
final class MediaModule: NotchModule {
    let id = "media"
    var nowPlaying: NowPlaying?
    private(set) var artwork: NSImage?
    /// Accent taken from the artwork, like the iPhone tints the island.
    private(set) var tint: Color = .white
    var isAvailable: Bool { nowPlaying != nil }

    @ObservationIgnored private var safetyTimer: Timer?
    @ObservationIgnored private var artworkTrackID: String?
    /// Main-thread flags that coalesce overlapping refreshes into one extra pass.
    @ObservationIgnored private var inFlight = false
    @ObservationIgnored private var dirty = false
    private let queue = DispatchQueue(label: "app.cove.media", qos: .userInitiated)

    private static let playerNotifications = [
        "com.spotify.client.PlaybackStateChanged", "com.apple.Music.playerInfo", "com.apple.iTunes.playerInfo",
    ]

    func start() {
        let center = DistributedNotificationCenter.default()
        for name in Self.playerNotifications {
            center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
        }
        let players = [MediaPlayer.spotify.bundleID, MediaPlayer.music.bundleID]
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                if let id = app?.bundleIdentifier, players.contains(id) { self?.refresh() }
            }
        }
        refresh()
        // Safety net (position drift after seeking inside the player); cheap when no player runs.
        safetyTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.refresh() }
    }

    /// Call on the main thread.
    func refresh() {
        guard let player = [MediaPlayer.spotify, .music].first(where: { $0.isRunning }) else { clear(); return }
        guard !inFlight else { dirty = true; return }
        inFlight = true
        queue.async { [weak self] in
            let fetched = Self.fetch(player)
            DispatchQueue.main.async {
                guard let self else { return }
                self.inFlight = false
                self.apply(fetched)
                if self.dirty {
                    self.dirty = false
                    self.refresh()
                }
            }
        }
    }

    func send(_ command: String) {
        guard let player = nowPlaying?.player else { return }
        queue.async { [weak self] in
            _ = Self.run("tell application \"\(player.rawValue)\" to \(command)")
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    func seek(to seconds: TimeInterval) {
        guard let player = nowPlaying?.player else { return }
        // AppleScript wants a dot decimal regardless of locale.
        let value = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), max(seconds, 0))
        queue.async { [weak self] in
            _ = Self.run("tell application \"\(player.rawValue)\" to set player position to \(value)")
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    private func apply(_ new: NowPlaying?) {
        guard let new else { clear(); return }
        if new != nowPlaying { nowPlaying = new }
        if new.trackID != artworkTrackID { loadArtwork(for: new) }
    }

    private func clear() {
        if nowPlaying != nil { nowPlaying = nil }
        artworkTrackID = nil
    }

    private func loadArtwork(for track: NowPlaying) {
        artworkTrackID = track.trackID
        if track.player == .music {
            // Music has no artwork URL; ask for the raw image data instead.
            queue.async { [weak self] in
                let data = Self.run("tell application \"Music\" to get raw data of artwork 1 of current track")?.data
                let image = data.flatMap(NSImage.init(data:))
                DispatchQueue.main.async {
                    guard let self, self.artworkTrackID == track.trackID else { return }
                    self.setArtwork(image)
                }
            }
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

    /// Runs on the media queue.
    private static func fetch(_ player: MediaPlayer) -> NowPlaying? {
        let extra = player == .spotify
            ? " & \"||\" & ((duration of current track) / 1000) & \"||\" & (artwork url of current track)"
            : " & \"||\" & (duration of current track) & \"||\""
        // The `is running` guard keeps AppleScript from relaunching a player that just quit.
        let script = """
        if application "\(player.rawValue)" is running then
          tell application "\(player.rawValue)"
            if player state is stopped then return ""
            return (name of current track) & "||" & (artist of current track) & "||" & (player state as string) & "||" & (player position)\(extra)
          end tell
        end if
        return ""
        """
        guard let out = run(script)?.stringValue, !out.isEmpty else { return nil }
        return NowPlaying.parse(out, player: player)
    }

    /// NSAppleScript is not documented as thread safe, so every call goes through the single media queue.
    private static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { Log.media.error("AppleScript error: \(error)") }
        return result
    }

    var compactView: some View { MediaCompactView(media: self) }
    var expandedView: some View { MediaExpandedView(media: self) }
}

extension MediaModule: ActivityProviding {
    var activityEntry: ActivityEntry {
        ActivityEntry(
            activity: .media, expandedHeight: 138,
            isLive: { Prefs.on(Prefs.music) && self.nowPlaying?.isPlaying == true },
            leading: { AnyView(self.compactView) },
            trailing: { AnyView(EqualizerView(isPlaying: self.nowPlaying?.isPlaying == true, color: self.tint)) },
            bubble: { size in AnyView(Artwork(image: self.artwork, size: size - 12, radius: (size - 12) / 2)) },
            expanded: { AnyView(self.expandedView) })
    }
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
