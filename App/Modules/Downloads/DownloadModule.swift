import AppKit
import SwiftUI
import Observation
import UniformTypeIdentifiers

/// Watches ~/Downloads for in-progress browser downloads (Safari .download, Chrome .crdownload, Firefox .part).
@Observable
final class DownloadModule: NotchModule {
    struct Item: Equatable {
        var name: String
        /// nil when the browser doesn't expose the total size (Chrome, Firefox).
        var fraction: Double?
    }

    let id = "downloads"
    /// Settable for debug hooks; normally driven by poll().
    var active: Item?
    var onFinish: ((String) -> Void)?
    var isAvailable: Bool { active != nil }
    private var timer: Timer?
    private let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    private static let partialSuffixes = [".download", ".crdownload", ".part"]

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
    }

    private func poll() {
        guard Prefs.on(Prefs.downloads) else { return }
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        let partial = entries
            .filter { url in Self.partialSuffixes.contains { url.lastPathComponent.hasSuffix($0) } }
            .max { Self.modified($0) < Self.modified($1) }

        let item = partial.map { Item(name: Self.displayName($0), fraction: Self.safariProgress($0)) }
        if item == nil, let finished = active?.name { onFinish?(finished) }
        if item != active { active = item }
    }

    private static func displayName(_ url: URL) -> String {
        var name = url.lastPathComponent
        for suffix in partialSuffixes where name.hasSuffix(suffix) { name.removeLast(suffix.count) }
        return name
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    /// Safari keeps progress in the bundle's Info.plist.
    private static func safariProgress(_ url: URL) -> Double? {
        guard url.pathExtension == "download",
              let plist = NSDictionary(contentsOf: url.appendingPathComponent("Info.plist")),
              let done = plist["DownloadEntryProgressBytesSoFar"] as? Double,
              let total = plist["DownloadEntryProgressTotalToLoad"] as? Double, total > 0 else { return nil }
        return min(done / total, 1)
    }

    var compactView: some View { EmptyView() }
    var expandedView: some View { DownloadExpandedView(downloads: self) }
}

/// Ring that fills with progress, or spins when the total is unknown.
struct DownloadRing: View {
    var fraction: Double?
    var lineWidth: CGFloat = 2.5
    var body: some View {
        ZStack {
            Circle().stroke(.blue.opacity(0.25), lineWidth: lineWidth)
            if let fraction {
                Circle().trim(from: 0, to: fraction)
                    .stroke(.blue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: fraction)
            } else {
                TimelineView(.animation) { ctx in
                    Circle().trim(from: 0, to: 0.3)
                        .stroke(.blue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(ctx.date.timeIntervalSinceReferenceDate * 360))
                }
            }
        }
    }
}

struct DownloadExpandedView: View {
    let downloads: DownloadModule
    var body: some View {
        if let item = downloads.active {
            HStack(spacing: 14) {
                Image(nsImage: NSWorkspace.shared.icon(for: UTType(filenameExtension: (item.name as NSString).pathExtension) ?? .data))
                    .resizable().frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name).font(.system(size: 14, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                    if let f = item.fraction {
                        LevelBar(value: f, color: .blue)
                    } else {
                        Text("Downloading…").font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer(minLength: 8)
                if let f = item.fraction {
                    Text("\(Int(f * 100))%").font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundStyle(.blue)
                } else {
                    DownloadRing(fraction: nil).frame(width: 22, height: 22)
                }
            }
            .foregroundStyle(.white)
        }
    }
}
