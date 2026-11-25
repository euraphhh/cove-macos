import AppKit
import SwiftUI

/// New screenshots pop into the island (thumbnail alert) and land on the Shelf, ready to drag out.
/// Uses Spotlight's kMDItemIsScreenCapture so it works wherever screenshots are saved.
final class ScreenshotWatcher {
    private let viewModel: NotchViewModel
    private let shelf: ShelfModule
    private let query = NSMetadataQuery()
    private var seen = Set<String>()
    private var primed = false

    init(viewModel: NotchViewModel, shelf: ShelfModule) {
        self.viewModel = viewModel
        self.shelf = shelf
    }

    func start() {
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture = 1")
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSCreationDateKey, ascending: false)]
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { [weak self] _ in
            self?.collect(announce: false)
        }
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] _ in
            self?.collect(announce: true)
        }
        query.start()
    }

    private func collect(announce: Bool) {
        query.disableUpdates()
        defer { query.enableUpdates() }
        let items = (0..<query.resultCount).compactMap { query.result(at: $0) as? NSMetadataItem }
        for item in items {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String, !seen.contains(path) else { continue }
            seen.insert(path)
            let created = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? .distantPast
            // Only fresh captures after launch; the first gathering just records what already exists.
            if announce, primed, Date().timeIntervalSince(created) < 30 { show(URL(fileURLWithPath: path)) }
        }
        primed = true
    }

    private func show(_ url: URL) {
        guard Prefs.on(Prefs.screenshots) else { return }
        shelf.add([url])
        let thumb = NSImage(contentsOf: url)
        viewModel.show(IslandAlert(icon: "camera.viewfinder", iconColor: .white, text: "", image: thumb), for: 3)
    }
}
